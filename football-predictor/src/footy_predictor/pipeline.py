"""The two workflows behind the CLI: ad-hoc predictions and the daily job."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Iterable
from zoneinfo import ZoneInfo

from .config import Settings
from .data import DataSource, Match
from .engine import Predictor
from .history import (HistoryStore, backfill_tiers, fixture_record, grade_day, has_started,
                      merge_day, new_day, pending_leagues, pick_key, pick_record, track_record)
from .leagues import LEAGUES, TIER_ABOVE, League
from .notify import NotifyError, send_telegram, telegram_credentials
from .render import (APP_FILES, app_file, build_report, render_csv, render_html, render_json,
                     render_manifest, render_markdown, render_telegram)
from .selection import select_picks

log = logging.getLogger(__name__)


def gather_fixtures(source: DataSource, leagues: Iterable[League], dates: list[date],
                    tz: ZoneInfo, today: date) -> list[Match]:
    """Fixtures on ``dates`` (in ``tz``). Past dates are rebuilt from results."""
    leagues = list(leagues)
    codes = {lg.code for lg in leagues}
    wanted = set(dates)
    found: dict[str, Match] = {}
    if max(dates) >= today:
        for match in source.fixtures():
            if match.league in codes and match.local_date(tz) in wanted:
                found[match.id] = match
    past = [d for d in dates if d < today]
    if past:
        start, end = min(past) - timedelta(days=1), max(past) + timedelta(days=1)
        _prefetch(source, leagues, start, end)
        for league in leagues:
            for match in source.results(league, start, end):
                if match.local_date(tz) in wanted:
                    found.setdefault(match.id, match)
    return sorted(found.values(), key=lambda m: (m.kickoff is None, m.kickoff or m.date, m.league))


def _prefetch(source: DataSource, leagues: Iterable[League], start: date, end: date) -> None:
    prefetch = getattr(source, "prefetch", None)
    if prefetch is not None:
        prefetch(list(leagues), start, end)


def _prepare(source: DataSource, settings: Settings, fixtures: list[Match], dates: list[date]) -> None:
    """Download all training data in parallel before fitting."""
    codes = {m.league for m in fixtures}
    codes |= {TIER_ABOVE[c] for c in codes if c in TIER_ABOVE}
    if codes:
        start = min(dates) - timedelta(days=settings.model.history_days)
        _prefetch(source, [LEAGUES[c] for c in sorted(codes)], start, max(dates))


def predict_days(settings: Settings, source: DataSource, dates: list[date],
                 now: datetime) -> list[dict]:
    """Predictions and picks for each date, without reading or writing history.

    For past dates the real scores are attached and the picks graded, which
    makes this a quick way to see how the model did on a given day.
    """
    tz = settings.tz
    today = now.astimezone(tz).date()
    fixtures = gather_fixtures(source, settings.league_list(), dates, tz, today)
    _prepare(source, settings, fixtures, dates)
    predictor = Predictor(source, settings.model)
    days = []
    for day in dates:
        todays = [m for m in fixtures if m.local_date(tz) == day]
        predictions = predictor.predict([m.as_fixture() for m in todays], as_of=day)
        picks = select_picks(predictions, settings.selection)
        record = new_day(day, now)
        record["fixtures"] = [fixture_record(p, now) for p in predictions]
        for market, chosen in picks.items():
            record["picks"][market] = [pick_record(p, now) for p in chosen]
        results = {m.id: (m.home_goals, m.away_goals) for m in todays if m.played}
        grade_day(record, results, today)  # type: ignore[arg-type]
        days.append(record)
        log.info("%s: %d matches, picks %s", day, len(predictions),
                 {k: len(v) for k, v in picks.items()})
    return days


def write_outputs(report: dict, out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "data").mkdir(exist_ok=True)
    files = {
        out_dir / "index.html": render_html(report, app=True),
        out_dir / "manifest.webmanifest": render_manifest(report),
        out_dir / "predictions.md": render_markdown(report),
        out_dir / "predictions.csv": render_csv(report),
        out_dir / "data" / "latest.json": render_json(report),
        out_dir / ".nojekyll": "",
    }
    for day in report["days"]:
        files[out_dir / "data" / f"{day['date']}.json"] = render_json(day)
    for path, content in files.items():
        path.write_text(content, encoding="utf-8")
    for name in APP_FILES:  # icons and service worker for the installable app
        (out_dir / name).write_bytes(app_file(name))
        files[out_dir / name] = ""
    return list(files)


@dataclass
class DailyResult:
    report: dict
    files: list[Path] = field(default_factory=list)
    messages: list[str] = field(default_factory=list)
    sent: bool = False
    notify_error: str | None = None


def run_daily(settings: Settings, source: DataSource, start: date, now: datetime,
              history_dir: Path, out_dir: Path | None = None, notify: bool = True,
              dry_run: bool = False) -> DailyResult:
    """Predict upcoming days, record picks, grade old picks, publish and notify."""
    tz = settings.tz
    today = now.astimezone(tz).date()
    dates = [start + timedelta(days=i) for i in range(settings.days)]
    store = HistoryStore(history_dir)

    fixtures = [m for m in gather_fixtures(source, settings.league_list(), dates, tz, today)
                if not m.played]
    _prepare(source, settings, fixtures, dates)
    predictor = Predictor(source, settings.model)
    for day in dates:
        predictions = predictor.predict([m for m in fixtures if m.local_date(tz) == day], as_of=day)
        picks = select_picks(predictions, settings.selection)
        record = merge_day(store.load(day), day, predictions, picks, now)
        backfill_tiers(record, settings.selection)
        store.save(record)
        log.info("%s: %d matches, %d picks recorded", day, len(record["fixtures"]),
                 sum(len(v) for v in record["picks"].values()))

    _grade_history(store, source, today)
    records = store.all()
    day_records = [store.load(day) or new_day(day, now) for day in dates]
    report = build_report(day_records, track_record(records, today), settings, now)
    result = DailyResult(report)
    if out_dir is not None:
        result.files = write_outputs(report, out_dir)

    if notify and settings.telegram.enabled:
        _notify(settings, store, report, day_records[0], result, now, dry_run)
    return result


REGRADE_VOID_DAYS = 60  # keep looking for late results of void picks this long


def _grade_history(store: HistoryStore, source: DataSource, today: date) -> None:
    def needs_grading(record: dict) -> bool:
        day = date.fromisoformat(record["date"])
        if day > today:
            return False
        statuses = {p["status"] for picks in record["picks"].values() for p in picks}
        return "pending" in statuses or (
            "void" in statuses and (today - day).days <= REGRADE_VOID_DAYS)

    open_records = [r for r in store.all() if needs_grading(r)]
    leagues = pending_leagues(open_records)
    if not open_records or not leagues:
        return
    start = min(date.fromisoformat(r["date"]) for r in open_records) - timedelta(days=1)
    results: dict[str, tuple[int, int]] = {}
    for code in sorted(leagues):
        if code not in LEAGUES:
            continue
        for match in source.results(LEAGUES[code], start, today):
            results[match.id] = (match.home_goals, match.away_goals)  # type: ignore[assignment]
    for record in open_records:
        if grade_day(record, results, today):
            store.save(record)


def _notify(settings: Settings, store: HistoryStore, report: dict, first_day: dict,
            result: DailyResult, now: datetime, dry_run: bool) -> None:
    """Send picks not sent before, skipping matches that have already kicked off."""
    picks = {pick_key(p): p for chosen in first_day["picks"].values() for p in chosen}
    already = set(first_day.get("notified", []))
    new = {key for key, pick in picks.items() if key not in already and not has_started(pick, now)}
    empty_note = (not picks and settings.telegram.send_when_empty
                  and not first_day.get("notified_empty"))
    if not new and not empty_note:
        log.info("Telegram: nothing new to send")
        return
    result.messages = render_telegram(report, 0, only=new, update=bool(already))
    credentials = telegram_credentials()
    if dry_run or credentials is None:
        if credentials is None and not dry_run:
            log.info("Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)")
        return
    try:
        send_telegram(*credentials, result.messages)
    except NotifyError as exc:
        result.notify_error = str(exc)
        log.error("%s", exc)
        return
    result.sent = True
    first_day["notified"] = sorted(already | new)
    if empty_note:
        first_day["notified_empty"] = True
    store.save(first_day)

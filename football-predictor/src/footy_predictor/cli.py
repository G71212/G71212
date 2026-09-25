"""Command line interface: ``footy <command>``."""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from . import APP_NAME, __version__
from .backtest import collect_rows, evaluate, format_report, per_league_summary
from .config import ConfigError, Settings, load_settings
from .data import DataError, FootballDataSource, HttpCache
from .engine import Predictor
from .history import HistoryStore, track_record
from .leagues import LEAGUES, MAIN_LEAGUES, EXTRA_LEAGUES, PRESETS, TIER_ABOVE
from .pipeline import predict_days, run_daily
from .render import (build_report, render_csv, render_html, render_json, render_markdown,
                     render_text, today_index)

log = logging.getLogger("footy_predictor")


def _parse_day(value: str, today: date) -> date:
    value = value.strip().lower()
    if value in ("", "today"):
        return today
    if value == "tomorrow":
        return today + timedelta(days=1)
    if value == "yesterday":
        return today - timedelta(days=1)
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid date {value!r} (use YYYY-MM-DD, today, tomorrow)")


def _settings(args: argparse.Namespace) -> Settings:
    overrides: dict = {}
    if getattr(args, "leagues", None):
        overrides["leagues"] = [x.strip() for x in args.leagues.split(",") if x.strip()]
    if getattr(args, "timezone", None):
        overrides["timezone"] = args.timezone
    if getattr(args, "cache_dir", None):
        overrides["cache_dir"] = args.cache_dir
    if getattr(args, "days", None):
        overrides["days"] = args.days
    if getattr(args, "market_weight", None) is not None:
        overrides.setdefault("model", {})["market_weight"] = args.market_weight
    if os.environ.get("FOOTY_SITE_URL"):
        overrides.setdefault("site", {})["url"] = os.environ["FOOTY_SITE_URL"]
    return load_settings(args.config, overrides)


def _source(settings: Settings, args: argparse.Namespace, today: date) -> FootballDataSource:
    cache = HttpCache(settings.cache_dir, offline=args.offline)
    return FootballDataSource(cache, refresh_hours=settings.refresh_hours, today=today)


def _now() -> datetime:
    return datetime.now(timezone.utc)


# --------------------------------------------------------------------------- commands


def cmd_leagues(args: argparse.Namespace) -> int:
    print("Main leagues (one file per season, with Over/Under odds):")
    for lg in MAIN_LEAGUES:
        above = f"  (below {TIER_ABOVE[lg.code]})" if lg.code in TIER_ABOVE else ""
        print(f"  {lg.code:4s} {lg.label}{above}")
    print("\nExtra leagues (1X2 odds only):")
    for lg in EXTRA_LEAGUES:
        print(f"  {lg.code:4s} {lg.label}")
    print("\nPresets: " + ", ".join(f"{k} ({len(v)})" for k, v in PRESETS.items()))
    return 0


def cmd_predict(args: argparse.Namespace) -> int:
    settings = _settings(args)
    now = _now()
    today = now.astimezone(settings.tz).date()
    start = _parse_day(args.date or "today", today)
    days = args.days or 1
    source = _source(settings, args, today)
    records = predict_days(settings, source, [start + timedelta(days=i) for i in range(days)], now)
    report = build_report(records, {}, settings, now)
    renderers = {"text": render_text, "markdown": render_markdown, "json": render_json,
                 "csv": render_csv, "html": render_html}
    output = renderers[args.format](report)
    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"Wrote {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(output)
    if not any(r["fixtures"] for r in records):
        print("No fixtures found. football-data.co.uk publishes weekend fixtures on Friday "
              "afternoon and midweek fixtures on Tuesday afternoon (UK time).", file=sys.stderr)
    return 0


def cmd_daily(args: argparse.Namespace) -> int:
    settings = _settings(args)
    now = _now()
    today = now.astimezone(settings.tz).date()
    start = _parse_day(args.date or "today", today)
    source = _source(settings, args, today)
    result = run_daily(settings, source, start, now, Path(args.history),
                       Path(args.out) if args.out else None, notify=not args.no_notify,
                       dry_run=args.dry_run)
    for path in result.files:
        log.info("wrote %s", path)
    if args.dry_run and result.messages:
        print("---- Telegram preview ----")
        print("\n\n---- next message ----\n\n".join(result.messages))
    elif result.sent:
        print(f"Sent {len(result.messages)} Telegram message(s).", file=sys.stderr)
    first = result.report["days"][today_index(result.report)]
    counts = ", ".join(f"{m['title']}: {len(first['picks'].get(m['key'], []))}"
                       for m in result.report["markets"])
    print(f"{first['date']}: {len(first['fixtures'])} matches analysed. {counts}", file=sys.stderr)
    if result.notify_error:
        print(f"Telegram delivery failed: {result.notify_error}", file=sys.stderr)
        return 2
    return 0


def cmd_record(args: argparse.Namespace) -> int:
    settings = _settings(args)
    now = _now()
    today = now.astimezone(settings.tz).date()
    records = HistoryStore(args.history).all()
    if not records:
        print(f"No history in {args.history} yet - run 'footy daily' first.")
        return 0
    report = build_report([], track_record(records, today), settings, now)
    for market in report["markets"]:
        windows = report["track_record"][market["key"]]
        parts = []
        for label in ("7d", "30d", "all"):
            s = windows[label]
            rate = "-" if s["hit_rate"] is None else f"{100 * s['hit_rate']:.0f}%"
            parts.append(f"{label}: {s['won']}/{s['settled']} {rate}")
        print(f"{market['title']:22s} " + " | ".join(parts))
    return 0


def cmd_backtest(args: argparse.Namespace) -> int:
    settings = _settings(args)
    now = _now()
    today = now.astimezone(settings.tz).date()
    end = _parse_day(args.end, today) if args.end else today - timedelta(days=1)
    start = _parse_day(args.start, today) if args.start else end - timedelta(days=365)
    if start > end:
        raise ConfigError("--start must be before --end")
    source = _source(settings, args, today)
    leagues = settings.league_list()
    source.prefetch(leagues + [LEAGUES[TIER_ABOVE[lg.code]] for lg in leagues if lg.code in TIER_ABOVE],
                    start - timedelta(days=settings.model.history_days), end)
    rows = collect_rows(source, leagues, start, end, settings.model, args.refit_days,
                        progress=lambda msg: log.info("%s", msg))
    result = evaluate(rows, settings.model.market_weight, settings.selection, settings.model.max_goals)
    print(f"{APP_NAME} backtest {start} -> {end}, {len(leagues)} leagues")
    print(format_report(result))
    if args.per_league:
        print("\nPer league Brier (lower is better):")
        for code, s in per_league_summary(rows, settings.model.market_weight).items():
            print(f"  {code:4s} n={s['n']:5d}  Over 2.5 {s['over25_brier']:.4f}  BTTS {s['btts_brier']:.4f}")
    if args.json:
        Path(args.json).write_text(json.dumps(result, indent=1) + "\n", encoding="utf-8")
        print(f"\nWrote {args.json}")
    return 0


def cmd_ratings(args: argparse.Namespace) -> int:
    settings = _settings(args)
    now = _now()
    today = now.astimezone(settings.tz).date()
    as_of = _parse_day(args.date or "today", today)
    code = args.league.upper()
    if code not in LEAGUES:
        raise ConfigError(f"Unknown league {args.league!r} - see 'footy leagues'")
    model = Predictor(_source(settings, args, today), settings.model).model(code, as_of)
    if model is None:
        print(f"Not enough data to rate {code} on {as_of}.")
        return 1
    print(f"{LEAGUES[code].label} ratings as of {as_of} ({model.n_matches} matches)")
    print(f"home advantage x{model.home_adv:.2f} · rho {model.rho:+.3f} · "
          f"average team scores {model.base * (1 + model.home_adv) / 2:.2f} per match\n")
    print(f"{'Team':24s} {'Attack':>7s} {'Defence':>8s} {'Net':>6s} {'Matches':>8s}")
    rows = sorted(model.teams.items(), key=lambda kv: kv[1].defence / kv[1].attack)
    for team, r in rows:
        if r.weight < 1.0 and not args.all:
            continue  # teams that left the league long ago
        note = " (new)" if r.newcomer else ""
        print(f"{team:24s} {r.attack:7.2f} {r.defence:8.2f} {r.attack / r.defence:6.2f} {r.matches:8d}{note}")
    print("\nAttack > 1 scores more than average; Defence < 1 concedes less than average.")
    return 0


# --------------------------------------------------------------------------- parser


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--config", help="TOML config file (default: ./config.toml or $FOOTY_CONFIG)")
    common.add_argument("--leagues", help="comma separated league codes or presets, e.g. top5,E1")
    common.add_argument("--timezone", help="IANA time zone for 'today' and kick-off times")
    common.add_argument("--cache-dir", help="where downloaded CSV files are cached")
    common.add_argument("--offline", action="store_true", help="use cached data only")
    common.add_argument("-v", "--verbose", action="store_true", help="show progress logs")

    parser = argparse.ArgumentParser(
        prog="footy",
        description="Daily football predictions: BTTS & Over 2.5, Over 2.5, BTTS and Double Chance.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("predict", parents=[common], help="print predictions for a date")
    p.add_argument("--date", help="YYYY-MM-DD, today (default), tomorrow or yesterday")
    p.add_argument("--days", type=int, help="number of consecutive days (default 1)")
    p.add_argument("--format", choices=["text", "markdown", "json", "csv", "html"], default="text")
    p.add_argument("-o", "--output", help="write to a file instead of stdout")
    p.set_defaults(func=cmd_predict)

    d = sub.add_parser("daily", parents=[common], help="run the daily job (history, site, Telegram)")
    d.add_argument("--date", help="first day to predict (default: today)")
    d.add_argument("--days", type=int, help="upcoming days to cover (default from config: 3)")
    d.add_argument("--out", default="site", help="output folder for the dashboard (default: site)")
    d.add_argument("--history", default="history", help="folder with prediction history")
    d.add_argument("--no-notify", action="store_true", help="do not send Telegram messages")
    d.add_argument("--dry-run", action="store_true", help="print the Telegram message instead of sending")
    d.set_defaults(func=cmd_daily)

    r = sub.add_parser("record", parents=[common], help="show the track record from history")
    r.add_argument("--history", default="history")
    r.set_defaults(func=cmd_record)

    b = sub.add_parser("backtest", parents=[common], help="walk-forward evaluation on past seasons")
    b.add_argument("--start", help="first match date (default: one year before --end)")
    b.add_argument("--end", help="last match date (default: yesterday)")
    b.add_argument("--refit-days", type=int, default=7, help="refit the model every N days")
    b.add_argument("--market-weight", type=float, help="override model.market_weight (0-1)")
    b.add_argument("--per-league", action="store_true", help="also print per-league scores")
    b.add_argument("--json", help="write full results to this JSON file")
    b.set_defaults(func=cmd_backtest)

    t = sub.add_parser("ratings", parents=[common], help="team attack/defence ratings for a league")
    t.add_argument("league", help="league code, e.g. E0")
    t.add_argument("--date", help="ratings as of this date (default: today)")
    t.add_argument("--all", action="store_true", help="include teams no longer in the league")
    t.set_defaults(func=cmd_ratings)

    lg = sub.add_parser("leagues", help="list supported leagues")
    lg.set_defaults(func=cmd_leagues, verbose=False)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.INFO if getattr(args, "verbose", False) else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )
    try:
        return args.func(args)
    except (ConfigError, argparse.ArgumentTypeError) as exc:
        print(f"Configuration error: {exc}", file=sys.stderr)
        return 1
    except DataError as exc:
        print(f"Data error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())

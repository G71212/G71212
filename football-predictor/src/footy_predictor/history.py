"""Prediction history: one JSON file per day, graded once results are in.

Published picks are never edited or removed afterwards - later runs can only
add picks for matches that have not kicked off yet. That keeps the track
record honest.
"""

from __future__ import annotations

import json
import os
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

from .engine import Prediction
from .leagues import LEAGUES
from .selection import MARKETS, Pick, SelectionSettings, is_winner

VOID_AFTER_DAYS = 10  # no result this long after the match date -> void (postponed)


def _iso(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).replace(microsecond=0).isoformat()


def _round(value: float | None, digits: int = 4) -> float | None:
    return None if value is None else round(float(value), digits)


def fixture_record(prediction: Prediction, now: datetime) -> dict:
    m, p = prediction.match, prediction.probs
    league = LEAGUES.get(m.league)
    odds = None
    if m.odds_1x2 or m.odds_ou25:
        odds = {"home": None, "draw": None, "away": None, "over25": None, "under25": None}
        if m.odds_1x2:
            odds.update(home=m.odds_1x2[0], draw=m.odds_1x2[1], away=m.odds_1x2[2])
        if m.odds_ou25:
            odds.update(over25=m.odds_ou25[0], under25=m.odds_ou25[1])
    market = None
    if prediction.market is not None:
        market = {k: _round(v) for k, v in prediction.market.as_dict().items()}
    return {
        "id": m.id,
        "league": m.league,
        "league_name": league.label if league else m.league,
        "date": m.date.isoformat(),
        "kickoff": _iso(m.kickoff) if m.kickoff else None,
        "home": m.home,
        "away": m.away,
        "expected_goals": [round(prediction.exp_home, 2), round(prediction.exp_away, 2)],
        "model_expected_goals": [round(prediction.model_exp_home, 2),
                                 round(prediction.model_exp_away, 2)],
        "rho": round(prediction.rho, 4),
        "probabilities": {k: round(v, 4) for k, v in p.as_dict().items()},
        "top_scores": [[score, round(prob, 4)] for score, prob in p.top_scores],
        "market": market,
        "odds": odds,
        "team_matches": [prediction.home_matches, prediction.away_matches],
        "flags": list(prediction.flags),
        "result": [m.home_goals, m.away_goals] if m.played else None,
        "predicted_at": _iso(now),
    }


def pick_record(pick: Pick, now: datetime) -> dict:
    m = pick.prediction.match
    return {
        "market": pick.market,
        "match_id": m.id,
        "league": m.league,
        "kickoff": _iso(m.kickoff) if m.kickoff else None,
        "home": m.home,
        "away": m.away,
        "selection": pick.selection,
        "tier": pick.tier,
        "probability": round(pick.probability, 4),
        "fair_odds": round(pick.fair_odds, 2),
        "market_odds": _round(pick.market_odds, 2),
        "edge": _round(pick.edge),
        "published_at": _iso(now),
        "status": "pending",
        "result": None,
    }


def pick_key(pick: dict) -> str:
    return f"{pick['market']}|{pick['match_id']}"


def has_started(pick: dict, now: datetime) -> bool:
    """True once kick-off has passed (by date alone when the time is unknown)."""
    if pick.get("kickoff"):
        return datetime.fromisoformat(pick["kickoff"]) <= now
    match_date = pick["match_id"].split("|")[1]
    return date.fromisoformat(match_date) < now.date()


def _recorded_after_kickoff(fixture: dict) -> bool:
    if not fixture.get("kickoff") or not fixture.get("predicted_at"):
        return False
    return datetime.fromisoformat(fixture["predicted_at"]) >= datetime.fromisoformat(fixture["kickoff"])


def new_day(day: date, now: datetime) -> dict:
    return {"date": day.isoformat(), "created_at": _iso(now), "updated_at": _iso(now),
            "fixtures": [], "picks": {m: [] for m in MARKETS}, "notified": []}


def merge_day(existing: dict | None, day: date, predictions: Iterable[Prediction],
              picks: dict[str, list[Pick]], now: datetime) -> dict:
    """Add fresh predictions/picks to a day's record without touching published ones.

    Matches first seen after kick-off are left out: a prediction made once a
    game is under way is of no use and would read like hindsight.
    """
    record = existing or new_day(day, now)
    # Older versions recorded such matches; they never carry picks, so drop them.
    record["fixtures"] = [f for f in record["fixtures"] if not _recorded_after_kickoff(f)]
    known_fixtures = {f["id"] for f in record["fixtures"]}
    for prediction in predictions:
        match = prediction.match
        started = match.kickoff <= now if match.kickoff else match.date < now.date()
        if match.id in known_fixtures or started:
            continue
        record["fixtures"].append(fixture_record(prediction, now))
        known_fixtures.add(match.id)
    record["fixtures"].sort(key=lambda f: (f["kickoff"] or f["date"] + "T23:59", f["league"], f["home"]))
    for market in MARKETS:
        published = record["picks"].setdefault(market, [])
        taken = {p["match_id"] for p in published}
        for pick in picks.get(market, []):
            candidate = pick_record(pick, now)
            if candidate["match_id"] in taken or has_started(candidate, now):
                continue
            published.append(candidate)
            taken.add(candidate["match_id"])
        published.sort(key=lambda p: (-p["probability"], p["kickoff"] or ""))
    record["updated_at"] = _iso(now)
    return record


def backfill_tiers(record: dict, selection: SelectionSettings) -> None:
    """Label picks published before tiers existed. The tier only restates the
    published probability against the thresholds; the pick itself is unchanged."""
    for market, picks in record["picks"].items():
        if market not in MARKETS:
            continue
        for pick in picks:
            pick.setdefault("tier", selection.rule(market).tier(pick["probability"]))


def grade_day(record: dict, results: dict[str, tuple[int, int]], today: date,
              provisional: bool = False) -> bool:
    """Attach final scores and settle picks. Returns True if anything changed.

    ``provisional`` scores (from football-data.org, which is faster) settle picks
    straight away but stay flagged until football-data.co.uk, the main source,
    has the same match: its score then confirms the grade, or corrects it.
    """
    changed = False
    for fixture in record["fixtures"]:
        score = results.get(fixture["id"])
        if score is None or (provisional and fixture.get("result") is not None):
            continue
        if fixture.get("result") != list(score) or bool(fixture.get("provisional")) != provisional:
            fixture["result"] = list(score)
            _mark(fixture, provisional)
            changed = True
    stale = (today - date.fromisoformat(record["date"])).days > VOID_AFTER_DAYS
    for market, picks in record["picks"].items():
        for pick in picks:
            settled = pick["status"] in ("won", "lost")
            if settled and (provisional or not pick.get("provisional")):
                continue
            score = results.get(pick["match_id"])
            if score is not None:
                status = "won" if is_winner(market, pick["selection"], *score) else "lost"
                if (pick["status"], pick.get("result")) != (status, list(score)) or \
                        bool(pick.get("provisional")) != provisional:
                    pick["result"] = list(score)
                    pick["status"] = status
                    _mark(pick, provisional)
                    changed = True
            elif pick["status"] == "pending" and stale and not provisional:
                pick["status"] = "void"
                changed = True
    return changed


def _mark(item: dict, provisional: bool) -> None:
    if provisional:
        item["provisional"] = True
    else:
        item.pop("provisional", None)


def pending_leagues(records: Iterable[dict]) -> set[str]:
    """Leagues whose results are still needed: open picks, and provisional grades to confirm."""
    return {pick["league"] for record in records for picks in record["picks"].values()
            for pick in picks if pick["status"] in ("pending", "void") or pick.get("provisional")}


def _summary(picks: list[dict]) -> dict:
    settled = [p for p in picks if p["status"] in ("won", "lost")]
    won = sum(p["status"] == "won" for p in settled)
    with_odds = [p for p in settled if p.get("market_odds")]
    roi = None
    if with_odds:
        returns = [(p["market_odds"] - 1) if p["status"] == "won" else -1.0 for p in with_odds]
        roi = round(sum(returns) / len(returns), 4)
    return {
        "picks": len(picks),
        "settled": len(settled),
        "won": won,
        "lost": len(settled) - won,
        "pending": sum(p["status"] == "pending" for p in picks),
        "void": sum(p["status"] == "void" for p in picks),
        "hit_rate": round(won / len(settled), 4) if settled else None,
        "avg_probability": (round(sum(p["probability"] for p in settled) / len(settled), 4)
                            if settled else None),
        "roi": roi,
        "roi_picks": len(with_odds),
    }


def track_record(records: Iterable[dict], today: date) -> dict:
    """Hit rates per market (plus all bankers together) over 7 days, 30 days and all time."""
    records = list(records)
    groups = {market: (lambda p, m=market: p["market"] == m) for market in MARKETS}
    groups["bankers"] = lambda p: p.get("tier") == "banker"
    out = {}
    for group, wanted in groups.items():
        windows = {}
        for label, days in (("7d", 7), ("30d", 30), ("all", None)):
            start = None if days is None else today - timedelta(days=days)
            picks = [p for r in records
                     if start is None or date.fromisoformat(r["date"]) > start
                     for market_picks in r["picks"].values() for p in market_picks if wanted(p)]
            windows[label] = _summary(picks)
        out[group] = windows
    return out


class HistoryStore:
    """Directory of ``YYYY-MM-DD.json`` day records."""

    def __init__(self, directory: Path | str):
        self.directory = Path(directory)

    def path(self, day: date) -> Path:
        return self.directory / f"{day.isoformat()}.json"

    def load(self, day: date) -> dict | None:
        path = self.path(day)
        if not path.exists():
            return None
        return json.loads(path.read_text(encoding="utf-8"))

    def save(self, record: dict) -> None:
        self.directory.mkdir(parents=True, exist_ok=True)
        path = self.path(date.fromisoformat(record["date"]))
        tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
        tmp.write_text(json.dumps(record, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        tmp.replace(path)

    def all(self) -> list[dict]:
        if not self.directory.exists():
            return []
        records = []
        for path in sorted(self.directory.glob("????-??-??.json")):
            records.append(json.loads(path.read_text(encoding="utf-8")))
        return records

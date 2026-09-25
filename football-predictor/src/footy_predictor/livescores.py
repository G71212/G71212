"""Faster final scores from football-data.org (optional, needs a free API key).

football-data.co.uk publishes most results only twice a week, so picks can wait
days for their tick or cross. football-data.org has final scores shortly after
the whistle for the competitions in its free plan. Its scores are matched to
our fixtures by competition, kick-off time and team names (the two sites spell
clubs differently: "Man United" vs "Manchester United FC"), and the picks they
settle stay marked as provisional until football-data.co.uk confirms the score.

The key is read from the FOOTBALL_DATA_API_KEY environment variable and is
never logged or included in error messages.
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from difflib import SequenceMatcher
from typing import Iterable

from .data import USER_AGENT

log = logging.getLogger(__name__)

API = "https://api.football-data.org/v4"
TOKEN_ENV = "FOOTBALL_DATA_API_KEY"

# Our league code -> football-data.org competition code (all in its free plan).
COMPETITIONS = {
    "E0": "PL", "E1": "ELC", "D1": "BL1", "I1": "SA", "SP1": "PD",
    "F1": "FL1", "N1": "DED", "P1": "PPL", "BRA": "BSA",
}
MAX_RANGE_DAYS = 10  # longest date range the API accepts in one request
KICKOFF_TOLERANCE = timedelta(hours=3)


class LiveScoreError(RuntimeError):
    pass


def api_token() -> str | None:
    token = os.environ.get(TOKEN_ENV, "").strip()
    return token or None


@dataclass(frozen=True)
class Score:
    """A finished match on football-data.org."""

    competition: str
    kickoff: datetime  # UTC
    home: tuple[str, ...]  # full name, short name and three-letter code
    away: tuple[str, ...]
    home_goals: int
    away_goals: int


@dataclass(frozen=True)
class Wanted:
    """One of our fixtures that is still waiting for its score."""

    match_id: str
    league: str
    kickoff: datetime | None
    day: date
    home: str
    away: str


# --------------------------------------------------------------------------- API


def fetch_scores(token: str, start: date, end: date, competitions: Iterable[str],
                 timeout: float = 30.0) -> list[Score]:
    """Finished matches between ``start`` and ``end`` (inclusive, UTC dates)."""
    codes = ",".join(sorted(set(competitions)))
    scores: dict[tuple, Score] = {}
    chunk_start = start
    while chunk_start <= end:
        chunk_end = min(end, chunk_start + timedelta(days=MAX_RANGE_DAYS - 2))
        # dateTo is treated as exclusive by some API versions: ask for one more day.
        body = _get(token, "/matches", {
            "competitions": codes, "status": "FINISHED",
            "dateFrom": chunk_start.isoformat(),
            "dateTo": (chunk_end + timedelta(days=1)).isoformat(),
        }, timeout)
        for score in parse_matches(body):
            if start <= score.kickoff.date() <= end:
                scores[(score.competition, score.kickoff, score.home, score.away)] = score
        chunk_start = chunk_end + timedelta(days=1)
    return sorted(scores.values(), key=lambda s: (s.kickoff, s.competition))


def parse_matches(body: dict) -> list[Score]:
    out = []
    for match in body.get("matches") or []:
        try:
            if match.get("status") != "FINISHED":
                continue
            score = match.get("score") or {}
            if score.get("duration", "REGULAR") != "REGULAR":
                continue  # extra time or penalties: not a league result
            full = score.get("fullTime") or {}
            home_goals, away_goals = full.get("home"), full.get("away")
            if home_goals is None or away_goals is None:
                continue
            out.append(Score(
                competition=(match.get("competition") or {}).get("code") or "",
                kickoff=datetime.fromisoformat(match["utcDate"].replace("Z", "+00:00")).astimezone(timezone.utc),
                home=_names(match.get("homeTeam")),
                away=_names(match.get("awayTeam")),
                home_goals=int(home_goals),
                away_goals=int(away_goals),
            ))
        except (KeyError, TypeError, ValueError) as exc:
            log.debug("Skipping unreadable football-data.org match: %s", exc)
    return out


def _names(team: dict | None) -> tuple[str, ...]:
    team = team or {}
    return tuple(n for n in (team.get("name"), team.get("shortName"), team.get("tla")) if n)


def _get(token: str, path: str, params: dict, timeout: float) -> dict:
    url = f"{API}{path}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={
        "X-Auth-Token": token, "User-Agent": USER_AGENT, "Accept": "application/json"})
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            message = _error_message(exc)
            if exc.code == 429 and attempt < 3:
                wait = _int(exc.headers.get("X-RequestCounter-Reset"), 60)
                log.info("football-data.org rate limit, waiting %ss", wait)
                time.sleep(min(max(wait, 1), 65))
                continue
            if exc.code >= 500 and attempt < 3:
                time.sleep(3 * attempt)
                continue
            if exc.code in (400, 401, 403):
                raise LiveScoreError(f"football-data.org refused the request (HTTP {exc.code}): {message}. "
                                     f"Check the {TOKEN_ENV} secret.") from None
            raise LiveScoreError(f"football-data.org error (HTTP {exc.code}): {message}") from None
        except (urllib.error.URLError, TimeoutError, ConnectionError, json.JSONDecodeError) as exc:
            if attempt < 3:
                time.sleep(3 * attempt)
                continue
            raise LiveScoreError(f"Could not reach football-data.org: {getattr(exc, 'reason', exc)}") from None
    raise LiveScoreError("football-data.org: no response")  # pragma: no cover


def _error_message(exc: urllib.error.HTTPError) -> str:
    try:
        data = json.loads(exc.read().decode("utf-8"))
        return str(data.get("message", ""))[:200].rstrip(".") if isinstance(data, dict) else ""
    except Exception:  # noqa: BLE001 - best effort only
        return ""


def _int(value: str | None, default: int) -> int:
    try:
        return int(value) if value is not None else default
    except ValueError:
        return default


# --------------------------------------------------------------------------- team names

# Whole-name spellings used by football-data.co.uk (after normalising).
_NAME_ALIASES = {
    "ath madrid": "atletico madrid",
    "ath bilbao": "athletic bilbao",
    "sp lisbon": "sporting cp",
    "sp braga": "sporting braga",
    "sp gijon": "sporting gijon",
    "paris sg": "paris saint germain",
    "psg": "paris saint germain",
    "ein frankfurt": "eintracht frankfurt",
    "for sittard": "fortuna sittard",
    "nijmegen": "nec nijmegen",
    "guimaraes": "vitoria guimaraes",
    "atletico mg": "atletico mineiro",
    "athletico pr": "athletico paranaense",
    "atletico pr": "athletico paranaense",
    "atletico go": "atletico goianiense",
    "flamengo rj": "flamengo",
    "botafogo rj": "botafogo",
    "vasco": "vasco gama",
    "sao paulo": "sao paulo",
}
# Single-word abbreviations.
_WORD_ALIASES = {
    "man": "manchester",
    "utd": "united",
    "nottm": "nottingham",
    "weds": "wednesday",
    "brom": "bromwich",
    "wolves": "wolverhampton wanderers",
    "qpr": "queens park rangers",
    "mgladbach": "monchengladbach",
    "st": "saint",
    "ein": "eintracht",
    "munich": "munchen",
    "rennes": "rennais",
}
# Club-type words that carry no identity ("FC", "Calcio", "de"...).
_NOISE = {
    "fc", "afc", "cf", "sc", "ac", "as", "ss", "ssc", "ssd", "club", "de", "del", "da", "do", "di", "la",
    "le", "les", "the", "cd", "ud", "sd", "rc", "rcd", "ca", "sv", "fk", "vfl", "vfb", "tsg", "bsc",
    "us", "calcio", "futbol", "football", "clube", "sad", "ec", "fbc", "cfc", "acf", "ogc", "osc",
    "aj", "sco", "fsv", "bc", "cp", "fbpa", "se", "cr", "fr", "and", "e",
    "borussia", "stade", "olympique", "futebol",
}


def name_tokens(name: str) -> frozenset[str]:
    text = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    text = " ".join(re.findall(r"[a-z0-9]+", text.replace("'", "")))
    text = _NAME_ALIASES.get(text, text)
    words = " ".join(_WORD_ALIASES.get(w, w) for w in text.split()).split()
    return frozenset(w for w in words if w not in _NOISE and not w.isdigit())


def _same_word(a: str, b: str) -> bool:
    if a == b:
        return True
    if min(len(a), len(b)) >= 4 and (a.startswith(b) or b.startswith(a)):
        return True
    return SequenceMatcher(None, a, b).ratio() >= 0.8


def name_similarity(ours: str, theirs: Iterable[str]) -> float:
    """0..1: how well one of football-data.org's names for a team matches ours."""
    mine = name_tokens(ours)
    best = 0.0
    for name in theirs:
        if name.isupper() and len(name) <= 4 and name.lower() == ours.lower().replace(" ", ""):
            return 1.0  # three-letter code, e.g. QPR
        other = name_tokens(name)
        if not mine or not other:
            continue
        left, matched = set(other), 0
        for word in mine:
            hit = next((w for w in left if _same_word(word, w)), None)
            if hit is not None:
                left.discard(hit)
                matched += 1
        best = max(best, matched / (len(mine) + len(other) - matched))
    return best


# --------------------------------------------------------------------------- matching


def match_scores(wanted: Iterable[Wanted], scores: Iterable[Score]) -> dict[str, tuple[int, int]]:
    """Scores for our fixtures, keyed by match id. Unclear pairings are left out."""
    return {match_id: (s.home_goals, s.away_goals) for match_id, s in pair_scores(wanted, scores).items()}


def pair_scores(wanted: Iterable[Wanted], scores: Iterable[Score]) -> dict[str, Score]:
    """The football-data.org match for each of our fixtures, where the pairing is clear."""
    by_competition: dict[str, list[Score]] = {}
    for score in scores:
        by_competition.setdefault(score.competition, []).append(score)
    found: dict[str, Score] = {}
    for fixture in wanted:
        code = COMPETITIONS.get(fixture.league)
        candidates = []
        for score in by_competition.get(code or "", []):
            if fixture.kickoff is not None:
                if abs(score.kickoff - fixture.kickoff) > KICKOFF_TOLERANCE:
                    continue
            elif abs((score.kickoff.date() - fixture.day).days) > 1:
                continue
            home = name_similarity(fixture.home, score.home)
            away = name_similarity(fixture.away, score.away)
            candidates.append((home + away, home, away, score))
        if not candidates:
            continue
        candidates.sort(key=lambda c: -c[0])
        total, home, away, score = candidates[0]
        # Both names must agree, or one must match exactly (a club plays one league match
        # at a time, so an exact name inside the kick-off window is nearly decisive) with
        # the other at least resembling ours.
        convincing = (home >= 0.5 and away >= 0.5) or (max(home, away) >= 0.99 and min(home, away) >= 0.2)
        clear = len(candidates) == 1 or total - candidates[1][0] >= 0.3
        if convincing and clear:
            found[fixture.match_id] = score
        else:
            log.info("football-data.org: no clear match for %s v %s (%s)", fixture.home, fixture.away,
                     fixture.day)
    return found


def fast_result_leagues() -> list[str]:
    """Names of the covered leagues for display, e.g. "Premier League", "Serie A (Brazil)"."""
    from .leagues import LEAGUES

    leagues = [LEAGUES[code] for code in COMPETITIONS]
    names = [league.name for league in leagues]
    return [f"{league.name} ({league.country})" if names.count(league.name) > 1 else league.name
            for league in leagues]


def wanted_fixtures(records: Iterable[dict], now: datetime,
                    max_age: timedelta = timedelta(days=20)) -> list[Wanted]:
    """Fixtures in the covered leagues that have kicked off but have no score yet."""
    out = []
    for record in records:
        for fixture in record["fixtures"]:
            if fixture.get("result") is not None or fixture["league"] not in COMPETITIONS:
                continue
            kickoff = datetime.fromisoformat(fixture["kickoff"]) if fixture.get("kickoff") else None
            day = date.fromisoformat(fixture["date"])
            started = kickoff + timedelta(minutes=100) if kickoff else datetime(
                day.year, day.month, day.day, tzinfo=timezone.utc) + timedelta(days=1)
            if started > now or now - started > max_age:
                continue
            out.append(Wanted(fixture["id"], fixture["league"], kickoff, day,
                              fixture["home"], fixture["away"]))
    return out

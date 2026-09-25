"""Match data: the Match record, CSV parsing and the football-data.co.uk source.

football-data.co.uk publishes free CSV files (no API key needed):

* ``mmz4281/<season>/<code>.csv`` - one file per season for 22 European leagues,
  with results, pre-match odds (1X2, Over/Under 2.5) and, from 2026/27, xG.
* ``new/<code>.csv`` - one all-seasons file per "extra" league (MLS, Brazil...).
* ``fixtures.csv`` / ``new_league_fixtures.csv`` - upcoming matches with odds.
  They are refreshed on Friday afternoons (weekend games) and Tuesday
  afternoons (midweek games).

All kick-off times in those files are UK local time; they are converted to UTC.
"""

from __future__ import annotations

import csv
import io
import logging
import os
import re
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Protocol
from urllib.parse import urlparse
from zoneinfo import ZoneInfo

from . import __version__
from .leagues import EXTRA_BY_COUNTRY, LEAGUES, League

log = logging.getLogger(__name__)

UK = ZoneInfo("Europe/London")
BASE_URL = "https://football-data.co.uk"
USER_AGENT = f"footy-predictor/{__version__} (+https://github.com/G71212/G71212)"

# Pre-match odds columns in order of preference (market average first).
H2H_COLUMNS = (
    ("AvgH", "AvgD", "AvgA"),
    ("BFEH", "BFED", "BFEA"),
    ("B365H", "B365D", "B365A"),
    ("PSH", "PSD", "PSA"),
    ("BbAvH", "BbAvD", "BbAvA"),
)
OU25_COLUMNS = (
    ("Avg>2.5", "Avg<2.5"),
    ("BFE>2.5", "BFE<2.5"),
    ("B365>2.5", "B365<2.5"),
    ("P>2.5", "P<2.5"),
    ("BbAv>2.5", "BbAv<2.5"),
)


class DataError(RuntimeError):
    """Raised when data cannot be downloaded and no cached copy exists."""


@dataclass(frozen=True)
class Match:
    """A fixture or a played match (goals are None until it has been played)."""

    league: str
    season: str
    date: date  # UK calendar date, as published by the source
    home: str
    away: str
    kickoff: datetime | None = None  # timezone-aware UTC
    home_goals: int | None = None
    away_goals: int | None = None
    home_xg: float | None = None
    away_xg: float | None = None
    odds_1x2: tuple[float, float, float] | None = None
    odds_ou25: tuple[float, float] | None = None  # (over, under)

    @property
    def id(self) -> str:
        return f"{self.league}|{self.date.isoformat()}|{self.home}|{self.away}"

    @property
    def played(self) -> bool:
        return self.home_goals is not None and self.away_goals is not None

    def local_date(self, tz: ZoneInfo) -> date:
        """Calendar date of the kick-off in ``tz`` (falls back to the UK date)."""
        if self.kickoff is None:
            return self.date
        return self.kickoff.astimezone(tz).date()

    def as_fixture(self) -> "Match":
        """Copy without the result - used when re-predicting past matches."""
        return Match(
            self.league, self.season, self.date, self.home, self.away, self.kickoff,
            odds_1x2=self.odds_1x2, odds_ou25=self.odds_ou25,
        )


# --------------------------------------------------------------------------- parsing


def _float(value: str | None) -> float | None:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    try:
        out = float(value)
    except ValueError:
        return None
    return out if out == out else None  # drop NaN


def _int(value: str | None) -> int | None:
    number = _float(value)
    if number is None or number < 0:
        return None
    return int(round(number))


def parse_date(value: str | None) -> date | None:
    value = (value or "").strip()
    for fmt in ("%d/%m/%Y", "%d/%m/%y", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            continue
    return None


def parse_kickoff(day: date, value: str | None) -> datetime | None:
    """Combine a UK date and ``HH:MM`` UK time into an aware UTC datetime."""
    match = re.match(r"^\s*(\d{1,2}):(\d{2})", value or "")
    if not match:
        return None
    hour, minute = int(match.group(1)), int(match.group(2))
    if hour > 23 or minute > 59:
        return None
    local = datetime(day.year, day.month, day.day, hour, minute, tzinfo=UK)
    return local.astimezone(timezone.utc)


def _odds(row: dict[str, str], candidates: Iterable[tuple[str, ...]]) -> tuple[float, ...] | None:
    for columns in candidates:
        values = [_float(row.get(col)) for col in columns]
        if all(v is not None and v > 1.0 for v in values):
            return tuple(values)  # type: ignore[arg-type]
    return None


def read_csv_rows(raw: bytes) -> list[dict[str, str]]:
    """Decode a football-data CSV (comma or tab separated, with or without BOM)."""
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("cp1252", errors="replace")
    first_line = text.split("\n", 1)[0]
    delimiter = "\t" if first_line.count("\t") > first_line.count(",") else ","
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    rows = []
    for row in reader:
        rows.append({(k or "").strip(): (v or "") for k, v in row.items() if k})
    return rows


def season_start_year(day: date) -> int:
    """European seasons are labelled by the year they start (July cut-off)."""
    return day.year if day.month >= 7 else day.year - 1


def season_code(start_year: int) -> str:
    return f"{start_year % 100:02d}{(start_year + 1) % 100:02d}"


def parse_main_rows(rows: list[dict[str, str]], league: str, season: str) -> list[Match]:
    """Rows from a per-season file or fixtures.csv (HomeTeam/AwayTeam/FTHG...)."""
    out = []
    for row in rows:
        home = (row.get("HomeTeam") or row.get("HT") or "").strip()
        away = (row.get("AwayTeam") or row.get("AT") or "").strip()
        day = parse_date(row.get("Date"))
        if not home or not away or day is None:
            continue
        home_goals = _int(row.get("FTHG") or row.get("HG"))
        away_goals = _int(row.get("FTAG") or row.get("AG"))
        if home_goals is None or away_goals is None:
            home_goals = away_goals = None
        home_xg, away_xg = _float(row.get("HxG")), _float(row.get("AxG"))
        if home_xg is None or away_xg is None:
            home_xg = away_xg = None
        out.append(
            Match(
                league=league,
                season=season,
                date=day,
                home=home,
                away=away,
                kickoff=parse_kickoff(day, row.get("Time")),
                home_goals=home_goals,
                away_goals=away_goals,
                home_xg=home_xg,
                away_xg=away_xg,
                odds_1x2=_odds(row, H2H_COLUMNS),  # type: ignore[arg-type]
                odds_ou25=_odds(row, OU25_COLUMNS),  # type: ignore[arg-type]
            )
        )
    return out


def parse_extra_rows(rows: list[dict[str, str]], league: str) -> list[Match]:
    """Rows from new/<code>.csv or new_league_fixtures.csv (Home/Away/HG/AG).

    Only pre-match odds are used; the historical extra-league files carry
    closing odds only, which would leak information into backtests.
    """
    out = []
    for row in rows:
        home = (row.get("Home") or "").strip()
        away = (row.get("Away") or "").strip()
        day = parse_date(row.get("Date"))
        if not home or not away or day is None:
            continue
        home_goals, away_goals = _int(row.get("HG")), _int(row.get("AG"))
        if home_goals is None or away_goals is None:
            home_goals = away_goals = None
        out.append(
            Match(
                league=league,
                season=(row.get("Season") or str(season_start_year(day))).strip(),
                date=day,
                home=home,
                away=away,
                kickoff=parse_kickoff(day, row.get("Time")),
                home_goals=home_goals,
                away_goals=away_goals,
                odds_1x2=_odds(row, H2H_COLUMNS),  # type: ignore[arg-type]
            )
        )
    return out


# --------------------------------------------------------------------------- HTTP cache


class HttpCache:
    """Tiny file cache in front of HTTP GET with retries and stale fallback."""

    def __init__(self, cache_dir: Path | str, offline: bool = False, timeout: float = 30.0,
                 retries: int = 3):
        self.cache_dir = Path(cache_dir)
        self.offline = offline
        self.timeout = timeout
        self.retries = retries

    def path_for(self, url: str) -> Path:
        parsed = urlparse(url)
        safe = re.sub(r"[^A-Za-z0-9._/-]", "_", parsed.path.lstrip("/")) or "index"
        return self.cache_dir / parsed.netloc / safe

    def get(self, url: str, max_age: timedelta | None) -> bytes | None:
        """Return the body of ``url`` (None on HTTP 404).

        ``max_age=None`` means a cached copy never expires (finished seasons).
        """
        path = self.path_for(url)
        if path.exists():
            age = time.time() - path.stat().st_mtime
            if self.offline or max_age is None or age < max_age.total_seconds():
                return path.read_bytes()
        elif self.offline:
            return None
        try:
            body = self._download(url)
        except Exception as exc:  # network trouble: fall back to a stale copy
            if path.exists():
                log.warning("Download failed for %s (%s); using cached copy", url, exc)
                return path.read_bytes()
            raise DataError(f"Could not download {url}: {exc}") from exc
        if body is None:
            return None
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + f".{os.getpid()}.tmp")
        tmp.write_bytes(body)
        tmp.replace(path)
        return body

    def _download(self, url: str) -> bytes | None:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        delay = 2.0
        for attempt in range(1, self.retries + 1):
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    return response.read()
            except urllib.error.HTTPError as exc:
                if exc.code == 404:
                    return None
                if exc.code not in (429, 500, 502, 503, 504) or attempt == self.retries:
                    raise
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                if attempt == self.retries:
                    raise
            log.info("Retrying %s in %.0fs (attempt %d/%d)", url, delay, attempt + 1, self.retries)
            time.sleep(delay)
            delay *= 2
        return None  # pragma: no cover - loop always returns or raises


# --------------------------------------------------------------------------- sources


class DataSource(Protocol):
    def results(self, league: League, start: date, end: date) -> list[Match]:
        """Played matches with ``start <= date <= end``."""

    def fixtures(self) -> list[Match]:
        """Upcoming matches currently published by the source."""


class FootballDataSource:
    """Results and fixtures from football-data.co.uk."""

    def __init__(self, cache: HttpCache, refresh_hours: float = 6.0, base_url: str = BASE_URL,
                 today: date | None = None, workers: int = 4):
        self.cache = cache
        self.refresh = timedelta(hours=refresh_hours)
        self.base_url = base_url.rstrip("/")
        self.today = today or datetime.now(timezone.utc).date()
        self.workers = workers
        self._memo: dict[str, list[Match]] = {}

    # -- results
    def results(self, league: League, start: date, end: date) -> list[Match]:
        if league.kind == "extra":
            matches = self._extra_league(league)
        else:
            matches = []
            for year in range(season_start_year(start), season_start_year(end) + 1):
                matches.extend(self._main_season(league, year))
        return [m for m in matches if m.played and start <= m.date <= end]

    def prefetch(self, leagues: Iterable[League], start: date, end: date) -> None:
        """Download the files for several leagues concurrently (optional speed-up)."""
        jobs = []
        for league in leagues:
            if league.kind == "extra":
                jobs.append((self._extra_league, (league,)))
            else:
                for year in range(season_start_year(start), season_start_year(end) + 1):
                    jobs.append((self._main_season, (league, year)))
        with ThreadPoolExecutor(max_workers=self.workers) as pool:
            futures = [pool.submit(func, *args) for func, args in jobs]
            for future in futures:
                try:
                    future.result()
                except DataError as exc:
                    log.warning("%s", exc)

    def _main_season(self, league: League, start_year: int) -> list[Match]:
        code = season_code(start_year)
        key = f"{league.code}:{code}"
        if key not in self._memo:
            finished = start_year < season_start_year(self.today)
            url = f"{self.base_url}/mmz4281/{code}/{league.code}.csv"
            body = self.cache.get(url, None if finished else self.refresh)
            self._memo[key] = parse_main_rows(read_csv_rows(body), league.code, code) if body else []
        return self._memo[key]

    def _extra_league(self, league: League) -> list[Match]:
        key = league.code
        if key not in self._memo:
            body = self.cache.get(f"{self.base_url}/new/{league.code}.csv", self.refresh)
            self._memo[key] = parse_extra_rows(read_csv_rows(body), league.code) if body else []
        return self._memo[key]

    # -- fixtures
    def fixtures(self) -> list[Match]:
        max_age = min(self.refresh, timedelta(hours=2))
        out: list[Match] = []
        body = self.cache.get(f"{self.base_url}/fixtures.csv", max_age)
        if body:
            rows = read_csv_rows(body)
            by_league: dict[str, list[dict[str, str]]] = {}
            for row in rows:
                by_league.setdefault((row.get("Div") or "").strip(), []).append(row)
            for code, league_rows in by_league.items():
                if code in LEAGUES:
                    day = parse_date(league_rows[0].get("Date")) or self.today
                    out.extend(parse_main_rows(league_rows, code, season_code(season_start_year(day))))
        body = self.cache.get(f"{self.base_url}/new_league_fixtures.csv", max_age)
        if body:
            for row in read_csv_rows(body):
                league = EXTRA_BY_COUNTRY.get((row.get("Country") or "").strip().lower())
                if league is not None:
                    out.extend(parse_extra_rows([row], league.code))
        return [m for m in out if not m.played]

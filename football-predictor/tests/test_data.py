from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest

from footy_predictor.data import (DataError, FootballDataSource, HttpCache, parse_date,
                                  parse_extra_rows, parse_kickoff, parse_main_rows, read_csv_rows,
                                  season_code, season_start_year)
from footy_predictor.leagues import LEAGUES, resolve_leagues

MAIN_CSV = (
    "﻿Div,Date,Time,HomeTeam,AwayTeam,FTHG,FTAG,FTR,HxG,AxG,B365H,B365D,B365A,AvgH,AvgD,AvgA,"
    "B365>2.5,B365<2.5,Avg>2.5,Avg<2.5\n"
    "E0,21/08/2026,20:00,Arsenal,Coventry,3,0,H,1.88,0.2,1.2,7,13,1.19,6.77,14.19,1.57,2.38,1.55,2.38\n"
    "E0,05/12/2026,15:00,Hull,Man United,,,,,,8.5,5,1.36,,,,,,,\n"
    ",,,,,,,,,,,,,,,,,,,\n"
).encode("utf-8")

EXTRA_FIXTURES = (
    "Country\tLeague\tDate\tTime\tHome\tAway\tPSH\tPSD\tPSA\tAvgH\tAvgD\tAvgA\n"
    "Mexico\tLiga MX\t26/09/2026\t02:00\tAtlante\tMonterrey\t\t\t\t3.37\t3.57\t1.95\n"
    "Narnia\tLeague\t26/09/2026\t02:00\tA\tB\t\t\t\t2\t3\t4\n"
).encode("utf-8")


def test_parse_main_rows_prefers_market_average_odds_and_reads_xg():
    matches = parse_main_rows(read_csv_rows(MAIN_CSV), "E0", "2627")
    assert len(matches) == 2
    played, fixture = matches
    assert played.played and (played.home_goals, played.away_goals) == (3, 0)
    assert played.odds_1x2 == (1.19, 6.77, 14.19)  # Avg preferred over B365
    assert played.odds_ou25 == (1.55, 2.38)
    assert (played.home_xg, played.away_xg) == (1.88, 0.2)
    assert played.kickoff == datetime(2026, 8, 21, 19, 0, tzinfo=timezone.utc)  # BST -> UTC
    assert not fixture.played
    assert fixture.odds_1x2 == (8.5, 5.0, 1.36)  # falls back to Bet365
    assert fixture.kickoff == datetime(2026, 12, 5, 15, 0, tzinfo=timezone.utc)  # GMT
    assert played.id == "E0|2026-08-21|Arsenal|Coventry"


def test_parse_extra_rows_tab_separated():
    rows = read_csv_rows(EXTRA_FIXTURES)
    matches = parse_extra_rows(rows[:1], "MEX")
    (m,) = matches
    assert (m.home, m.away, m.league) == ("Atlante", "Monterrey", "MEX")
    assert m.kickoff == datetime(2026, 9, 26, 1, 0, tzinfo=timezone.utc)
    assert m.odds_1x2 == (3.37, 3.57, 1.95)
    assert m.local_date(ZoneInfo("America/Mexico_City")) == date(2026, 9, 25)


def test_dates_seasons_and_times():
    assert parse_date("05/12/26") == date(2026, 12, 5)
    assert parse_date("2026-12-05") == date(2026, 12, 5)
    assert parse_date("nonsense") is None
    assert parse_kickoff(date(2026, 7, 1), "") is None
    assert parse_kickoff(date(2026, 7, 1), "25:00") is None
    assert season_start_year(date(2026, 6, 30)) == 2025
    assert season_start_year(date(2026, 7, 1)) == 2026
    assert season_code(2026) == "2627"
    assert season_code(1999) == "9900"


def test_resolve_leagues():
    assert [lg.code for lg in resolve_leagues("top5,E1")] == ["E0", "SP1", "D1", "I1", "F1", "E1"]
    assert len(resolve_leagues("all")) == len(LEAGUES)
    assert [lg.code for lg in resolve_leagues(["e0", "E0"])] == ["E0"]
    with pytest.raises(ValueError):
        resolve_leagues("XX9")


class StubCache:
    def __init__(self, files):
        self.files = files
        self.requests = []

    def get(self, url, max_age):
        self.requests.append((url, max_age))
        return self.files.get(url)


def test_source_results_and_fixtures():
    base = "https://football-data.co.uk"
    files = {
        f"{base}/mmz4281/2627/E0.csv": MAIN_CSV,
        f"{base}/fixtures.csv": MAIN_CSV,
        f"{base}/new_league_fixtures.csv": EXTRA_FIXTURES,
    }
    cache = StubCache(files)
    source = FootballDataSource(cache, today=date(2026, 9, 25))  # type: ignore[arg-type]
    results = source.results(LEAGUES["E0"], date(2026, 8, 1), date(2026, 12, 31))
    assert [m.home for m in results] == ["Arsenal"]  # only played matches
    fixtures = source.fixtures()
    assert {(m.league, m.home) for m in fixtures} == {("E0", "Hull"), ("MEX", "Atlante")}
    # Current season files are refreshed, finished seasons cached forever.
    source.results(LEAGUES["E0"], date(2024, 8, 1), date(2024, 9, 1))
    ages = {url.rsplit("/", 2)[-2]: age for url, age in cache.requests if "mmz4281" in url}
    assert ages["2627"] is not None and ages["2425"] is None


def test_http_cache_offline_and_stale_fallback(tmp_path, monkeypatch):
    cache = HttpCache(tmp_path, offline=True)
    assert cache.get("https://example.com/a.csv", timedelta(hours=1)) is None
    online = HttpCache(tmp_path)
    monkeypatch.setattr(online, "_download", lambda url: b"fresh")
    assert online.get("https://example.com/a.csv", timedelta(hours=1)) == b"fresh"
    assert cache.get("https://example.com/a.csv", timedelta(hours=1)) == b"fresh"

    def boom(url):
        raise OSError("network down")

    monkeypatch.setattr(online, "_download", boom)
    assert online.get("https://example.com/a.csv", timedelta(seconds=0)) == b"fresh"
    with pytest.raises(DataError):
        online.get("https://example.com/missing.csv", timedelta(hours=1))

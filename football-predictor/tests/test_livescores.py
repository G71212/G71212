"""football-data.org scores: the API client and matching its matches to ours."""

import io
import json
import urllib.error
import urllib.parse
from datetime import date, datetime, timedelta, timezone

import pytest

import footy_predictor.livescores as live
from footy_predictor.livescores import (LiveScoreError, Score, Wanted, fetch_scores, match_scores,
                                        name_similarity, parse_matches, wanted_fixtures)

KICKOFF = datetime(2026, 9, 19, 14, 0, tzinfo=timezone.utc)


def api_match(home, away, goals=(2, 1), code="PL", kickoff=KICKOFF, status="FINISHED",
              duration="REGULAR", short=None):
    return {
        "competition": {"code": code}, "utcDate": kickoff.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "status": status,
        "homeTeam": {"name": home, "shortName": short[0] if short else None, "tla": None},
        "awayTeam": {"name": away, "shortName": short[1] if short else None, "tla": None},
        "score": {"duration": duration, "fullTime": {"home": goals[0], "away": goals[1]}},
    }


def score(home, away, goals=(2, 1), code="PL", kickoff=KICKOFF):
    return Score(code, kickoff, (home,), (away,), *goals)


def wanted(home, away, league="E0", kickoff=KICKOFF):
    day = kickoff.date()
    return Wanted(f"{league}|{day}|{home}|{away}", league, kickoff, day, home, away)


def test_parse_keeps_only_finished_league_results():
    body = {"matches": [
        api_match("Manchester United FC", "Chelsea FC", (2, 1)),
        api_match("Arsenal FC", "Liverpool FC", status="IN_PLAY"),
        api_match("Everton FC", "Fulham FC", duration="PENALTY_SHOOTOUT"),
        {"status": "FINISHED", "utcDate": "garbage"},
    ]}
    (only,) = parse_matches(body)
    assert only.home == ("Manchester United FC",) and (only.home_goals, only.away_goals) == (2, 1)
    assert only.kickoff == KICKOFF and only.competition == "PL"


@pytest.mark.parametrize("ours,theirs", [
    ("Man United", "Manchester United FC"), ("Nott'm Forest", "Nottingham Forest FC"),
    ("Wolves", "Wolverhampton Wanderers FC"), ("Sheffield Weds", "Sheffield Wednesday FC"),
    ("Ath Madrid", "Club Atlético de Madrid"), ("Paris SG", "Paris Saint-Germain FC"),
    ("M'gladbach", "Borussia Mönchengladbach"), ("St Pauli", "FC St. Pauli 1910"),
    ("Espanol", "RCD Espanyol de Barcelona"), ("Sp Lisbon", "Sporting Clube de Portugal"),
    ("Bayern Munich", "FC Bayern München"), ("Rennes", "Stade Rennais FC 1901"),
    ("Lyon", "Olympique Lyonnais"), ("Dortmund", "Borussia Dortmund"),
])
def test_team_names_from_both_sites_match(ours, theirs):
    assert name_similarity(ours, [theirs]) >= 0.5


@pytest.mark.parametrize("ours,theirs", [
    ("Man City", "Manchester United FC"), ("Sheffield Weds", "Sheffield United FC"),
    ("Paris FC", "Paris Saint-Germain FC"), ("West Brom", "West Ham United FC"),
])
def test_different_clubs_do_not_match(ours, theirs):
    assert name_similarity(ours, [theirs]) < 0.5


def test_matching_uses_competition_kickoff_and_both_names():
    ours = [wanted("Man United", "Chelsea"), wanted("Man City", "Arsenal"),
            wanted("Wolves", "Everton", kickoff=KICKOFF + timedelta(hours=6)),
            wanted("Inter", "Roma", league="I1")]
    theirs = [score("Manchester City FC", "Arsenal FC", (1, 1)),
              score("Manchester United FC", "Chelsea FC", (2, 0)),
              score("Wolverhampton Wanderers FC", "Everton FC", (0, 0)),  # 6 hours off: not it
              score("FC Internazionale Milano", "AS Roma", (3, 1), code="SA")]
    found = match_scores(ours, theirs)
    assert found == {ours[0].match_id: (2, 0), ours[1].match_id: (1, 1), ours[3].match_id: (3, 1)}


def test_unclear_pairings_are_left_for_the_main_source():
    ours = [wanted("Brighton", "Burnley")]
    theirs = [score("Aston Villa FC", "Brentford FC"), score("Bournemouth AFC", "Burnley FC", (4, 4))]
    assert match_scores(ours, theirs) == {}  # one weak name is not enough


def test_fetch_sends_the_key_and_splits_long_ranges(monkeypatch):
    calls = []

    def fake_urlopen(request, timeout):
        calls.append((request.full_url, request.get_header("X-auth-token")))
        query = urllib.parse.parse_qs(urllib.parse.urlparse(request.full_url).query)
        start = date.fromisoformat(query["dateFrom"][0])
        stop = date.fromisoformat(query["dateTo"][0])
        assert (stop - start).days <= 9  # the API's limit is 10 days
        matches = [api_match("Home FC", "Away FC", kickoff=datetime(d.year, d.month, d.day, 15, tzinfo=timezone.utc))
                   for d in (start + timedelta(days=i) for i in range((stop - start).days + 1))]
        return io.BytesIO(json.dumps({"matches": matches}).encode())

    monkeypatch.setattr(live.urllib.request, "urlopen", fake_urlopen)
    scores = fetch_scores("secret-key", date(2026, 9, 1), date(2026, 9, 20), ["PL", "SA"])
    assert len(calls) == 3 and all(token == "secret-key" for _, token in calls)
    assert "competitions=PL%2CSA" in calls[0][0] and "status=FINISHED" in calls[0][0]
    days = sorted(s.kickoff.date() for s in scores)
    assert days[0] == date(2026, 9, 1) and days[-1] == date(2026, 9, 20) and len(days) == 20


def test_refused_key_is_reported_without_revealing_it(monkeypatch):
    def refuse(request, timeout):
        raise urllib.error.HTTPError(request.full_url, 403, "Forbidden", {},
                                     io.BytesIO(b'{"message": "Your API token is invalid."}'))

    monkeypatch.setattr(live.urllib.request, "urlopen", refuse)
    with pytest.raises(LiveScoreError) as info:
        fetch_scores("secret-key", date(2026, 9, 1), date(2026, 9, 2), ["PL"])
    assert "403" in str(info.value) and "invalid" in str(info.value)
    assert "secret-key" not in str(info.value)


def test_only_finished_fixtures_in_covered_leagues_are_looked_up():
    record = {"fixtures": [
        {"id": "E0|a", "league": "E0", "date": "2026-09-19", "kickoff": "2026-09-19T14:00:00+00:00",
         "home": "A", "away": "B", "result": None},
        {"id": "E0|b", "league": "E0", "date": "2026-09-19", "kickoff": "2026-09-19T19:00:00+00:00",
         "home": "C", "away": "D", "result": None},  # still being played
        {"id": "E0|c", "league": "E0", "date": "2026-09-19", "kickoff": "2026-09-19T12:00:00+00:00",
         "home": "E", "away": "F", "result": [1, 0]},  # already has its score
        {"id": "E2|d", "league": "E2", "date": "2026-09-19", "kickoff": "2026-09-19T14:00:00+00:00",
         "home": "G", "away": "H", "result": None},  # League One: not on football-data.org's free plan
    ]}
    now = datetime(2026, 9, 19, 20, 0, tzinfo=timezone.utc)
    assert [w.match_id for w in wanted_fixtures([record], now)] == ["E0|a"]

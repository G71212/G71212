from datetime import date, datetime, timedelta, timezone

from footy_predictor.engine import Prediction
from footy_predictor.history import (HistoryStore, grade_day, merge_day, pending_leagues,
                                     track_record)
from footy_predictor.markets import market_probabilities, score_matrix
from footy_predictor.selection import SelectionSettings, select_picks
from helpers import fixture

DAY = date(2026, 9, 26)
MORNING = datetime(2026, 9, 26, 6, 0, tzinfo=timezone.utc)


def prediction(home, away, lam, mu, hour=15):
    match = fixture("E0", DAY, home, away, hour=hour, odds_ou25=(1.6, 2.4))
    probs = market_probabilities(score_matrix(lam, mu, -0.08))
    return Prediction(match, probs, lam, mu, lam, mu, None, 20, 20)


def day_record(preds, now=MORNING, existing=None):
    return merge_day(existing, DAY, preds, select_picks(preds, SelectionSettings()), now)


def test_merge_records_fixtures_and_picks():
    preds = [prediction("A", "B", 2.8, 1.9), prediction("C", "D", 1.0, 0.7)]
    record = day_record(preds)
    assert record["date"] == "2026-09-26"
    assert len(record["fixtures"]) == 2
    over = record["picks"]["over25"]
    assert [p["home"] for p in over] == ["A"]
    assert over[0]["status"] == "pending" and over[0]["market_odds"] == 1.6


def test_published_picks_are_frozen():
    record = day_record([prediction("A", "B", 2.8, 1.9)])
    first = dict(record["picks"]["over25"][0])
    # A later run with very different numbers must not rewrite the published pick.
    later = MORNING + timedelta(hours=3)
    record = day_record([prediction("A", "B", 3.5, 2.5)], now=later, existing=record)
    assert record["picks"]["over25"] == [first]
    assert record["fixtures"][0]["expected_goals"] == [2.8, 1.9]


def test_no_new_picks_after_kick_off():
    record = day_record([prediction("A", "B", 2.8, 1.9)])
    afternoon = datetime(2026, 9, 26, 16, 0, tzinfo=timezone.utc)
    late = [prediction("E", "F", 3.0, 2.0, hour=14), prediction("G", "H", 3.0, 2.0, hour=19)]
    record = day_record(late, now=afternoon, existing=record)
    homes = {p["home"] for p in record["picks"]["over25"]}
    assert homes == {"A", "G"}  # E v F kicked off at 14:00, before this run
    # A match first seen after kick-off is not recorded at all; A v B (seen earlier) stays.
    assert {f["home"] for f in record["fixtures"]} == {"A", "G"}


def test_fixtures_recorded_after_kick_off_are_dropped_from_old_records():
    record = day_record([prediction("A", "B", 2.8, 1.9), prediction("C", "D", 1.0, 0.7)])
    stale = next(f for f in record["fixtures"] if f["home"] == "C")
    stale["predicted_at"] = "2026-09-26T16:00:00+00:00"  # written after its 15:00 kick-off
    record = day_record([], now=MORNING + timedelta(hours=12), existing=record)
    assert [f["home"] for f in record["fixtures"]] == ["A"]
    assert [p["home"] for p in record["picks"]["over25"]] == ["A"]


def test_grading_and_void():
    record = day_record([prediction("A", "B", 2.8, 1.9), prediction("C", "D", 2.9, 2.0)])
    assert pending_leagues([record]) == {"E0"}
    ids = {p["home"]: p["match_id"] for p in record["picks"]["over25"]}
    assert grade_day(record, {ids["A"]: (2, 1)}, DAY + timedelta(days=1))
    status = {p["home"]: p["status"] for p in record["picks"]["over25"]}
    assert status == {"A": "won", "C": "pending"}
    assert record["fixtures"][0]["result"] == [2, 1]
    # No result long after the match date -> void; a late result still settles it.
    assert grade_day(record, {}, DAY + timedelta(days=11))
    assert {p["home"]: p["status"] for p in record["picks"]["over25"]}["C"] == "void"
    assert grade_day(record, {ids["C"]: (0, 0)}, DAY + timedelta(days=12))
    assert {p["home"]: p["status"] for p in record["picks"]["over25"]}["C"] == "lost"
    assert not grade_day(record, {ids["C"]: (0, 0)}, DAY + timedelta(days=12))


def test_track_record_windows():
    record = day_record([prediction("A", "B", 2.8, 1.9), prediction("C", "D", 2.9, 2.0)])
    ids = {p["home"]: p["match_id"] for p in record["picks"]["over25"]}
    grade_day(record, {ids["A"]: (2, 1), ids["C"]: (1, 0)}, DAY + timedelta(days=1))
    summary = track_record([record], DAY + timedelta(days=1))["over25"]
    assert summary["7d"]["settled"] == 2 and summary["7d"]["won"] == 1
    assert summary["7d"]["hit_rate"] == 0.5
    assert summary["7d"]["roi"] == round(((1.6 - 1) - 1) / 2, 4)
    old = track_record([record], DAY + timedelta(days=40))["over25"]
    assert old["30d"]["settled"] == 0 and old["all"]["settled"] == 2


def test_history_store_round_trip(tmp_path):
    store = HistoryStore(tmp_path / "history")
    assert store.all() == [] and store.load(DAY) is None
    record = day_record([prediction("A", "B", 2.8, 1.9)])
    store.save(record)
    assert store.load(DAY) == record
    assert store.all() == [record]


def test_tiers_are_stored_and_bankers_have_their_own_track_record():
    safe = prediction("Fav", "Dog", 3.4, 1.6)  # Over 2.5 ~ 90% -> banker
    record = day_record([safe, prediction("C", "D", 1.9, 1.3)])
    over = {p["home"]: p for p in record["picks"]["over25"]}
    assert over["Fav"]["tier"] == "banker"
    grade_day(record, {over["Fav"]["match_id"]: (3, 1)}, DAY + timedelta(days=1))
    bankers = track_record([record], DAY + timedelta(days=1))["bankers"]["7d"]
    assert bankers["settled"] >= 1 and bankers["won"] == bankers["settled"]


def test_backfill_tiers_labels_old_picks_without_changing_them():
    from footy_predictor.history import backfill_tiers
    record = day_record([prediction("Fav", "Dog", 3.4, 1.6), prediction("C", "D", 1.9, 1.3)])
    for picks in record["picks"].values():
        for p in picks:
            p.pop("tier")  # as published before tiers existed
    before = {k: [dict(p) for p in v] for k, v in record["picks"].items()}
    backfill_tiers(record, SelectionSettings())
    assert {p["home"]: p["tier"] for p in record["picks"]["over25"]}["Fav"] == "banker"
    for market, picks in record["picks"].items():
        assert [{k: v for k, v in p.items() if k != "tier"} for p in picks] == before[market]


def test_provisional_scores_are_confirmed_or_corrected_by_the_main_source():
    record = day_record([prediction("A", "B", 2.8, 1.9)])
    pick = record["picks"]["over25"][0]
    match_id = pick["match_id"]
    # A faster source says 2-1: graded at once, flagged as provisional.
    assert grade_day(record, {match_id: (2, 1)}, DAY, provisional=True)
    assert (pick["status"], pick["result"], pick["provisional"]) == ("won", [2, 1], True)
    assert record["fixtures"][0]["result"] == [2, 1] and record["fixtures"][0]["provisional"]
    assert pending_leagues([record]) == {"E0"}  # still waiting for confirmation
    # Another provisional score never overrides the first one.
    assert not grade_day(record, {match_id: (0, 0)}, DAY, provisional=True)
    # football-data.co.uk has 1-1 (the fast source was wrong): the grade is corrected.
    assert grade_day(record, {match_id: (1, 1)}, DAY)
    assert (pick["status"], pick["result"]) == ("lost", [1, 1]) and "provisional" not in pick
    assert record["fixtures"][0]["result"] == [1, 1] and "provisional" not in record["fixtures"][0]
    assert pending_leagues([record]) == set()
    assert not grade_day(record, {match_id: (1, 1)}, DAY)


def test_confirming_a_provisional_score_only_clears_the_flag():
    record = day_record([prediction("A", "B", 2.8, 1.9)])
    pick = record["picks"]["over25"][0]
    grade_day(record, {pick["match_id"]: (3, 0)}, DAY, provisional=True)
    assert grade_day(record, {pick["match_id"]: (3, 0)}, DAY)
    assert (pick["status"], pick["result"]) == ("won", [3, 0]) and "provisional" not in pick


def test_provisional_scores_never_void_picks():
    record = day_record([prediction("A", "B", 2.8, 1.9)])
    late = DAY + timedelta(days=30)
    assert not grade_day(record, {}, late, provisional=True)
    assert record["picks"]["over25"][0]["status"] == "pending"

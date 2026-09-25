from datetime import date

import pytest

from footy_predictor.engine import Prediction
from footy_predictor.markets import market_probabilities, score_matrix
from footy_predictor.selection import (MarketRule, SelectionSettings, candidate, is_winner,
                                       select_picks)
from helpers import fixture

DAY = date(2026, 9, 26)


def prediction(home, away, lam, mu, matches=20, odds_1x2=None, odds_ou25=None):
    probs = market_probabilities(score_matrix(lam, mu, -0.08))
    match = fixture("E0", DAY, home, away, odds_1x2=odds_1x2, odds_ou25=odds_ou25)
    return Prediction(match, probs, lam, mu, lam, mu, None, matches, matches)


def test_picks_respect_threshold_order_and_cap():
    preds = [
        prediction("Goals FC", "Leaky", 2.6, 1.9),
        prediction("Mid", "Mid B", 1.5, 1.2),
        prediction("Tight", "Park Bus", 0.8, 0.6),
        prediction("More Goals", "Leakier", 2.9, 2.1),
    ]
    settings = SelectionSettings(over25=MarketRule(min_probability=0.6, max_picks=1))
    picks = select_picks(preds, settings)["over25"]
    assert len(picks) == 1
    assert picks[0].prediction.match.home == "More Goals"
    assert picks[0].selection == "Over 2.5"
    assert picks[0].fair_odds == pytest.approx(1 / picks[0].probability)


def test_low_data_matches_are_skipped():
    preds = [prediction("New", "Old", 3.0, 2.0, matches=1)]
    assert select_picks(preds, SelectionSettings(min_team_matches=4))["over25"] == []
    assert len(select_picks(preds, SelectionSettings(min_team_matches=0))["over25"]) == 1


def test_disabled_market_returns_no_picks():
    preds = [prediction("A", "B", 3.0, 2.0)]
    settings = SelectionSettings(btts=MarketRule(enabled=False, min_probability=0.1))
    assert select_picks(preds, settings)["btts"] == []


def test_min_edge_only_filters_priced_selections():
    priced = prediction("A", "B", 2.4, 1.6, odds_ou25=(1.20, 4.5))  # price far below fair
    unpriced = prediction("C", "D", 2.4, 1.6)
    settings = SelectionSettings(over25=MarketRule(min_probability=0.5, min_edge=0.0))
    picks = select_picks([priced, unpriced], settings)["over25"]
    assert [p.prediction.match.home for p in picks] == ["C"]
    assert picks[0].edge is None


def test_double_chance_candidate_uses_synthetic_price():
    pred = prediction("Fav", "Dog", 2.2, 0.7, odds_1x2=(1.5, 4.2, 7.0))
    selection, prob, price = candidate(pred, "double_chance")
    assert selection == "1X"
    assert prob == pytest.approx(pred.probs.dc_1x)
    assert price == pytest.approx(1 / (1 / 1.5 + 1 / 4.2))


@pytest.mark.parametrize("market,selection,score,expected", [
    ("over25", "Over 2.5", (2, 1), True),
    ("over25", "Over 2.5", (1, 1), False),
    ("btts", "BTTS Yes", (1, 1), True),
    ("btts", "BTTS Yes", (3, 0), False),
    ("btts_over25", "BTTS & Over 2.5", (2, 1), True),
    ("btts_over25", "BTTS & Over 2.5", (1, 1), False),
    ("btts_over25", "BTTS & Over 2.5", (3, 0), False),
    ("double_chance", "1X", (0, 0), True),
    ("double_chance", "1X", (0, 1), False),
    ("double_chance", "X2", (1, 1), True),
    ("double_chance", "12", (1, 1), False),
    ("double_chance", "12", (0, 2), True),
])
def test_is_winner(market, selection, score, expected):
    assert is_winner(market, selection, *score) is expected


def test_selection_settings_validation():
    with pytest.raises(ValueError):
        SelectionSettings(over25=MarketRule(min_probability=1.2)).validate()
    SelectionSettings().validate()


def ladder(n=30):
    """Matches with steadily rising total goals, so Over 2.5 chances run from ~20% to ~85%."""
    return [prediction(f"H{i:02d}", f"A{i:02d}", 0.6 + 0.08 * i, 0.5 + 0.03 * i) for i in range(n)]


def test_lists_are_topped_up_to_min_picks_with_extra_picks():
    settings = SelectionSettings(over25=MarketRule(min_probability=0.75, min_picks=15, floor=0.5,
                                                   max_picks=20))
    picks = select_picks(ladder(), settings)["over25"]
    strong = [p for p in picks if p.tier != "extra"]
    extra = [p for p in picks if p.tier == "extra"]
    assert len(picks) == 15
    assert strong and extra
    assert all(p.probability >= 0.75 for p in strong)
    assert all(0.5 <= p.probability < 0.75 for p in extra)
    assert [p.probability for p in picks] == sorted((p.probability for p in picks), reverse=True)


def test_floor_limits_the_top_up():
    settings = SelectionSettings(over25=MarketRule(min_probability=0.75, min_picks=30, floor=0.6,
                                                   max_picks=30))
    picks = select_picks(ladder(), settings)["over25"]
    assert 0 < len(picks) < 30  # not enough matches above the floor
    assert min(p.probability for p in picks) >= 0.6


def test_max_picks_caps_strong_picks_and_skips_top_up():
    settings = SelectionSettings(over25=MarketRule(min_probability=0.3, min_picks=15, floor=0.3,
                                                   max_picks=20))
    picks = select_picks(ladder(), settings)["over25"]
    assert len(picks) == 20 and all(p.tier != "extra" for p in picks)


def test_min_picks_is_clamped_to_max_picks():
    rule = MarketRule(min_probability=0.9, min_picks=15, floor=0.3, max_picks=5)
    assert rule.target == 5
    picks = select_picks(ladder(), SelectionSettings(over25=rule))["over25"]
    assert len(picks) == 5


def test_bankers_are_flagged():
    safe = prediction("Fav", "Dog", 3.0, 0.3, odds_1x2=(1.15, 8.0, 17.0))
    tight = prediction("Even", "Match", 1.2, 1.1)
    picks = select_picks([safe, tight], SelectionSettings())["double_chance"]
    tiers = {p.prediction.match.home: p.tier for p in picks}
    assert tiers["Fav"] == "banker"
    assert tiers.get("Even", "extra") != "banker"
    assert SelectionSettings().btts.banker_probability is None  # BTTS never gets that sure


def test_floor_must_not_exceed_min_probability():
    with pytest.raises(ValueError):
        MarketRule(min_probability=0.6, floor=0.7).validate("over25")
    with pytest.raises(ValueError):
        MarketRule(min_probability=0.8, banker_probability=0.7).validate("double_chance")

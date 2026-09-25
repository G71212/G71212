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

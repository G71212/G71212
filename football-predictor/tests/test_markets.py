import math

import numpy as np
import pytest

from footy_predictor.markets import (MarketView, blend_rates, devig, double_chance_odds,
                                     implied_supremacy, implied_total_goals, market_probabilities,
                                     market_view, poisson_pmf, prob_over25, score_matrix)


@pytest.mark.parametrize("lam,mu,rho", [(1.5, 1.1, -0.1), (0.6, 2.2, 0.05), (2.9, 0.3, 0.0)])
def test_score_matrix_is_a_distribution(lam, mu, rho):
    matrix = score_matrix(lam, mu, rho)
    assert matrix.shape == (13, 13)
    assert matrix.min() >= 0
    assert matrix.sum() == pytest.approx(1.0)


def test_dixon_coles_correction_keeps_marginals_and_totals():
    plain = score_matrix(1.4, 1.2, 0.0, 15)
    corrected = score_matrix(1.4, 1.2, -0.12, 15)
    np.testing.assert_allclose(plain.sum(axis=1), corrected.sum(axis=1), atol=1e-12)
    np.testing.assert_allclose(plain.sum(axis=0), corrected.sum(axis=0), atol=1e-12)
    a, b = market_probabilities(plain), market_probabilities(corrected)
    assert a.over25 == pytest.approx(b.over25, abs=1e-12)
    assert b.draw > a.draw  # negative rho inflates 0-0 and 1-1
    assert corrected[0, 0] > plain[0, 0] and corrected[1, 1] > plain[1, 1]


def test_over25_matches_closed_form():
    matrix = score_matrix(1.3, 1.45, -0.08, 20)
    assert market_probabilities(matrix).over25 == pytest.approx(prob_over25(2.75), abs=1e-9)


def test_combined_market_is_btts_minus_one_one():
    matrix = score_matrix(1.7, 1.3, -0.1)
    p = market_probabilities(matrix)
    assert p.btts_over25 == pytest.approx(p.btts - matrix[1, 1])
    # Correlated events: joint probability sits between these Frechet bounds...
    assert max(0.0, p.btts + p.over25 - 1) <= p.btts_over25 <= min(p.btts, p.over25)
    # ...and is well above the naive independent product.
    assert p.btts_over25 > p.btts * p.over25


def test_outcomes_and_double_chance_add_up():
    p = market_probabilities(score_matrix(0.8, 1.9, -0.05))
    assert p.home + p.draw + p.away == pytest.approx(1.0)
    assert p.dc_1x == pytest.approx(1 - p.away)
    assert p.dc_x2 == pytest.approx(1 - p.home)
    assert p.dc_12 == pytest.approx(1 - p.draw)
    selection, prob = p.best_double_chance()
    assert selection == "X2" and prob == pytest.approx(max(p.dc_1x, p.dc_x2, p.dc_12))


def test_twelve_is_chosen_when_the_draw_is_least_likely():
    p = market_probabilities(score_matrix(2.4, 2.3, 0.0))
    assert p.best_double_chance()[0] == "12"


def test_expected_goals_and_top_scores():
    p = market_probabilities(score_matrix(1.8, 0.9, 0.0, 20))
    assert p.exp_home == pytest.approx(1.8, abs=1e-6)
    assert p.exp_away == pytest.approx(0.9, abs=1e-6)
    assert len(p.top_scores) == 3
    assert p.top_scores[0][1] >= p.top_scores[1][1] >= p.top_scores[2][1]


def test_poisson_pmf_edge_cases():
    assert poisson_pmf(0.0, 5)[0] == 1.0
    np.testing.assert_allclose(poisson_pmf(2.0, 60 // 2).sum(), 1.0, atol=1e-9)
    assert poisson_pmf(1.3, 4)[2] == pytest.approx(math.exp(-1.3) * 1.3 ** 2 / 2)


def test_devig_power_method():
    probs = devig([1.25, 5.5, 11.0])
    assert sum(probs) == pytest.approx(1.0)
    implied = [1 / 1.25, 1 / 5.5, 1 / 11.0]
    normalised = [p / sum(implied) for p in implied]
    # Power method trims long shots more than simple normalisation does.
    assert probs[2] < normalised[2] and probs[0] > normalised[0]
    assert devig([2.0, 2.0]) == pytest.approx([0.5, 0.5])


@pytest.mark.parametrize("total", [1.4, 2.5, 3.6])
def test_implied_total_round_trip(total):
    assert implied_total_goals(prob_over25(total)) == pytest.approx(total, abs=1e-6)


@pytest.mark.parametrize("lam,mu,rho", [(1.6, 1.1, -0.1), (0.7, 2.4, -0.05), (2.8, 0.4, 0.0)])
def test_implied_supremacy_round_trip(lam, mu, rho):
    p = market_probabilities(score_matrix(lam, mu, rho))
    supremacy = implied_supremacy(lam + mu, p.home - p.away, rho)
    assert supremacy == pytest.approx(lam - mu, abs=1e-4)


def test_market_view_uses_prices_and_falls_back_to_model():
    assert market_view(None, None, 1.4, 1.1, -0.1) is None
    only_1x2 = market_view((1.8, 3.6, 4.5), None, 1.4, 1.1, -0.1)
    assert only_1x2.over25 is None
    assert only_1x2.exp_home + only_1x2.exp_away == pytest.approx(2.5)  # model total kept
    assert only_1x2.exp_home > only_1x2.exp_away
    full = market_view((1.8, 3.6, 4.5), (1.7, 2.15), 1.4, 1.1, -0.1)
    assert full.exp_home + full.exp_away == pytest.approx(implied_total_goals(full.over25), abs=1e-6)


def test_blend_rates():
    view = MarketView(exp_home=2.0, exp_away=1.0)
    assert blend_rates((1.0, 1.0), view, 0.0) == (1.0, 1.0)
    assert blend_rates((1.0, 1.0), view, 1.0) == pytest.approx((2.0, 1.0))
    lam, mu = blend_rates((1.0, 1.0), view, 0.5)
    assert lam == pytest.approx(math.sqrt(2.0))
    assert blend_rates((1.2, 0.8), None, 0.9) == (1.2, 0.8)


def test_double_chance_odds():
    assert double_chance_odds(None, "1X") is None
    assert double_chance_odds((2.0, 4.0, 4.0), "1X") == pytest.approx(1 / (0.5 + 0.25))
    assert double_chance_odds((2.0, 4.0, 4.0), "12") == pytest.approx(1 / 0.75)

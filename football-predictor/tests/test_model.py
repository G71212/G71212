from datetime import date, timedelta

import numpy as np
import pytest

from footy_predictor.data import Match
from footy_predictor.model import DixonColesModel, InsufficientData, ModelSettings
from helpers import synthetic_league

AS_OF = date(2026, 7, 1)


def fit(matches, **overrides):
    settings = ModelSettings(**{"prior_strength": 2.0, **overrides})
    return DixonColesModel(settings).fit(matches, AS_OF)


def test_recovers_known_team_strengths():
    matches, truth = synthetic_league(n_teams=16, seasons=(2023, 2024, 2025), seed=3)
    model = fit(matches, half_life_days=10_000)
    attack = np.array([model.teams[t].attack for t in truth["teams"]])
    defence = np.array([model.teams[t].defence for t in truth["teams"]])
    assert np.corrcoef(np.log(attack), np.log(truth["attack"]))[0, 1] > 0.85
    assert np.corrcoef(np.log(defence), np.log(truth["defence"]))[0, 1] > 0.85
    assert model.home_adv == pytest.approx(truth["home_adv"], rel=0.1)
    assert model.rho < 0  # data generated with rho = -0.1
    assert model.n_matches == len(matches)


def test_expected_goals_favour_the_stronger_side():
    matches, truth = synthetic_league(seed=5)
    model = fit(matches)
    ranking = sorted(truth["teams"], key=lambda t: model.teams[t].attack / model.teams[t].defence)
    weak, strong = ranking[0], ranking[-1]
    lam, mu = model.expected_goals(strong, weak)
    assert lam > mu
    lam_rev, mu_rev = model.expected_goals(weak, strong)
    assert mu_rev > lam_rev
    assert lam > mu_rev  # home advantage


def test_ignores_future_and_too_old_matches():
    matches, _ = synthetic_league(seasons=(2021, 2022, 2023, 2024, 2025))
    cutoff = date(2025, 1, 1)
    model = DixonColesModel(ModelSettings(history_days=400)).fit(matches, cutoff)
    used = [m for m in matches if m.date < cutoff and (cutoff - m.date).days <= 400]
    assert model.n_matches == len(used)


def test_recent_form_counts_more_with_time_decay():
    matches, _ = synthetic_league(n_teams=10, seasons=(2024, 2025), seed=11)
    # "Team 00" suddenly scores five in every recent match.
    last = max(m.date for m in matches)
    boosted = []
    for m in matches:
        if m.home == "Team 00" and (last - m.date).days < 90:
            m = Match(m.league, m.season, m.date, m.home, m.away, m.kickoff, 5, m.away_goals)
        boosted.append(m)
    as_of = last + timedelta(days=1)
    fast = DixonColesModel(ModelSettings(half_life_days=60, prior_strength=2)).fit(boosted, as_of)
    slow = DixonColesModel(ModelSettings(half_life_days=5000, prior_strength=2)).fit(boosted, as_of)
    assert fast.teams["Team 00"].attack > slow.teams["Team 00"].attack


def test_promoted_and_relegated_priors():
    old, _ = synthetic_league(n_teams=10, seasons=(2024,), seed=2)
    new_season, _ = synthetic_league(n_teams=10, seasons=(2025,), seed=2,
                                     teams=[f"Team {i:02d}" for i in range(8)] + ["Up FC", "Down FC"])
    first_rounds = [m for m in new_season if m.date < date(2025, 8, 20)]
    settings = ModelSettings(prior_strength=24)
    model = DixonColesModel(settings).fit(old + first_rounds, date(2025, 8, 21),
                                         from_above={"Down FC"})
    up, down = model.teams["Up FC"], model.teams["Down FC"]
    assert up.newcomer and down.newcomer
    assert not model.teams["Team 00"].newcomer
    assert down.attack / down.defence > up.attack / up.defence
    # Teams never seen at all fall back to the matching prior.
    unknown = model.rating("Brand New FC")
    assert unknown.matches == 0 and unknown.attack == settings.newcomer_attack
    assert model.rating("Down FC").matches > 0


def test_unknown_relegated_team_uses_relegated_prior():
    matches, _ = synthetic_league(n_teams=10, seasons=(2024, 2025))
    model = DixonColesModel(ModelSettings()).fit(matches, AS_OF, from_above={"Fallen FC"})
    rating = model.rating("Fallen FC")
    assert rating.attack == ModelSettings().relegated_attack
    assert rating.defence == ModelSettings().relegated_defence


def test_expected_goals_blend_changes_targets():
    matches, _ = synthetic_league(n_teams=10, seasons=(2025,), seed=4)
    with_xg = [Match(m.league, m.season, m.date, m.home, m.away, m.kickoff, m.home_goals,
                     m.away_goals, home_xg=1.9 if m.home == "Team 01" else 1.0, away_xg=1.0)
               for m in matches]
    plain = DixonColesModel(ModelSettings(xg_weight=0.0, prior_strength=2)).fit(with_xg, AS_OF)
    blended = DixonColesModel(ModelSettings(xg_weight=0.8, prior_strength=2)).fit(with_xg, AS_OF)
    assert blended.teams["Team 01"].attack != pytest.approx(plain.teams["Team 01"].attack)


def test_needs_enough_matches():
    matches, _ = synthetic_league(n_teams=6, seasons=(2025,))
    with pytest.raises(InsufficientData):
        DixonColesModel(ModelSettings(min_league_matches=100)).fit(matches[:20], AS_OF)


def test_settings_validation():
    with pytest.raises(ValueError):
        ModelSettings(market_weight=1.5).validate()
    with pytest.raises(ValueError):
        ModelSettings(half_life_days=0).validate()
    ModelSettings().validate()


def test_fit_is_fast_enough_for_daily_use():
    import time
    matches, _ = synthetic_league(n_teams=24, seasons=(2023, 2024, 2025))
    start = time.perf_counter()
    DixonColesModel(ModelSettings()).fit(matches, AS_OF + timedelta(days=1))
    assert time.perf_counter() - start < 2.0

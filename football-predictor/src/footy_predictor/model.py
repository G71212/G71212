"""Time-weighted Dixon-Coles team-strength model.

Goals are modelled as

    home goals ~ Poisson(lambda),  lambda = base * home_adv * attack[home] * defence[away]
    away goals ~ Poisson(mu),      mu     = base * attack[away] * defence[home]

with the Dixon-Coles correction ``rho`` on the 0-0, 1-0, 0-1 and 1-1 scorelines.

Fitting details
---------------
* Matches are weighted by ``0.5 ** (age_days / half_life_days)`` so recent form
  counts more (Dixon & Coles, 1997).
* log(attack) and log(defence) get Gaussian priors worth ``prior_strength``
  pseudo-matches, centred on the league average - or, for teams new to the
  league, on weaker values (promoted) or stronger values (relegated from the
  division above). This stabilises early-season ratings. The penalised
  likelihood is maximised with Newton's method (it is concave, so this
  converges in a handful of steps).
* When expected-goals data is available the fitting target blends real goals
  with xG (scaled to the league's scoring rate), which is less noisy.
* ``rho`` is then fitted by 1-D maximum likelihood on the low scorelines.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date

import numpy as np

from .data import Match


class InsufficientData(ValueError):
    pass


@dataclass
class ModelSettings:
    # Defaults chosen by walk-forward backtests on 22 leagues, Aug 2024 - Jun 2026
    # (15,300 matches); see README "Accuracy".
    half_life_days: float = 365.0
    history_days: int = 1095
    prior_strength: float = 24.0
    newcomer_attack: float = 0.85
    newcomer_defence: float = 1.15
    relegated_attack: float = 1.15
    relegated_defence: float = 0.87
    xg_weight: float = 0.5
    # Share of the betting market's implied goal expectations in the final
    # forecast (0 = model only). The market is the sharpest single signal.
    market_weight: float = 0.85
    max_goals: int = 12
    min_league_matches: int = 60

    def validate(self) -> None:
        if self.half_life_days <= 0:
            raise ValueError("model.half_life_days must be > 0")
        if self.history_days < 30:
            raise ValueError("model.history_days must be >= 30")
        if self.prior_strength < 0:
            raise ValueError("model.prior_strength must be >= 0")
        for name in ("newcomer_attack", "newcomer_defence", "relegated_attack",
                     "relegated_defence"):
            if not 0.2 <= getattr(self, name) <= 3.0:
                raise ValueError(f"model.{name} must be between 0.2 and 3")
        for name in ("xg_weight", "market_weight"):
            if not 0.0 <= getattr(self, name) <= 1.0:
                raise ValueError(f"model.{name} must be between 0 and 1")
        if not 6 <= self.max_goals <= 20:
            raise ValueError("model.max_goals must be between 6 and 20")


@dataclass
class TeamRating:
    attack: float  # goals-scored multiplier (1.0 = league average)
    defence: float  # goals-conceded multiplier (1.0 = league average, higher = leakier)
    matches: int  # matches in the training window
    weight: float  # sum of time-decay weights of those matches
    newcomer: bool = False


@dataclass
class DixonColesModel:
    settings: ModelSettings = field(default_factory=ModelSettings)
    base: float = 1.2
    home_adv: float = 1.2
    rho: float = 0.0
    teams: dict[str, TeamRating] = field(default_factory=dict)
    n_matches: int = 0
    as_of: date | None = None
    from_above: frozenset[str] = frozenset()

    # ------------------------------------------------------------------ fitting
    def fit(self, matches: list[Match], as_of: date,
            from_above: frozenset[str] | set[str] = frozenset()) -> "DixonColesModel":
        """Fit on matches played before ``as_of``.

        ``from_above`` names teams seen in the division above; if one of them is
        new to this league it was relegated and gets the stronger prior.
        """
        cfg = self.settings
        self.from_above = frozenset(from_above)
        data = [
            m for m in matches
            if m.played and m.date < as_of and (as_of - m.date).days <= cfg.history_days
        ]
        if len(data) < cfg.min_league_matches:
            raise InsufficientData(
                f"only {len(data)} matches before {as_of} (need {cfg.min_league_matches})"
            )

        teams = sorted({m.home for m in data} | {m.away for m in data})
        index = {team: i for i, team in enumerate(teams)}
        n_teams, n_obs = len(teams), len(data)
        home_idx = np.array([index[m.home] for m in data])
        away_idx = np.array([index[m.away] for m in data])
        home_goals = np.array([m.home_goals for m in data], dtype=float)
        away_goals = np.array([m.away_goals for m in data], dtype=float)
        age = np.array([(as_of - m.date).days for m in data], dtype=float)
        weight = 0.5 ** (age / cfg.half_life_days)

        target_home, target_away = self._targets(data, home_goals, away_goals)

        # Newly promoted teams: no matches outside the latest season in the window.
        latest_season = max(data, key=lambda m: m.date).season
        seasons_by_team: dict[str, set[str]] = {}
        for m in data:
            seasons_by_team.setdefault(m.home, set()).add(m.season)
            seasons_by_team.setdefault(m.away, set()).add(m.season)
        multi_season = any(m.season != latest_season for m in data)
        newcomer = np.array(
            [multi_season and seasons_by_team[t] == {latest_season} for t in teams]
        )

        # Design matrix: [log base, log home_adv, log attack (n), log defence (n)].
        n_params = 2 + 2 * n_teams
        X = np.zeros((2 * n_obs, n_params))
        rows = np.arange(n_obs)
        X[:, 0] = 1.0
        X[:n_obs, 1] = 1.0
        X[rows, 2 + home_idx] = 1.0
        X[rows, 2 + n_teams + away_idx] = 1.0
        X[n_obs + rows, 2 + away_idx] = 1.0
        X[n_obs + rows, 2 + n_teams + home_idx] = 1.0
        t = np.concatenate([target_home, target_away])
        w = np.concatenate([weight, weight])

        mean_goals = max(float(np.average(t, weights=w)), 0.2)
        penalty = np.zeros(n_params)
        penalty[2:] = max(cfg.prior_strength, 1e-3) * mean_goals
        centre = np.zeros(n_params)
        for i, team in enumerate(teams):
            if newcomer[i]:
                attack0, defence0 = self._newcomer_prior(team)
                centre[2 + i] = math.log(attack0)
                centre[2 + n_teams + i] = math.log(defence0)
        start = centre.copy()
        mean_home = max(float(np.average(target_home, weights=weight)), 0.1)
        mean_away = max(float(np.average(target_away, weights=weight)), 0.1)
        start[0] = math.log(mean_away)
        start[1] = math.log(mean_home / mean_away)

        theta = _penalised_poisson(X, t, w, penalty, centre, start)

        self.base = math.exp(theta[0])
        self.home_adv = math.exp(theta[1])
        attack = np.exp(theta[2:2 + n_teams])
        defence = np.exp(theta[2 + n_teams:])
        counts = np.bincount(home_idx, minlength=n_teams) + np.bincount(away_idx, minlength=n_teams)
        weights = (np.bincount(home_idx, weights=weight, minlength=n_teams)
                   + np.bincount(away_idx, weights=weight, minlength=n_teams))
        self.teams = {
            team: TeamRating(float(attack[i]), float(defence[i]), int(counts[i]),
                             float(weights[i]), bool(newcomer[i]))
            for i, team in enumerate(teams)
        }
        lam = self.base * self.home_adv * attack[home_idx] * defence[away_idx]
        mu = self.base * attack[away_idx] * defence[home_idx]
        self.rho = _fit_rho(lam, mu, home_goals, away_goals, weight)
        self.n_matches = n_obs
        self.as_of = as_of
        return self

    def _targets(self, data: list[Match], home_goals: np.ndarray,
                 away_goals: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        """Blend goals with league-scaled xG where xG is available."""
        xg_weight = self.settings.xg_weight
        has_xg = np.array([m.home_xg is not None for m in data])
        if xg_weight <= 0 or has_xg.sum() < 10:
            return home_goals, away_goals
        home_xg = np.array([m.home_xg if m.home_xg is not None else 0.0 for m in data])
        away_xg = np.array([m.away_xg if m.away_xg is not None else 0.0 for m in data])
        total_xg = home_xg[has_xg].sum() + away_xg[has_xg].sum()
        total_goals = home_goals[has_xg].sum() + away_goals[has_xg].sum()
        scale = float(np.clip(total_goals / total_xg, 0.7, 1.3)) if total_xg > 0 else 1.0
        blend_home = np.where(has_xg, (1 - xg_weight) * home_goals + xg_weight * scale * home_xg,
                              home_goals)
        blend_away = np.where(has_xg, (1 - xg_weight) * away_goals + xg_weight * scale * away_xg,
                              away_goals)
        return blend_home, blend_away

    def _newcomer_prior(self, team: str) -> tuple[float, float]:
        if team in self.from_above:
            return self.settings.relegated_attack, self.settings.relegated_defence
        return self.settings.newcomer_attack, self.settings.newcomer_defence

    # ------------------------------------------------------------------ predicting
    def rating(self, team: str) -> TeamRating:
        """Fitted rating, or the newcomer prior for teams without data."""
        if team in self.teams:
            return self.teams[team]
        attack, defence = self._newcomer_prior(team)
        return TeamRating(attack, defence, 0, 0.0, True)

    def expected_goals(self, home: str, away: str) -> tuple[float, float]:
        h, a = self.rating(home), self.rating(away)
        lam = self.base * self.home_adv * h.attack * a.defence
        mu = self.base * a.attack * h.defence
        return lam, mu


def _penalised_poisson(X: np.ndarray, t: np.ndarray, w: np.ndarray, penalty: np.ndarray,
                       centre: np.ndarray, start: np.ndarray, max_iter: int = 100,
                       tol: float = 1e-9) -> np.ndarray:
    """Maximise sum w*(t*eta - exp(eta)) - 0.5*sum penalty*(theta-centre)^2 by Newton."""

    def objective(theta: np.ndarray) -> float:
        eta = np.clip(X @ theta, -20, 5)
        return float(np.sum(w * (t * eta - np.exp(eta)))
                     - 0.5 * np.sum(penalty * (theta - centre) ** 2))

    theta = start.copy()
    value = objective(theta)
    for _ in range(max_iter):
        lam = np.exp(np.clip(X @ theta, -20, 5))
        grad = X.T @ (w * (t - lam)) - penalty * (theta - centre)
        hess = (X * (w * lam)[:, None]).T @ X + np.diag(penalty + 1e-9)
        step = np.linalg.solve(hess, grad)
        scale = 1.0
        while True:
            candidate = theta + scale * step
            new_value = objective(candidate)
            if new_value >= value - 1e-10 or scale < 1e-4:
                break
            scale *= 0.5
        theta, value = candidate, new_value
        if float(np.max(np.abs(scale * step))) < tol:
            break
    return theta


def _fit_rho(lam: np.ndarray, mu: np.ndarray, home_goals: np.ndarray, away_goals: np.ndarray,
             weight: np.ndarray) -> float:
    """Weighted ML estimate of the Dixon-Coles low-score dependence parameter."""
    m00 = (home_goals == 0) & (away_goals == 0)
    m01 = (home_goals == 0) & (away_goals == 1)
    m10 = (home_goals == 1) & (away_goals == 0)
    m11 = (home_goals == 1) & (away_goals == 1)
    lo, hi = -0.25, 0.25
    eps = 1e-6
    if m00.any():
        hi = min(hi, float(np.min(1.0 / (lam[m00] * mu[m00]))) - eps)
    if m01.any():
        lo = max(lo, float(np.max(-1.0 / lam[m01])) + eps)
    if m10.any():
        lo = max(lo, float(np.max(-1.0 / mu[m10])) + eps)
    if lo >= hi:
        return 0.0

    def loglik(rho: float) -> float:
        total = 0.0
        total += float(np.sum(weight[m00] * np.log(1.0 - lam[m00] * mu[m00] * rho)))
        total += float(np.sum(weight[m01] * np.log(1.0 + lam[m01] * rho)))
        total += float(np.sum(weight[m10] * np.log(1.0 + mu[m10] * rho)))
        total += float(np.sum(weight[m11] * math.log(1.0 - rho)))
        return total

    # log-likelihood is concave in rho -> golden-section search is exact enough.
    golden = (math.sqrt(5) - 1) / 2
    a, b = lo, hi
    c, d = b - golden * (b - a), a + golden * (b - a)
    fc, fd = loglik(c), loglik(d)
    for _ in range(60):
        if fc > fd:
            b, d, fd = d, c, fc
            c = b - golden * (b - a)
            fc = loglik(c)
        else:
            a, c, fc = c, d, fd
            d = a + golden * (b - a)
            fd = loglik(d)
    return float((a + b) / 2)

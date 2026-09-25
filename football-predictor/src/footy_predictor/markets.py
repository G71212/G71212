"""Scoreline matrix -> market probabilities, plus bookmaker-odds helpers.

Every market is read off the same joint scoreline distribution, which matters
for the combined market: "BTTS & Over 2.5" is *not* P(BTTS) * P(Over 2.5)
because the two events are strongly positively correlated. From the matrix it
is exactly P(BTTS) - P(1-1), since 1-1 is the only BTTS scoreline with fewer
than three goals.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from functools import lru_cache
from typing import Callable, Sequence

import numpy as np

_LOG_FACTORIAL = np.array([math.lgamma(k + 1) for k in range(41)])


def poisson_pmf(rate: float, max_goals: int) -> np.ndarray:
    if rate <= 0:
        pmf = np.zeros(max_goals + 1)
        pmf[0] = 1.0
        return pmf
    k = np.arange(max_goals + 1)
    return np.exp(k * math.log(rate) - rate - _LOG_FACTORIAL[:max_goals + 1])


@lru_cache(maxsize=8)
def _masks(size: int) -> dict[str, np.ndarray]:
    goals = np.arange(size)
    home, away = goals[:, None], goals[None, :]
    return {
        "home": (home > away).astype(float),
        "away": (home < away).astype(float),
        "over25": (home + away >= 3).astype(float),
    }


def score_matrix(lam: float, mu: float, rho: float = 0.0, max_goals: int = 12) -> np.ndarray:
    """P(home goals = i, away goals = j) with the Dixon-Coles low-score correction."""
    matrix = np.outer(poisson_pmf(lam, max_goals), poisson_pmf(mu, max_goals))
    matrix[0, 0] *= 1.0 - lam * mu * rho
    matrix[0, 1] *= 1.0 + lam * rho
    matrix[1, 0] *= 1.0 + mu * rho
    matrix[1, 1] *= 1.0 - rho
    matrix = np.clip(matrix, 0.0, None)
    return matrix / matrix.sum()


@dataclass(frozen=True)
class MarketProbabilities:
    home: float
    draw: float
    away: float
    over25: float
    btts: float
    btts_over25: float
    exp_home: float
    exp_away: float
    top_scores: tuple[tuple[str, float], ...] = ()

    @property
    def under25(self) -> float:
        return 1.0 - self.over25

    @property
    def dc_1x(self) -> float:
        return self.home + self.draw

    @property
    def dc_x2(self) -> float:
        return self.draw + self.away

    @property
    def dc_12(self) -> float:
        return self.home + self.away

    def best_double_chance(self) -> tuple[str, float]:
        options = (("1X", self.dc_1x), ("X2", self.dc_x2), ("12", self.dc_12))
        return max(options, key=lambda item: item[1])

    def as_dict(self) -> dict[str, float]:
        return {
            "home": self.home, "draw": self.draw, "away": self.away,
            "over25": self.over25, "under25": self.under25,
            "btts": self.btts, "btts_over25": self.btts_over25,
            "dc_1x": self.dc_1x, "dc_x2": self.dc_x2, "dc_12": self.dc_12,
        }


def market_probabilities(matrix: np.ndarray, top_n: int = 3) -> MarketProbabilities:
    masks = _masks(matrix.shape[0])
    goals = np.arange(matrix.shape[0])
    btts = float(matrix[1:, 1:].sum())
    top: tuple[tuple[str, float], ...] = ()
    if top_n > 0:
        flat = np.argsort(matrix, axis=None)[::-1][:top_n]
        top = tuple(
            (f"{i}-{j}", float(matrix[i, j]))
            for i, j in (np.unravel_index(k, matrix.shape) for k in flat)
        )
    return MarketProbabilities(
        home=float(np.vdot(matrix, masks["home"])),
        draw=float(np.trace(matrix)),
        away=float(np.vdot(matrix, masks["away"])),
        over25=float(np.vdot(matrix, masks["over25"])),
        btts=btts,
        btts_over25=btts - float(matrix[1, 1]),
        exp_home=float(matrix.sum(axis=1) @ goals),
        exp_away=float(matrix.sum(axis=0) @ goals),
        top_scores=top,
    )


def _home_minus_away(lam: float, mu: float, rho: float, max_goals: int) -> float:
    matrix = score_matrix(lam, mu, rho, max_goals)
    masks = _masks(max_goals + 1)
    return float(np.vdot(matrix, masks["home"]) - np.vdot(matrix, masks["away"]))


def _solve_increasing(func: Callable[[float], float], lo: float, hi: float,
                      tol: float = 1e-10) -> float:
    """Root of an increasing function on [lo, hi] (Illinois regula falsi, clamped)."""
    f_lo, f_hi = func(lo), func(hi)
    if f_lo >= 0:
        return lo
    if f_hi <= 0:
        return hi
    side = 0
    mid = lo
    for _ in range(100):
        mid = (lo * f_hi - hi * f_lo) / (f_hi - f_lo)
        f_mid = func(mid)
        if abs(f_mid) < tol or hi - lo < tol:
            break
        if f_mid > 0:
            hi, f_hi = mid, f_mid
            if side == -1:
                f_lo /= 2
            side = -1
        else:
            lo, f_lo = mid, f_mid
            if side == 1:
                f_hi /= 2
            side = 1
    return mid


# --------------------------------------------------------------------------- odds


def devig(odds: Sequence[float]) -> list[float]:
    """Bookmaker odds -> fair probabilities using the power method.

    Finds k >= 1 with sum((1/o)^k) = 1, which removes proportionally more margin
    from long shots (the favourite-longshot bias) than plain normalisation.
    """
    implied = [1.0 / o for o in odds]
    booksum = sum(implied)
    if booksum <= 1.0:
        return [p / booksum for p in implied]
    lo, hi = 1.0, 10.0
    for _ in range(80):
        k = (lo + hi) / 2
        if sum(p ** k for p in implied) > 1.0:
            lo = k
        else:
            hi = k
    k = (lo + hi) / 2
    probs = [p ** k for p in implied]
    norm = sum(probs)
    return [p / norm for p in probs]


def prob_over25(total: float) -> float:
    """P(total goals >= 3) when total goals ~ Poisson(total).

    The Dixon-Coles correction leaves the distribution of the total unchanged,
    so this holds for the full model too.
    """
    return 1.0 - math.exp(-total) * (1.0 + total + total * total / 2.0)


def implied_total_goals(p_over: float) -> float:
    """Invert :func:`prob_over25` (expected total goals implied by an Over 2.5 price)."""
    p_over = min(max(p_over, 0.02), 0.98)
    return _solve_increasing(lambda total: prob_over25(total) - p_over, 0.05, 10.0)


def implied_supremacy(total: float, home_minus_away: float, rho: float,
                      max_goals: int = 12) -> float:
    """Goal supremacy (lambda - mu) that reproduces P(home) - P(away) at a fixed total."""
    return _solve_increasing(
        lambda s: _home_minus_away((total + s) / 2, (total - s) / 2, rho, max_goals)
        - home_minus_away,
        -0.97 * total, 0.97 * total, tol=1e-9,
    )


@dataclass(frozen=True)
class MarketView:
    """What the betting market implies for a match (fair, margin-free)."""

    home: float | None = None
    draw: float | None = None
    away: float | None = None
    over25: float | None = None
    exp_home: float | None = None
    exp_away: float | None = None

    def as_dict(self) -> dict[str, float | None]:
        return {"home": self.home, "draw": self.draw, "away": self.away, "over25": self.over25}


def market_view(odds_1x2: tuple[float, float, float] | None,
                odds_ou25: tuple[float, float] | None,
                model_lam: float, model_mu: float, rho: float, max_goals: int = 12) -> MarketView | None:
    """Market-implied probabilities and expected goals.

    The total comes from the Over/Under 2.5 price and the split from the 1X2
    price. A missing price falls back to the model's own total or split.
    """
    if odds_1x2 is None and odds_ou25 is None:
        return None
    home = draw = away = over = None
    total = model_lam + model_mu
    if odds_ou25 is not None:
        over = devig(odds_ou25)[0]
        total = implied_total_goals(over)
    if odds_1x2 is not None:
        home, draw, away = devig(odds_1x2)
        supremacy = implied_supremacy(total, home - away, rho, max_goals)
        exp_home, exp_away = (total + supremacy) / 2, (total - supremacy) / 2
    else:
        share = model_lam / (model_lam + model_mu)
        exp_home, exp_away = total * share, total * (1 - share)
    return MarketView(home, draw, away, over, exp_home, exp_away)


def blend_rates(model: tuple[float, float], market: MarketView | None,
                market_weight: float) -> tuple[float, float]:
    """Geometric blend of model and market expected goals."""
    if market is None or market.exp_home is None or market_weight <= 0:
        return model
    w = market_weight
    lam = math.exp((1 - w) * math.log(model[0]) + w * math.log(max(market.exp_home, 0.05)))
    mu = math.exp((1 - w) * math.log(model[1]) + w * math.log(max(market.exp_away, 0.05)))
    return lam, mu


def fair_odds(probability: float) -> float:
    return 1.0 / probability if probability > 0 else float("inf")


def double_chance_odds(odds_1x2: tuple[float, float, float] | None, selection: str) -> float | None:
    """Price of a double chance built from two 1X2 bets (a 'synthetic' double chance)."""
    if odds_1x2 is None:
        return None
    home, draw, away = odds_1x2
    pair = {"1X": (home, draw), "X2": (draw, away), "12": (home, away)}[selection]
    return 1.0 / (1.0 / pair[0] + 1.0 / pair[1])

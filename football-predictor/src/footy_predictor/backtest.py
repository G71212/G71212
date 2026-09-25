"""Walk-forward backtest.

Every ``refit_days`` the model is refitted using only matches played before
that day, then used to predict the following window - exactly what the daily
job does live, so the numbers are honest out-of-sample estimates. Market odds
used for blending are the pre-match odds (never closing odds).
"""

from __future__ import annotations

import logging
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Callable, Iterable

import numpy as np

from .data import DataError, DataSource, Match
from .leagues import LEAGUES, TIER_ABOVE, League
from .markets import (MarketProbabilities, MarketView, blend_rates, double_chance_odds,
                      market_probabilities, market_view, score_matrix)
from .model import DixonColesModel, InsufficientData, ModelSettings
from .selection import MARKET_TITLES, MARKETS, SelectionSettings, is_winner

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class BacktestRow:
    match: Match
    model_lam: float
    model_mu: float
    rho: float
    market: MarketView | None
    min_team_matches: int

    def probabilities(self, market_weight: float, max_goals: int = 12) -> MarketProbabilities:
        lam, mu = blend_rates((self.model_lam, self.model_mu), self.market, market_weight)
        return market_probabilities(score_matrix(lam, mu, self.rho, max_goals), top_n=0)


def collect_rows(source: DataSource, leagues: Iterable[League], start: date, end: date,
                 settings: ModelSettings, refit_days: int = 7,
                 progress: Callable[[str], None] | None = None) -> list[BacktestRow]:
    settings.validate()
    rows: list[BacktestRow] = []
    history_start = start - timedelta(days=settings.history_days)
    for league in leagues:
        try:
            matches = source.results(league, history_start, end)
            above = TIER_ABOVE.get(league.code)
            above_matches = source.results(LEAGUES[above], history_start, end) if above else []
        except DataError as exc:
            log.warning("Skipping %s: %s", league.code, exc)
            continue
        tests = sorted((m for m in matches if start <= m.date <= end), key=lambda m: m.date)
        if progress:
            progress(f"{league.code}: {len(tests)} matches")
        day = start
        while day <= end:
            window_end = day + timedelta(days=refit_days)
            window = [m for m in tests if day <= m.date < window_end]
            if window:
                lower = day - timedelta(days=settings.history_days)
                from_above = {t for m in above_matches if lower <= m.date < day
                              for t in (m.home, m.away)}
                try:
                    model = DixonColesModel(settings).fit(matches, day, from_above)
                except InsufficientData:
                    model = None
                if model is not None:
                    for m in window:
                        lam, mu = model.expected_goals(m.home, m.away)
                        view = market_view(m.odds_1x2, m.odds_ou25, lam, mu, model.rho,
                                           settings.max_goals)
                        seen = min(model.rating(m.home).matches, model.rating(m.away).matches)
                        rows.append(BacktestRow(m, lam, mu, model.rho, view, seen))
            day = window_end
    return rows


# --------------------------------------------------------------------------- metrics


def _brier(p: np.ndarray, y: np.ndarray) -> float:
    return float(np.mean((p - y) ** 2))


def _log_loss(p: np.ndarray, y: np.ndarray) -> float:
    p = np.clip(p, 1e-6, 1 - 1e-6)
    return float(-np.mean(y * np.log(p) + (1 - y) * np.log(1 - p)))


def _calibration(p: np.ndarray, y: np.ndarray, bins: int = 10) -> list[dict]:
    out = []
    edges = np.linspace(0, 1, bins + 1)
    for lo, hi in zip(edges[:-1], edges[1:]):
        mask = (p >= lo) & (p < hi if hi < 1 else p <= hi)
        if mask.sum():
            out.append({"bin": f"{lo:.1f}-{hi:.1f}", "n": int(mask.sum()),
                        "predicted": float(p[mask].mean()), "observed": float(y[mask].mean())})
    return out


def _pick_stats(p: np.ndarray, y: np.ndarray, odds: np.ndarray) -> dict:
    n = int(len(p))
    stats = {"n": n, "hits": int(y.sum()), "hit_rate": float(y.mean()) if n else None,
             "avg_probability": float(p.mean()) if n else None, "n_with_odds": 0, "roi": None}
    has_odds = ~np.isnan(odds)
    if has_odds.any():
        returns = np.where(y[has_odds] > 0, odds[has_odds] - 1.0, -1.0)
        stats["n_with_odds"] = int(has_odds.sum())
        stats["roi"] = float(returns.mean())
    return stats


def evaluate(rows: list[BacktestRow], market_weight: float, selection: SelectionSettings,
             max_goals: int = 12) -> dict:
    """Scores for all four markets plus pick hit-rates at the configured thresholds."""
    if not rows:
        return {"matches": 0, "markets": {}}
    probs = [r.probabilities(market_weight, max_goals) for r in rows]
    hg = np.array([r.match.home_goals for r in rows])
    ag = np.array([r.match.away_goals for r in rows])
    seen = np.array([r.min_team_matches for r in rows])
    days = np.array([r.match.date.toordinal() for r in rows])

    dc_choice = [p.best_double_chance() for p in probs]
    series = {
        "btts_over25": (np.array([p.btts_over25 for p in probs]),
                        ((hg > 0) & (ag > 0) & (hg + ag >= 3)).astype(float),
                        np.full(len(rows), np.nan)),
        "over25": (np.array([p.over25 for p in probs]), (hg + ag >= 3).astype(float),
                   np.array([r.match.odds_ou25[0] if r.match.odds_ou25 else np.nan for r in rows])),
        "btts": (np.array([p.btts for p in probs]), ((hg > 0) & (ag > 0)).astype(float),
                 np.full(len(rows), np.nan)),
        "double_chance": (
            np.array([c[1] for c in dc_choice]),
            np.array([is_winner("double_chance", c[0], int(h), int(a))
                      for c, h, a in zip(dc_choice, hg, ag)], dtype=float),
            np.array([double_chance_odds(r.match.odds_1x2, c[0]) or np.nan
                      for r, c in zip(rows, dc_choice)]),
        ),
    }

    markets = {}
    for market in MARKETS:
        p, y, odds = series[market]
        rule = selection.rule(market)
        eligible = seen >= selection.min_team_matches
        above = eligible & (p >= rule.min_probability)
        # Emulate the daily lists: up to max_picks strong picks, topped up to
        # min_picks with the next best matches down to the floor.
        capped = np.zeros(len(rows), dtype=bool)
        extra = np.zeros(len(rows), dtype=bool)
        for day in np.unique(days[eligible]):
            strong = np.where(above & (days == day))[0]
            strong = strong[np.argsort(-p[strong])][:rule.max_picks]
            capped[strong] = True
            need = rule.target - len(strong)
            if need > 0:
                rest = np.where(eligible & (days == day) & (p >= rule.floor) & ~above)[0]
                extra[rest[np.argsort(-p[rest])][:need]] = True
        bankers = (eligible & (p >= rule.banker_probability) if rule.banker_probability is not None
                   else np.zeros(len(rows), dtype=bool))
        base_rate = float(y.mean())
        sweep = []
        for threshold in np.arange(0.40, 0.96, 0.05):
            mask = eligible & (p >= threshold - 1e-9)
            if mask.sum() >= 20:
                sweep.append({"threshold": round(float(threshold), 2),
                              **_pick_stats(p[mask], y[mask], odds[mask])})
        markets[market] = {
            "title": MARKET_TITLES[market],
            "n": len(rows),
            "base_rate": base_rate,
            "brier": _brier(p, y),
            "brier_base_rate": base_rate * (1 - base_rate),
            "log_loss": _log_loss(p, y),
            "calibration": _calibration(p, y),
            "picks": {"threshold": rule.min_probability, **_pick_stats(p[above], y[above], odds[above])},
            "daily_picks": {"max_per_day": rule.max_picks,
                            **_pick_stats(p[capped], y[capped], odds[capped])},
            "extra_picks": {"min_per_day": rule.min_picks, "floor": rule.floor,
                            **_pick_stats(p[extra], y[extra], odds[extra])},
            "all_daily_picks": _pick_stats(p[capped | extra], y[capped | extra],
                                           odds[capped | extra]),
            "bankers": {"threshold": rule.banker_probability,
                        **_pick_stats(p[bankers], y[bankers], odds[bankers])},
            "threshold_sweep": sweep,
        }

    return {"matches": len(rows), "market_weight": market_weight, "markets": markets,
            "vs_market": _versus_market(rows, probs, hg, ag)}


def _versus_market(rows: list[BacktestRow], probs: list[MarketProbabilities], hg: np.ndarray,
                   ag: np.ndarray) -> dict:
    """Compare model/blend with the de-margined bookmaker prices where available."""
    out = {}
    ou = np.array([r.market is not None and r.market.over25 is not None for r in rows])
    if ou.any():
        y = (hg + ag >= 3).astype(float)[ou]
        ours = np.array([p.over25 for p in probs])[ou]
        mkt = np.array([r.market.over25 for r in rows if r.market is not None
                        and r.market.over25 is not None])
        out["over25"] = {"n": int(ou.sum()), "brier": _brier(ours, y),
                         "market_brier": _brier(mkt, y), "log_loss": _log_loss(ours, y),
                         "market_log_loss": _log_loss(mkt, y)}
    hx = np.array([r.market is not None and r.market.home is not None for r in rows])
    if hx.any():
        outcome = np.where(hg > ag, 0, np.where(hg == ag, 1, 2))[hx]
        ours = np.array([[p.home, p.draw, p.away] for p in probs])[hx]
        mkt = np.array([[r.market.home, r.market.draw, r.market.away] for r in rows
                        if r.market is not None and r.market.home is not None])
        out["1x2"] = {"n": int(hx.sum()), "rps": _rps(ours, outcome),
                      "market_rps": _rps(mkt, outcome),
                      "log_loss": _multi_log_loss(ours, outcome),
                      "market_log_loss": _multi_log_loss(mkt, outcome)}
    return out


def _rps(probs: np.ndarray, outcome: np.ndarray) -> float:
    """Ranked probability score for ordered outcomes (home, draw, away)."""
    actual = np.zeros_like(probs)
    actual[np.arange(len(outcome)), outcome] = 1.0
    diff = np.cumsum(probs, axis=1) - np.cumsum(actual, axis=1)
    return float(np.mean(np.sum(diff[:, :-1] ** 2, axis=1) / 2))


def _multi_log_loss(probs: np.ndarray, outcome: np.ndarray) -> float:
    chosen = np.clip(probs[np.arange(len(outcome)), outcome], 1e-6, 1.0)
    return float(-np.mean(np.log(chosen)))


def format_report(result: dict) -> str:
    """Human readable summary of :func:`evaluate`."""
    if not result.get("matches"):
        return "No matches to evaluate."
    pct = lambda v: "  -  " if v is None else f"{100 * v:5.1f}%"  # noqa: E731
    lines = [f"Backtest over {result['matches']} matches "
             f"(market weight {result['market_weight']:.2f})", ""]
    lines.append(f"{'Market':22s} {'base':>6s} {'Brier':>7s} {'skill':>6s} "
                 f"{'picks':>6s} {'hit%':>6s} {'exp%':>6s} {'ROI':>7s}   daily strong | extra | bankers")
    for market, m in result["markets"].items():
        skill = 1 - m["brier"] / m["brier_base_rate"] if m["brier_base_rate"] else 0.0
        picks, daily = m["picks"], m["daily_picks"]
        extra, bank = m.get("extra_picks", {}), m.get("bankers", {})
        roi = "   -   " if picks["roi"] is None else f"{100 * picks['roi']:+6.1f}%"
        lines.append(
            f"{m['title']:22s} {pct(m['base_rate'])} {m['brier']:.4f} {100 * skill:5.1f}% "
            f"{picks['n']:6d} {pct(picks['hit_rate'])} {pct(picks['avg_probability'])} {roi}"
            f"   {daily['n']:5d} {pct(daily['hit_rate']).strip()}"
            f" | {extra.get('n', 0):5d} {pct(extra.get('hit_rate')).strip()}"
            f" | {bank.get('n', 0):5d} {pct(bank.get('hit_rate')).strip()}"
        )
    lines.append("")
    lines.append("Calibration (predicted -> observed):")
    for market, m in result["markets"].items():
        cells = ", ".join(f"{c['predicted']:.2f}->{c['observed']:.2f} (n={c['n']})"
                          for c in m["calibration"] if c["n"] >= 30)
        lines.append(f"  {m['title']}: {cells}")
    lines.append("")
    lines.append("Threshold sweep (min probability: picks / hit rate / ROI):")
    for market, m in result["markets"].items():
        cells = []
        for s in m["threshold_sweep"]:
            roi = "" if s["roi"] is None else f" / {100 * s['roi']:+.1f}%"
            cells.append(f"{s['threshold']:.2f}: {s['n']} / {pct(s['hit_rate']).strip()}{roi}")
        lines.append(f"  {m['title']}: " + "; ".join(cells))
    vs = result.get("vs_market") or {}
    if vs:
        lines.append("")
        lines.append("Against the betting market (lower is better):")
        if "over25" in vs:
            v = vs["over25"]
            lines.append(f"  Over 2.5 Brier: ours {v['brier']:.4f} vs market {v['market_brier']:.4f}"
                         f" (n={v['n']})")
        if "1x2" in vs:
            v = vs["1x2"]
            lines.append(f"  1X2 RPS: ours {v['rps']:.4f} vs market {v['market_rps']:.4f}"
                         f" (n={v['n']})")
    if math.isfinite(result.get("market_weight", 0)):
        lines.append("")
        lines.append("hit% = share of picks that won, exp% = average predicted probability "
                     "(well calibrated when close). ROI uses average market odds, flat stakes.")
    return "\n".join(lines)


def per_league_summary(rows: list[BacktestRow], market_weight: float) -> dict[str, dict]:
    """Brier score per league and market - handy to spot leagues the model struggles with."""
    grouped: dict[str, list[BacktestRow]] = defaultdict(list)
    for row in rows:
        grouped[row.match.league].append(row)
    out = {}
    for league, league_rows in sorted(grouped.items()):
        probs = [r.probabilities(market_weight) for r in league_rows]
        hg = np.array([r.match.home_goals for r in league_rows])
        ag = np.array([r.match.away_goals for r in league_rows])
        out[league] = {
            "n": len(league_rows),
            "over25_brier": _brier(np.array([p.over25 for p in probs]), (hg + ag >= 3).astype(float)),
            "btts_brier": _brier(np.array([p.btts for p in probs]),
                                 ((hg > 0) & (ag > 0)).astype(float)),
        }
    return out

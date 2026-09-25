"""Turn predictions into the four daily pick lists."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from .engine import Prediction
from .markets import double_chance_odds, fair_odds

MARKETS = ("btts_over25", "over25", "btts", "double_chance")
MARKET_TITLES = {
    "btts_over25": "BTTS & Over 2.5",
    "over25": "Over 2.5 Goals",
    "btts": "Both Teams To Score",
    "double_chance": "Double Chance",
}
MARKET_ICONS = {"btts_over25": "🔥", "over25": "⚽", "btts": "🎯", "double_chance": "🛡️"}


TIERS = ("banker", "strong", "extra")


@dataclass
class MarketRule:
    enabled: bool = True
    # Picks at or above this probability are "strong" picks.
    min_probability: float = 0.6
    # Always try to publish at least this many picks: when fewer matches are
    # strong, the list is topped up with the next best ones ("extra" picks)...
    min_picks: int = 15
    # ...but never with a pick below this probability.
    floor: float = 0.5
    max_picks: int = 20
    # Picks at or above this probability are flagged as bankers (safest tips).
    # None = the market never produces bankers.
    banker_probability: float | None = None
    # Only applied where bookmaker odds exist (Over 2.5 and Double Chance):
    # require probability * odds - 1 >= min_edge.
    min_edge: float | None = None

    def validate(self, name: str) -> None:
        if not 0.0 < self.min_probability < 1.0:
            raise ValueError(f"selection.{name}.min_probability must be between 0 and 1")
        if not 0.0 < self.floor <= self.min_probability:
            raise ValueError(f"selection.{name}.floor must be above 0 and at most min_probability")
        if self.max_picks < 0 or self.min_picks < 0:
            raise ValueError(f"selection.{name}.min_picks and max_picks must be >= 0")
        if self.banker_probability is not None and not (
                self.min_probability <= self.banker_probability <= 1.0):
            raise ValueError(f"selection.{name}.banker_probability must be between "
                             "min_probability and 1")

    @property
    def target(self) -> int:
        """Picks to aim for each day (min_picks, never more than max_picks)."""
        return min(self.min_picks, self.max_picks)

    def tier(self, probability: float) -> str:
        if self.banker_probability is not None and probability >= self.banker_probability:
            return "banker"
        return "strong" if probability >= self.min_probability else "extra"


# Thresholds from walk-forward backtests (Aug 2024 - Jun 2026, 22 leagues):
# Double Chance picks at 88%+ won 94.5% of the time, Over 2.5 picks at 75%+
# won 87%. BTTS markets never reach that level of certainty, so no bankers.
@dataclass
class SelectionSettings:
    # Both teams need at least this many league matches in the training window.
    min_team_matches: int = 4
    btts_over25: MarketRule = field(
        default_factory=lambda: MarketRule(min_probability=0.50, floor=0.40))
    over25: MarketRule = field(
        default_factory=lambda: MarketRule(min_probability=0.62, floor=0.50,
                                           banker_probability=0.75))
    btts: MarketRule = field(default_factory=lambda: MarketRule(min_probability=0.60, floor=0.50))
    double_chance: MarketRule = field(
        default_factory=lambda: MarketRule(min_probability=0.80, floor=0.70,
                                           banker_probability=0.88))

    def rule(self, market: str) -> MarketRule:
        return getattr(self, market)

    def validate(self) -> None:
        if self.min_team_matches < 0:
            raise ValueError("selection.min_team_matches must be >= 0")
        for market in MARKETS:
            self.rule(market).validate(market)


@dataclass(frozen=True)
class Pick:
    market: str
    selection: str
    probability: float
    market_odds: float | None
    prediction: Prediction
    tier: str = "strong"  # "banker", "strong" or "extra" (top-up pick below the usual bar)

    @property
    def match_id(self) -> str:
        return self.prediction.match.id

    @property
    def fair_odds(self) -> float:
        return fair_odds(self.probability)

    @property
    def edge(self) -> float | None:
        if self.market_odds is None:
            return None
        return self.probability * self.market_odds - 1.0


def candidate(prediction: Prediction, market: str) -> tuple[str, float, float | None]:
    """(selection label, model probability, bookmaker odds if known) for a market."""
    probs, match = prediction.probs, prediction.match
    if market == "btts_over25":
        return "BTTS & Over 2.5", probs.btts_over25, None
    if market == "over25":
        return "Over 2.5", probs.over25, match.odds_ou25[0] if match.odds_ou25 else None
    if market == "btts":
        return "BTTS Yes", probs.btts, None
    if market == "double_chance":
        selection, probability = probs.best_double_chance()
        return selection, probability, double_chance_odds(match.odds_1x2, selection)
    raise KeyError(market)


def is_winner(market: str, selection: str, home_goals: int, away_goals: int) -> bool:
    if market == "btts_over25":
        return home_goals > 0 and away_goals > 0 and home_goals + away_goals >= 3
    if market == "over25":
        return home_goals + away_goals >= 3
    if market == "btts":
        return home_goals > 0 and away_goals > 0
    if market == "double_chance":
        return {"1X": home_goals >= away_goals, "X2": away_goals >= home_goals,
                "12": home_goals != away_goals}[selection]
    raise KeyError(market)


def select_picks(predictions: Iterable[Prediction],
                 settings: SelectionSettings) -> dict[str, list[Pick]]:
    """Best picks per market, most confident first.

    Every match at or above ``min_probability`` qualifies (up to ``max_picks``).
    If that gives fewer than ``min_picks``, the list is topped up with the next
    most likely matches down to ``floor``; those are marked as "extra" picks.
    """
    predictions = list(predictions)
    picks: dict[str, list[Pick]] = {}
    for market in MARKETS:
        rule = settings.rule(market)
        candidates: list[Pick] = []
        if rule.enabled:
            for prediction in predictions:
                if prediction.min_team_matches < settings.min_team_matches:
                    continue
                selection, probability, odds = candidate(prediction, market)
                if probability < rule.floor:
                    continue
                pick = Pick(market, selection, probability, odds, prediction,
                            rule.tier(probability))
                if rule.min_edge is not None and pick.edge is not None and pick.edge < rule.min_edge:
                    continue
                candidates.append(pick)
            candidates.sort(key=lambda p: -p.probability)
        strong = [p for p in candidates if p.tier != "extra"][:rule.max_picks]
        extra = [p for p in candidates if p.tier == "extra"][:max(0, rule.target - len(strong))]
        picks[market] = strong + extra
    return picks

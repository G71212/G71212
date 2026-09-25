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


@dataclass
class MarketRule:
    enabled: bool = True
    min_probability: float = 0.6
    max_picks: int = 10
    # Only applied where bookmaker odds exist (Over 2.5 and Double Chance):
    # require probability * odds - 1 >= min_edge.
    min_edge: float | None = None

    def validate(self, name: str) -> None:
        if not 0.0 < self.min_probability < 1.0:
            raise ValueError(f"selection.{name}.min_probability must be between 0 and 1")
        if self.max_picks < 0:
            raise ValueError(f"selection.{name}.max_picks must be >= 0")


@dataclass
class SelectionSettings:
    # Both teams need at least this many league matches in the training window.
    min_team_matches: int = 4
    btts_over25: MarketRule = field(default_factory=lambda: MarketRule(min_probability=0.50))
    over25: MarketRule = field(default_factory=lambda: MarketRule(min_probability=0.62))
    btts: MarketRule = field(default_factory=lambda: MarketRule(min_probability=0.60))
    double_chance: MarketRule = field(default_factory=lambda: MarketRule(min_probability=0.80))

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
    """Best picks per market: above the threshold, most confident first."""
    predictions = list(predictions)
    picks: dict[str, list[Pick]] = {}
    for market in MARKETS:
        rule = settings.rule(market)
        chosen: list[Pick] = []
        if rule.enabled:
            for prediction in predictions:
                if prediction.min_team_matches < settings.min_team_matches:
                    continue
                selection, probability, odds = candidate(prediction, market)
                if probability < rule.min_probability:
                    continue
                pick = Pick(market, selection, probability, odds, prediction)
                if rule.min_edge is not None and pick.edge is not None and pick.edge < rule.min_edge:
                    continue
                chosen.append(pick)
            chosen.sort(key=lambda p: -p.probability)
            chosen = chosen[:rule.max_picks]
        picks[market] = chosen
    return picks

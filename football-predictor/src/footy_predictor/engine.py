"""Turn fixtures into predictions: fit one model per league, blend with odds."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Iterable

from .data import DataError, DataSource, Match
from .leagues import LEAGUES, TIER_ABOVE
from .markets import (MarketProbabilities, MarketView, blend_rates, market_probabilities,
                      market_view, score_matrix)
from .model import DixonColesModel, InsufficientData, ModelSettings

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Prediction:
    match: Match
    probs: MarketProbabilities
    exp_home: float  # final expected goals (after blending with the market)
    exp_away: float
    model_exp_home: float  # pure model expected goals
    model_exp_away: float
    market: MarketView | None
    home_matches: int
    away_matches: int
    flags: tuple[str, ...] = ()
    rho: float = 0.0  # Dixon-Coles low-score correction of the league model

    @property
    def min_team_matches(self) -> int:
        return min(self.home_matches, self.away_matches)


def predict_with_model(model: DixonColesModel, fixture: Match,
                       settings: ModelSettings) -> Prediction:
    model_lam, model_mu = model.expected_goals(fixture.home, fixture.away)
    view = market_view(fixture.odds_1x2, fixture.odds_ou25, model_lam, model_mu, model.rho,
                       settings.max_goals)
    lam, mu = blend_rates((model_lam, model_mu), view, settings.market_weight)
    probs = market_probabilities(score_matrix(lam, mu, model.rho, settings.max_goals))
    home, away = model.rating(fixture.home), model.rating(fixture.away)
    flags = []
    for team, rating in ((fixture.home, home), (fixture.away, away)):
        if rating.matches == 0:
            flags.append(f"no data for {team}")
        elif rating.newcomer:
            status = "relegated" if team in model.from_above else "new to league"
            flags.append(f"{team} {status}")
    if view is None:
        flags.append("no odds")
    return Prediction(fixture, probs, lam, mu, model_lam, model_mu, view, home.matches,
                      away.matches, tuple(flags), model.rho)


class Predictor:
    """Fits (and caches) a model per league and predicts fixtures."""

    def __init__(self, source: DataSource, settings: ModelSettings):
        settings.validate()
        self.source = source
        self.settings = settings
        self._models: dict[tuple[str, date], DixonColesModel | None] = {}

    def training_window(self, as_of: date) -> tuple[date, date]:
        return as_of - timedelta(days=self.settings.history_days), as_of - timedelta(days=1)

    def model(self, league_code: str, as_of: date) -> DixonColesModel | None:
        key = (league_code, as_of)
        if key not in self._models:
            start, end = self.training_window(as_of)
            try:
                matches = self.source.results(LEAGUES[league_code], start, end)
                from_above = self._teams_above(league_code, start, end)
                self._models[key] = DixonColesModel(self.settings).fit(matches, as_of, from_above)
            except (InsufficientData, DataError) as exc:
                log.warning("Skipping %s: %s", league_code, exc)
                self._models[key] = None
        return self._models[key]

    def _teams_above(self, league_code: str, start: date, end: date) -> set[str]:
        above = TIER_ABOVE.get(league_code)
        if above is None:
            return set()
        try:
            matches = self.source.results(LEAGUES[above], start, end)
        except DataError as exc:
            log.warning("Could not load %s to spot relegated teams: %s", above, exc)
            return set()
        return {team for m in matches for team in (m.home, m.away)}

    def predict(self, fixtures: Iterable[Match], as_of: date) -> list[Prediction]:
        out = []
        for fixture in fixtures:
            model = self.model(fixture.league, as_of)
            if model is None:
                continue
            if fixture.home not in model.teams and fixture.away not in model.teams:
                # Neither team has played in this league recently: most likely a
                # different competition sharing the country code - skip it.
                log.info("Skipping %s: teams unknown to the %s model", fixture.id, fixture.league)
                continue
            out.append(predict_with_model(model, fixture, self.settings))
        out.sort(key=lambda p: (p.match.kickoff is None, p.match.kickoff or p.match.date,
                                p.match.league, p.match.home))
        return out

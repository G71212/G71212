"""Synthetic leagues with known team strengths, and an offline data source."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

import numpy as np

from footy_predictor.data import Match, season_code
from footy_predictor.markets import score_matrix


def round_robin(n: int) -> list[list[tuple[int, int]]]:
    """Double round robin (circle method): each pair meets once home, once away."""
    order = list(range(n))
    first = []
    for r in range(n - 1):
        pairs = [(order[i], order[n - 1 - i]) for i in range(n // 2)]
        if r % 2:
            pairs = [(a, h) for h, a in pairs]
        first.append(pairs)
        order = [order[0], order[-1]] + order[1:-1]
    return first + [[(a, h) for h, a in rnd] for rnd in first]


def synthetic_league(code: str = "E0", n_teams: int = 12, seasons=(2023, 2024, 2025),
                     seed: int = 7, base: float = 1.15, home_adv: float = 1.3,
                     rho: float = -0.1, spread: float = 0.3, teams: list[str] | None = None,
                     odds: bool = False) -> tuple[list[Match], dict]:
    rng = np.random.default_rng(seed)
    names = teams or [f"Team {i:02d}" for i in range(n_teams)]
    attack = np.exp(rng.normal(0, spread, len(names)))
    defence = np.exp(rng.normal(0, spread, len(names)))
    matches = []
    for year in seasons:
        start = date(year, 8, 9)
        for r, pairs in enumerate(round_robin(len(names))):
            day = start + timedelta(days=7 * r)
            for h, a in pairs:
                lam = base * home_adv * attack[h] * defence[a]
                mu = base * attack[a] * defence[h]
                matrix = score_matrix(lam, mu, rho, 10)
                k = rng.choice(matrix.size, p=matrix.ravel())
                hg, ag = divmod(int(k), 11)
                matches.append(Match(
                    league=code, season=season_code(year), date=day, home=names[h], away=names[a],
                    kickoff=datetime(day.year, day.month, day.day, 14, 0, tzinfo=timezone.utc),
                    home_goals=hg, away_goals=ag,
                    odds_1x2=(2.1, 3.4, 3.6) if odds else None,
                    odds_ou25=(1.9, 1.95) if odds else None,
                ))
    truth = {"teams": names, "attack": attack, "defence": defence, "base": base,
             "home_adv": home_adv, "rho": rho}
    return matches, truth


class FakeSource:
    """In-memory stand-in for FootballDataSource."""

    def __init__(self, results: dict[str, list[Match]], fixtures: list[Match] | None = None):
        self._results = results
        self._fixtures = fixtures or []
        self.calls: list[str] = []

    def results(self, league, start, end):
        self.calls.append(league.code)
        return [m for m in self._results.get(league.code, [])
                if m.played and start <= m.date <= end]

    def fixtures(self):
        return list(self._fixtures)


def fixture(league: str, day: date, home: str, away: str, hour: int = 15,
            odds_1x2=None, odds_ou25=None) -> Match:
    return Match(league=league, season=season_code(day.year if day.month >= 7 else day.year - 1),
                 date=day, home=home, away=away,
                 kickoff=datetime(day.year, day.month, day.day, hour, 0, tzinfo=timezone.utc),
                 odds_1x2=odds_1x2, odds_ou25=odds_ou25)

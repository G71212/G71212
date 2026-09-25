"""Catalogue of leagues supported by the football-data.co.uk data source."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class League:
    code: str
    country: str
    name: str
    # "main" leagues have one CSV per season (mmz4281/<season>/<code>.csv);
    # "extra" leagues have a single all-seasons CSV (new/<code>.csv).
    kind: str = "main"

    @property
    def label(self) -> str:
        return f"{self.country} · {self.name}"


MAIN_LEAGUES = (
    League("E0", "England", "Premier League"),
    League("E1", "England", "Championship"),
    League("E2", "England", "League One"),
    League("E3", "England", "League Two"),
    League("EC", "England", "National League"),
    League("SC0", "Scotland", "Premiership"),
    League("SC1", "Scotland", "Championship"),
    League("SC2", "Scotland", "League One"),
    League("SC3", "Scotland", "League Two"),
    League("D1", "Germany", "Bundesliga"),
    League("D2", "Germany", "2. Bundesliga"),
    League("I1", "Italy", "Serie A"),
    League("I2", "Italy", "Serie B"),
    League("SP1", "Spain", "La Liga"),
    League("SP2", "Spain", "Segunda División"),
    League("F1", "France", "Ligue 1"),
    League("F2", "France", "Ligue 2"),
    League("N1", "Netherlands", "Eredivisie"),
    League("B1", "Belgium", "Pro League"),
    League("P1", "Portugal", "Primeira Liga"),
    League("T1", "Turkey", "Süper Lig"),
    League("G1", "Greece", "Super League"),
)

# The country names must match the "Country" column of football-data.co.uk's
# extra-league files and new_league_fixtures.csv.
EXTRA_LEAGUES = (
    League("ARG", "Argentina", "Liga Profesional", "extra"),
    League("AUT", "Austria", "Bundesliga", "extra"),
    League("BRA", "Brazil", "Serie A", "extra"),
    League("CHN", "China", "Super League", "extra"),
    League("DNK", "Denmark", "Superliga", "extra"),
    League("FIN", "Finland", "Veikkausliiga", "extra"),
    League("IRL", "Ireland", "Premier Division", "extra"),
    League("JPN", "Japan", "J1 League", "extra"),
    League("MEX", "Mexico", "Liga MX", "extra"),
    League("NOR", "Norway", "Eliteserien", "extra"),
    League("POL", "Poland", "Ekstraklasa", "extra"),
    League("ROU", "Romania", "Superliga", "extra"),
    League("RUS", "Russia", "Premier League", "extra"),
    League("SWE", "Sweden", "Allsvenskan", "extra"),
    League("SWZ", "Switzerland", "Super League", "extra"),
    League("USA", "USA", "MLS", "extra"),
)

LEAGUES: dict[str, League] = {lg.code: lg for lg in MAIN_LEAGUES + EXTRA_LEAGUES}
EXTRA_BY_COUNTRY: dict[str, League] = {lg.country.lower(): lg for lg in EXTRA_LEAGUES}

# The division directly above, used to tell relegated newcomers (usually strong
# in the lower division) from promoted ones (usually weak in the higher one).
TIER_ABOVE: dict[str, str] = {
    "E1": "E0", "E2": "E1", "E3": "E2", "EC": "E3",
    "SC1": "SC0", "SC2": "SC1", "SC3": "SC2",
    "D2": "D1", "I2": "I1", "SP2": "SP1", "F2": "F1",
}

PRESETS: dict[str, tuple[str, ...]] = {
    "all": tuple(LEAGUES),
    "main": tuple(lg.code for lg in MAIN_LEAGUES),
    "extra": tuple(lg.code for lg in EXTRA_LEAGUES),
    "top5": ("E0", "SP1", "D1", "I1", "F1"),
    "europe-top": ("E0", "E1", "SP1", "D1", "I1", "F1", "N1", "P1", "B1", "T1", "SC0"),
}


def resolve_leagues(spec: str | list[str] | tuple[str, ...]) -> list[League]:
    """Turn a preset name, league code or comma separated list into leagues.

    >>> [lg.code for lg in resolve_leagues("top5")]
    ['E0', 'SP1', 'D1', 'I1', 'F1']
    """
    items = spec.split(",") if isinstance(spec, str) else list(spec)
    codes: list[str] = []
    for raw in items:
        token = raw.strip()
        if not token:
            continue
        if token.lower() in PRESETS:
            codes.extend(PRESETS[token.lower()])
        elif token.upper() in LEAGUES:
            codes.append(token.upper())
        else:
            known = ", ".join(sorted(PRESETS)) + ", " + ", ".join(LEAGUES)
            raise ValueError(f"Unknown league or preset {token!r}. Known: {known}")
    seen: dict[str, League] = {}
    for code in codes:
        seen.setdefault(code, LEAGUES[code])
    return list(seen.values())

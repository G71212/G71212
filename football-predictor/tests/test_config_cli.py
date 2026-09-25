import json
from datetime import date, datetime, timezone

import pytest

import footy_predictor.cli as cli
from footy_predictor.config import ConfigError, load_settings
from helpers import FakeSource, fixture, synthetic_league


def test_load_settings_from_toml(tmp_path):
    path = tmp_path / "config.toml"
    path.write_text(
        'timezone = "Africa/Nairobi"\nleagues = "top5"\ndays = 1\n'
        "[model]\nmarket_weight = 0.5\nhalf_life_days = 200\n"
        "[selection]\nmin_team_matches = 6\n"
        "[selection.over25]\nmin_probability = 0.7\nmax_picks = 5\nmin_edge = 0.02\n"
        "[telegram]\nenabled = false\n",
        encoding="utf-8",
    )
    settings = load_settings(path)
    assert settings.timezone == "Africa/Nairobi"
    assert [lg.code for lg in settings.league_list()] == ["E0", "SP1", "D1", "I1", "F1"]
    assert settings.model.market_weight == 0.5 and settings.model.half_life_days == 200.0
    assert settings.selection.min_team_matches == 6
    assert settings.selection.over25.min_probability == 0.7
    assert settings.selection.over25.min_edge == 0.02
    assert settings.selection.btts.min_probability == 0.60  # untouched default
    assert settings.telegram.enabled is False


@pytest.mark.parametrize("content,message", [
    ("colour = 'green'\n", "Unknown setting"),
    ("timezone = 'Mars/Olympus'\n", "Unknown timezone"),
    ("[model]\nmarket_weight = 2\n", "market_weight"),
    ("[selection.btts]\nmax_picks = 'lots'\n", "must be a number"),
    ("leagues = ['E0', 'ZZ1']\n", "Unknown league"),
    ("past_days = 9\n", "past_days"),
])
def test_invalid_settings_are_reported(tmp_path, content, message):
    path = tmp_path / "bad.toml"
    path.write_text(content, encoding="utf-8")
    with pytest.raises(ConfigError, match=message):
        load_settings(path)


def test_missing_config_file_is_an_error():
    with pytest.raises(ConfigError):
        load_settings("does-not-exist.toml")


def test_repository_config_is_valid():
    from pathlib import Path
    load_settings(Path(__file__).resolve().parents[1] / "config.toml")


def test_cli_predict_json(monkeypatch, capsys, tmp_path):
    results, truth = synthetic_league("E0", seasons=(2024, 2025))
    day = date(2026, 5, 30)
    teams = truth["teams"]
    source = FakeSource({"E0": results}, [fixture("E0", day, teams[0], teams[1])])
    monkeypatch.setattr(cli, "_source", lambda settings, args, today: source)
    monkeypatch.setattr(cli, "_now", lambda: datetime(2026, 5, 30, 5, 0, tzinfo=timezone.utc))
    monkeypatch.chdir(tmp_path)  # no config.toml here -> defaults
    code = cli.main(["predict", "--date", "2026-05-30", "--leagues", "E0", "--format", "json"])
    assert code == 0
    data = json.loads(capsys.readouterr().out)
    (fx,) = data["days"][0]["fixtures"]
    assert fx["home"] == teams[0]
    assert 0 < fx["probabilities"]["over25"] < 1


def test_cli_reports_bad_config(capsys, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert cli.main(["predict", "--timezone", "Nowhere/Land"]) == 1
    assert "Configuration error" in capsys.readouterr().err


def test_cli_leagues(capsys):
    assert cli.main(["leagues"]) == 0
    out = capsys.readouterr().out
    assert "E0" in out and "USA" in out

"""Settings: built-in defaults, overridden by a TOML file, overridden by the CLI."""

from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass, field, fields, is_dataclass
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .leagues import League, resolve_leagues
from .model import ModelSettings
from .selection import SelectionSettings


class ConfigError(ValueError):
    pass


@dataclass
class TelegramSettings:
    # Messages are only sent when TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are set.
    enabled: bool = True
    send_when_empty: bool = False


@dataclass
class SiteSettings:
    title: str = "Footy Predictor"
    url: str = ""  # public dashboard URL, linked from Telegram messages


@dataclass
class Settings:
    timezone: str = "UTC"
    leagues: list[str] = field(default_factory=lambda: ["all"])
    days: int = 2  # days covered by the daily report: today (+ tomorrow)
    cache_dir: str = ".cache"
    refresh_hours: float = 6.0
    model: ModelSettings = field(default_factory=ModelSettings)
    selection: SelectionSettings = field(default_factory=SelectionSettings)
    telegram: TelegramSettings = field(default_factory=TelegramSettings)
    site: SiteSettings = field(default_factory=SiteSettings)

    @property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)

    def league_list(self) -> list[League]:
        return resolve_leagues(self.leagues)

    def validate(self) -> None:
        try:
            ZoneInfo(self.timezone)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ConfigError(f"Unknown timezone {self.timezone!r} (use e.g. 'Africa/Nairobi')") from exc
        try:
            self.league_list()
        except ValueError as exc:
            raise ConfigError(str(exc)) from exc
        if not 1 <= self.days <= 7:
            raise ConfigError("days must be between 1 and 7")
        if self.refresh_hours <= 0:
            raise ConfigError("refresh_hours must be > 0")
        try:
            self.model.validate()
            self.selection.validate()
        except ValueError as exc:
            raise ConfigError(str(exc)) from exc


def _coerce(value: Any, current: Any, name: str) -> Any:
    if isinstance(current, bool):
        if not isinstance(value, bool):
            raise ConfigError(f"{name} must be true or false")
        return value
    if isinstance(current, (int, float)) and not isinstance(current, bool):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ConfigError(f"{name} must be a number")
        return float(value) if isinstance(current, float) else int(value)
    if isinstance(current, list):
        if isinstance(value, str):
            return [value]
        if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
            raise ConfigError(f"{name} must be a list of strings")
        return value
    if isinstance(current, str):
        if not isinstance(value, str):
            raise ConfigError(f"{name} must be a string")
        return value
    if current is None:  # optional numbers such as min_edge
        if value is not None and (isinstance(value, bool) or not isinstance(value, (int, float))):
            raise ConfigError(f"{name} must be a number")
        return None if value is None else float(value)
    return value


def _apply(target: Any, data: dict[str, Any], prefix: str = "") -> None:
    names = {f.name for f in fields(target)}
    for key, value in data.items():
        name = f"{prefix}{key}"
        if key not in names:
            raise ConfigError(f"Unknown setting '{name}'")
        current = getattr(target, key)
        if is_dataclass(current):
            if not isinstance(value, dict):
                raise ConfigError(f"'{name}' must be a table")
            _apply(current, value, f"{name}.")
        else:
            setattr(target, key, _coerce(value, current, name))


def find_config(explicit: str | None = None) -> Path | None:
    if explicit:
        path = Path(explicit)
        if not path.is_file():
            raise ConfigError(f"Config file not found: {path}")
        return path
    env = os.environ.get("FOOTY_CONFIG")
    if env:
        return find_config(env)
    default = Path("config.toml")
    return default if default.is_file() else None


def load_settings(path: str | Path | None = None, overrides: dict[str, Any] | None = None) -> Settings:
    settings = Settings()
    config_path = find_config(str(path) if path else None)
    if config_path is not None:
        try:
            data = tomllib.loads(config_path.read_text(encoding="utf-8"))
        except tomllib.TOMLDecodeError as exc:
            raise ConfigError(f"{config_path}: {exc}") from exc
        _apply(settings, data)
    if overrides:
        _apply(settings, overrides)
    settings.validate()
    return settings

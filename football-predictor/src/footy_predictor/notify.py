"""Telegram delivery (Bot API sendMessage, HTML parse mode)."""

from __future__ import annotations

import json
import logging
import os
import time
import urllib.error
import urllib.request

log = logging.getLogger(__name__)

API = "https://api.telegram.org"


class NotifyError(RuntimeError):
    pass


def telegram_credentials() -> tuple[str, str] | None:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
    return (token, chat_id) if token and chat_id else None


def send_telegram(token: str, chat_id: str, messages: list[str], timeout: float = 20.0) -> None:
    """Send messages in order. Errors never include the bot token."""
    for index, text in enumerate(messages):
        payload = json.dumps({
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        }).encode("utf-8")
        request = urllib.request.Request(
            f"{API}/bot{token}/sendMessage", data=payload,
            headers={"Content-Type": "application/json"}, method="POST",
        )
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=timeout) as response:
                    body = json.loads(response.read().decode("utf-8"))
                if not body.get("ok"):
                    raise NotifyError(f"Telegram rejected message {index + 1}: {body.get('description')}")
                break
            except urllib.error.HTTPError as exc:
                info = _error_json(exc)
                if exc.code == 429 and attempt < 2:
                    retry_after = int((info.get("parameters") or {}).get("retry_after", 5))
                    log.info("Telegram rate limit, waiting %ss", retry_after)
                    time.sleep(min(retry_after, 60))
                    continue
                raise NotifyError(f"Telegram error {exc.code}: {info.get('description', '')}") from None
            except (urllib.error.URLError, TimeoutError) as exc:
                if attempt < 2:
                    time.sleep(2 * (attempt + 1))
                    continue
                raise NotifyError(f"Could not reach Telegram: {getattr(exc, 'reason', exc)}") from None
        if index + 1 < len(messages):
            time.sleep(1.1)  # stay well under Telegram's per-chat rate limit


def _error_json(exc: urllib.error.HTTPError) -> dict:
    try:
        data = json.loads(exc.read().decode("utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:  # noqa: BLE001 - best effort only
        return {}

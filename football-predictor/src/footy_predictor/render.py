"""Render a report (see :func:`build_report`) as Markdown, Telegram, CSV, text or HTML."""

from __future__ import annotations

import csv
import html
import io
import json
from datetime import date, datetime, timezone
from importlib import resources
from zoneinfo import ZoneInfo

from . import APP_NAME, __version__
from .selection import MARKET_ICONS, MARKET_TITLES, MARKETS, TIERS

DISCLAIMER = ("Predictions are model probabilities, not certainties. "
              "Bet only what you can afford to lose. 18+ | Gamble responsibly.")
TELEGRAM_LIMIT = 4096


def build_report(days: list[dict], track: dict, settings, generated_at: datetime) -> dict:
    """The single document every renderer (and the dashboard) works from."""
    return {
        "app": APP_NAME,
        "version": __version__,
        "title": settings.site.title,
        "url": settings.site.url,
        "generated_at": generated_at.astimezone(timezone.utc).replace(microsecond=0).isoformat(),
        "timezone": settings.timezone,
        "markets": [
            {"key": m, "title": MARKET_TITLES[m], "icon": MARKET_ICONS[m],
             "min_probability": settings.selection.rule(m).min_probability,
             "floor": settings.selection.rule(m).floor,
             "min_picks": settings.selection.rule(m).min_picks,
             "max_picks": settings.selection.rule(m).max_picks,
             "banker_probability": settings.selection.rule(m).banker_probability}
            for m in MARKETS
        ],
        "days": days,
        "track_record": track,
        "model": {"half_life_days": settings.model.half_life_days,
                  "market_weight": settings.model.market_weight,
                  "xg_weight": settings.model.xg_weight},
        "disclaimer": DISCLAIMER,
    }


# --------------------------------------------------------------------------- helpers


def _tz(report: dict) -> ZoneInfo:
    return ZoneInfo(report.get("timezone") or "UTC")


def kickoff_local(iso: str | None, tz: ZoneInfo) -> str:
    if not iso:
        return "--:--"
    return datetime.fromisoformat(iso).astimezone(tz).strftime("%H:%M")


def pct(value: float | None) -> str:
    return "-" if value is None else f"{100 * value:.0f}%"


def odds(value: float | None) -> str:
    return "-" if value is None else f"{value:.2f}"


def stars(probability: float, threshold: float) -> str:
    margin = probability - threshold
    return "★★★" if margin >= 0.10 else "★★" if margin >= 0.05 else "★"


LEGEND = "🔒 banker (safest tip) · ★ to ★★★ confidence · ☆ extra pick below the usual confidence bar"


def pick_tier(pick: dict, market: dict) -> str:
    """Tier stored with the pick; older records without one are derived from the threshold."""
    if pick.get("tier") in TIERS:
        return pick["tier"]
    return "strong" if pick["probability"] >= market["min_probability"] else "extra"


def badge(pick: dict, market: dict) -> str:
    tier = pick_tier(pick, market)
    if tier == "banker":
        return "🔒"
    if tier == "extra":
        return "☆"
    return stars(pick["probability"], market["min_probability"])


def bankers(report: dict, day: dict, only: set[str] | None = None) -> list[tuple[dict, dict]]:
    """(market, pick) pairs flagged as bankers, most likely first."""
    found = [(market, p) for market in report["markets"]
             for p in day["picks"].get(market["key"], [])
             if pick_tier(p, market) == "banker"
             and (only is None or f"{market['key']}|{p['match_id']}" in only)]
    return sorted(found, key=lambda item: -item[1]["probability"])


def long_date(day: str) -> str:
    return date.fromisoformat(day).strftime("%A %d %B %Y")


def _status_text(pick: dict) -> str:
    status = pick.get("status", "pending")
    if status in ("won", "lost") and pick.get("result"):
        home, away = pick["result"]
        return f"{'✅' if status == 'won' else '❌'} {home}-{away}"
    return {"void": "void", "pending": ""}.get(status, status)


def _league_names(day: dict) -> dict[str, str]:
    return {f["id"]: f["league_name"] for f in day["fixtures"]}


def _record_line(summary: dict) -> str:
    if not summary["settled"]:
        return "-"
    text = f"{summary['won']}/{summary['settled']} ({pct(summary['hit_rate'])})"
    if summary.get("roi") is not None:
        text += f", ROI {100 * summary['roi']:+.0f}%"
    return text


# --------------------------------------------------------------------------- markdown / text


def render_markdown(report: dict) -> str:
    tz = _tz(report)
    lines = [f"# ⚽ {report['title']}", ""]
    lines.append(f"_Generated {report['generated_at'].replace('T', ' ')[:16]} UTC · "
                 f"kick-off times in {report['timezone']}_")
    if report.get("url"):
        lines += ["", f"**[Open the live dashboard]({report['url']})**"]
    lines += ["", f"_{LEGEND}_"]
    for day in report["days"]:
        leagues = {f["league"] for f in day["fixtures"]}
        names = _league_names(day)
        lines += ["", f"## {long_date(day['date'])}", ""]
        if not day["fixtures"]:
            lines += ["_No upcoming matches in the published fixtures for this day._", ""]
            continue
        lines += [f"{len(day['fixtures'])} matches analysed across {len(leagues)} leagues.", ""]
        safest = bankers(report, day)
        if safest:
            lines += ["### 🔒 Bankers: the day's safest tips", "",
                      "| Kick-off | Match | Market | Tip | Probability | Fair odds | Result |",
                      "|---|---|---|---|---|---|---|"]
            for market, p in safest:
                lines.append(f"| {kickoff_local(p['kickoff'], tz)} | {p['home']} vs {p['away']} "
                             f"| {market['title']} | {p['selection']} | {pct(p['probability'])} "
                             f"| {odds(p['fair_odds'])} | {_status_text(p)} |")
            lines.append("")
        for market in report["markets"]:
            picks = day["picks"].get(market["key"], [])
            lines.append(f"### {market['icon']} {market['title']}")
            lines.append("")
            if not picks:
                lines += ["_No match was likely enough to pick._", ""]
                continue
            lines.append("| Kick-off | League | Match | Tip | Probability | Fair odds | Market odds | Result |")
            lines.append("|---|---|---|---|---|---|---|---|")
            for p in picks:
                lines.append(
                    f"| {kickoff_local(p['kickoff'], tz)} | {names.get(p['match_id'], p['league'])} "
                    f"| {p['home']} vs {p['away']} | {p['selection']} "
                    f"| {pct(p['probability'])} {badge(p, market)} "
                    f"| {odds(p['fair_odds'])} | {odds(p['market_odds'])} | {_status_text(p)} |"
                )
            lines.append("")
    lines += ["## 📊 Track record", "",
              "| Market | Last 7 days | Last 30 days | All time |", "|---|---|---|---|"]
    groups = [("🔒 Bankers", "bankers")] + [(m["title"], m["key"]) for m in report["markets"]]
    for title, key in groups:
        record = report["track_record"].get(key, {})
        if record:
            lines.append(f"| {title} | {_record_line(record['7d'])} | "
                         f"{_record_line(record['30d'])} | {_record_line(record['all'])} |")
    lines += ["", f"> {report['disclaimer']}", ""]
    return "\n".join(lines)


def render_text(report: dict) -> str:
    """Plain-text version for the terminal."""
    tz = _tz(report)
    out = []
    for day in report["days"]:
        names = _league_names(day)
        out.append(f"\n{long_date(day['date'])}  ({len(day['fixtures'])} matches analysed, "
                   f"times in {report['timezone']})")
        out.append("=" * 78)
        if not day["fixtures"]:
            out.append("   no upcoming matches in the published fixtures")
            continue
        safest = bankers(report, day)
        if safest:
            out.append("\n🔒  BANKERS (the day's safest tips)")
            for market, p in safest:
                match = f"{p['home']} v {p['away']}"
                out.append(f"   {kickoff_local(p['kickoff'], tz)}  {match[:38]:38s} "
                           f"{p['selection']:>15s} {pct(p['probability']):>4s}  {_status_text(p)}".rstrip())
        for market in report["markets"]:
            picks = day["picks"].get(market["key"], [])
            out.append(f"\n{market['icon']}  {market['title'].upper()}  "
                       f"(min {pct(market['min_probability'])})")
            if not picks:
                out.append("   no selections today")
                continue
            for p in picks:
                match = f"{p['home']} v {p['away']}"
                tip = "" if market["key"] != "double_chance" else f"{p['selection']:>3s} "
                extra = f"  mkt {odds(p['market_odds'])}" if p["market_odds"] else ""
                status = _status_text(p)
                out.append(f"   {kickoff_local(p['kickoff'], tz)}  {match[:38]:38s} {tip}"
                           f"{pct(p['probability']):>4s} {badge(p, market):3s} fair {odds(p['fair_odds'])}{extra}"
                           f"  {status}".rstrip())
                out.append(f"          {names.get(p['match_id'], p['league'])}")
    return ("\n".join(out).lstrip("\n") + "\n\n" + LEGEND + "\n" + report["disclaimer"] + "\n")


# --------------------------------------------------------------------------- telegram


def _chunks(blocks: list[str], limit: int = TELEGRAM_LIMIT) -> list[str]:
    messages, current = [], ""
    for block in blocks:
        block = block if len(block) <= limit else block[: limit - 1] + "…"
        candidate = f"{current}\n\n{block}" if current else block
        if len(candidate) > limit:
            messages.append(current)
            current = block
        else:
            current = candidate
    if current:
        messages.append(current)
    return messages


def render_telegram(report: dict, day_index: int = 0, only: set[str] | None = None,
                    update: bool = False) -> list[str]:
    """HTML-formatted Telegram messages. ``only`` limits output to these pick keys."""
    tz = _tz(report)
    day = report["days"][day_index]
    names = _league_names(day)
    esc = html.escape
    title = "Update" if update else "Daily tips"
    header = (f"<b>⚽ {esc(report['title'])} · {title}</b>\n"
              f"{date.fromisoformat(day['date']).strftime('%a %d %b %Y')} · "
              f"times in {esc(report['timezone'])}")
    blocks = [header]
    safest = bankers(report, day, only)
    if safest:
        lines = ["<b>🔒 Bankers: the day's safest tips</b>"]
        for market, p in safest:
            lines.append(f"{kickoff_local(p['kickoff'], tz)} {esc(p['home'])} v {esc(p['away'])}\n"
                         f"   <b>{esc(p['selection'])}</b> <b>{pct(p['probability'])}</b>"
                         f" · fair {odds(p['fair_odds'])} · <i>{esc(market['title'])}</i>")
        blocks.append("\n".join(lines))
    for market in report["markets"]:
        key = market["key"]
        picks = [p for p in day["picks"].get(key, [])
                 if only is None or f"{key}|{p['match_id']}" in only]
        if not picks:
            continue
        lines = [f"<b>{market['icon']} {esc(market['title'])}</b> ({len(picks)})"]
        for p in picks:
            tip = f"<b>{esc(p['selection'])}</b> " if key == "double_chance" else ""
            price = f" · odds {odds(p['market_odds'])}" if p["market_odds"] else ""
            lines.append(
                f"{kickoff_local(p['kickoff'], tz)} {esc(p['home'])} v {esc(p['away'])}\n"
                f"   {tip}<b>{pct(p['probability'])}</b> {badge(p, market)}"
                f" · fair {odds(p['fair_odds'])}{price} · <i>{esc(names.get(p['match_id'], p['league']))}</i>"
            )
        blocks.append("\n".join(lines))
    if len(blocks) == 1:
        blocks.append("No selections met the confidence thresholds today.")
    record = report.get("track_record") or {}
    titles = {"bankers": "🔒 Bankers", **MARKET_TITLES}
    summary = [f"{titles[m]}: {_record_line(record[m]['30d'])}"
               for m in ("bankers",) + MARKETS if m in record and record[m]["30d"]["settled"]]
    if summary:
        blocks.append("<b>📊 Last 30 days</b>\n" + "\n".join(summary))
    footer = f"<i>{esc(LEGEND)}\n{esc(report['disclaimer'])}</i>"
    if report.get("url"):
        footer = f'<a href="{esc(report["url"], quote=True)}">Full predictions</a>\n' + footer
    blocks.append(footer)
    return _chunks(blocks)


# --------------------------------------------------------------------------- csv


CSV_COLUMNS = [
    "date", "kickoff", "league", "league_name", "home", "away", "exp_home_goals",
    "exp_away_goals", "p_home", "p_draw", "p_away", "p_over25", "p_btts", "p_btts_over25",
    "p_1x", "p_x2", "p_12", "market_home", "market_draw", "market_away", "market_over25",
    "odds_home", "odds_draw", "odds_away", "odds_over25", "odds_under25", "picks", "flags",
    "result",
]


def render_csv(report: dict) -> str:
    tz = _tz(report)
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(CSV_COLUMNS)
    for day in report["days"]:
        tips: dict[str, list[str]] = {}
        for market, picks in day["picks"].items():
            for p in picks:
                tier = p.get("tier", "strong")
                label = p["selection"] if tier == "strong" else f"{p['selection']} ({tier})"
                tips.setdefault(p["match_id"], []).append(label)
        for f in day["fixtures"]:
            prob, market, price = f["probabilities"], f["market"] or {}, f["odds"] or {}
            kickoff = (datetime.fromisoformat(f["kickoff"]).astimezone(tz).strftime("%Y-%m-%d %H:%M")
                       if f["kickoff"] else "")
            writer.writerow([
                day["date"], kickoff, f["league"], f["league_name"], f["home"], f["away"],
                *f["expected_goals"], prob["home"], prob["draw"], prob["away"], prob["over25"],
                prob["btts"], prob["btts_over25"], prob["dc_1x"], prob["dc_x2"], prob["dc_12"],
                market.get("home"), market.get("draw"), market.get("away"), market.get("over25"),
                price.get("home"), price.get("draw"), price.get("away"), price.get("over25"),
                price.get("under25"), "; ".join(tips.get(f["id"], [])), "; ".join(f["flags"]),
                "-".join(map(str, f["result"])) if f.get("result") else "",
            ])
    return buffer.getvalue()


# --------------------------------------------------------------------------- html


def render_json(report: dict) -> str:
    return json.dumps(report, indent=1, ensure_ascii=False) + "\n"


def render_html(report: dict, standalone: bool = True) -> str:
    """Self-contained dashboard page with the report embedded as JSON.

    ``standalone=False`` returns just the head/body content, for hosts that
    supply their own document skeleton.
    """
    template = resources.files("footy_predictor").joinpath("templates/dashboard.html").read_text(
        encoding="utf-8")
    # Escaping "<" keeps "</script>" or "<!--" inside team names from ending the block.
    payload = json.dumps(report, ensure_ascii=False).replace("<", "\\u003c")
    page = (template.replace("__TITLE__", html.escape(report["title"]))
            .replace("__REPORT_JSON__", payload))
    head, _, body = page.partition("<!--BODY-->")
    if not standalone:
        return head + body
    return (
        '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
        '<meta name="color-scheme" content="light dark">\n'
        f"{head}</head>\n<body>\n{body}</body>\n</html>\n"
    )

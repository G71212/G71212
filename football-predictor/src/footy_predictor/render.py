"""Render a report (see :func:`build_report`) as Markdown, Telegram, CSV, text or HTML."""

from __future__ import annotations

import csv
import html
import io
import json
from datetime import date, datetime, timedelta, timezone
from importlib import resources
from zoneinfo import ZoneInfo

from . import APP_NAME, __version__
from .selection import MARKET_ICONS, MARKET_TITLES, MARKETS, TIERS

DISCLAIMER = ("Predictions are model probabilities, not certainties. "
              "Bet only what you can afford to lose. 18+ | Gamble responsibly.")
TELEGRAM_LIMIT = 4096


def build_report(days: list[dict], track: dict, settings, generated_at: datetime,
                 today: date | None = None) -> dict:
    """The single document every renderer (and the dashboard) works from.

    ``today`` is the first upcoming day; days before it are kept for their results.
    """
    return {
        "app": APP_NAME,
        "version": __version__,
        "title": settings.site.title,
        "url": settings.site.url,
        "generated_at": generated_at.astimezone(timezone.utc).replace(microsecond=0).isoformat(),
        "timezone": settings.timezone,
        "today": today.isoformat() if today else (days[0]["date"] if days else None),
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


def today_index(report: dict) -> int:
    """Position of the first upcoming day in ``report["days"]`` (earlier days are results)."""
    dates = [day["date"] for day in report["days"]]
    return dates.index(report["today"]) if report.get("today") in dates else 0


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


def result_counts(picks: list[dict]) -> dict[str, int]:
    counts = {"won": 0, "lost": 0, "pending": 0, "void": 0}
    for pick in picks:
        status = pick.get("status", "pending")
        counts[status] = counts.get(status, 0) + 1
    return counts


def _day_picks(day: dict) -> list[dict]:
    return [p for picks in day["picks"].values() for p in picks]


def _results_line(picks: list[dict]) -> str:
    counts = result_counts(picks)
    parts = [f"✅ {counts['won']} won", f"❌ {counts['lost']} lost"]
    if counts["pending"]:
        parts.append(f"{counts['pending']} pending")
    if counts["void"]:
        parts.append(f"{counts['void']} void")
    return " · ".join(parts)


def _has_results(picks: list[dict]) -> bool:
    return any(p.get("status") in ("won", "lost") for p in picks)


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
        if _has_results(_day_picks(day)):
            lines += [f"**Results:** {_results_line(_day_picks(day))}", ""]
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

    def esc(text: str) -> str:
        return html.escape(text, quote=False)

    title = "Update" if update else "Daily tips"
    header = (f"<b>⚽ {esc(report['title'])} · {title}</b>\n"
              f"{date.fromisoformat(day['date']).strftime('%a %d %b %Y')} · "
              f"times in {esc(report['timezone'])}")
    blocks = [header]
    if not update and day_index > 0:
        recap = _recap(report, report["days"][day_index - 1], day)
        if recap:
            blocks.append(recap)
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
    if not any(day["picks"].get(m["key"]) for m in report["markets"]):
        blocks.append("No selections met the confidence thresholds today.")
    record = report.get("track_record") or {}
    titles = {"bankers": "🔒 Bankers", **MARKET_TITLES}
    summary = [f"{titles[m]}: {_record_line(record[m]['30d'])}"
               for m in ("bankers",) + MARKETS if m in record and record[m]["30d"]["settled"]]
    if summary:
        blocks.append("<b>📊 Last 30 days</b>\n" + "\n".join(summary))
    footer = f"<i>{esc(LEGEND)}\n{esc(report['disclaimer'])}</i>"
    if report.get("url"):
        footer = f'<a href="{html.escape(report["url"], quote=True)}">Full predictions</a>\n' + footer
    blocks.append(footer)
    return _chunks(blocks)


def _recap(report: dict, previous: dict, day: dict) -> str | None:
    """The previous day's results by market, once some of its picks are settled."""
    if date.fromisoformat(day["date"]) - date.fromisoformat(previous["date"]) != timedelta(days=1):
        return None
    if not _has_results(_day_picks(previous)):
        return None
    lines = [f"<b>📋 Yesterday's results</b> · "
             f"{date.fromisoformat(previous['date']).strftime('%a %d %b')}"]
    safest = [p for _, p in bankers(report, previous)]
    if safest:
        lines.append(f"🔒 Bankers: {_results_line(safest)}")
    for market in report["markets"]:
        picks = previous["picks"].get(market["key"], [])
        if picks:
            lines.append(f"{market['icon']} {html.escape(market['title'], quote=False)}: "
                         f"{_results_line(picks)}")
    return "\n".join(lines)


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


APP_FILES = ("icon-192.png", "icon-512.png", "icon-maskable-512.png", "apple-touch-icon.png",
             "favicon-32.png", "sw.js")
THEME_COLOR = "#05050b"
# Bump when the icon artwork changes: the new URLs make browsers and installed apps
# fetch the new pictures instead of reusing cached ones.
ICON_VERSION = "2"


def short_app_name(title: str) -> str:
    """Home-screen label: Android launchers cut labels longer than about 12 characters."""
    if len(title) <= 12:
        return title
    return title.split()[0][:12]


def render_manifest(report: dict) -> str:
    """Web app manifest: lets Chrome, Edge and phones install the dashboard as an app."""
    manifest = {
        "id": "./",
        "name": report["title"],
        "short_name": short_app_name(report["title"]),
        "description": "Daily football predictions: BTTS & Over 2.5, Over 2.5, BTTS and Double Chance",
        "start_url": "./",
        "scope": "./",
        "display": "standalone",
        "background_color": THEME_COLOR,
        "theme_color": THEME_COLOR,
        "icons": [
            {"src": f"icon-192.png?v={ICON_VERSION}", "sizes": "192x192", "type": "image/png", "purpose": "any"},
            {"src": f"icon-512.png?v={ICON_VERSION}", "sizes": "512x512", "type": "image/png", "purpose": "any"},
            {"src": f"icon-maskable-512.png?v={ICON_VERSION}", "sizes": "512x512", "type": "image/png",
             "purpose": "maskable"},
        ],
    }
    return json.dumps(manifest, indent=1, ensure_ascii=False) + "\n"


def app_file(name: str) -> bytes:
    return resources.files("footy_predictor").joinpath(f"templates/static/{name}").read_bytes()


_APP_HEAD = (
    '<link rel="manifest" href="manifest.webmanifest">\n'
    f'<meta name="theme-color" content="{THEME_COLOR}">\n'
    f'<link rel="icon" type="image/png" sizes="32x32" href="favicon-32.png?v={ICON_VERSION}">\n'
    f'<link rel="apple-touch-icon" href="apple-touch-icon.png?v={ICON_VERSION}">\n'
    '<meta name="mobile-web-app-capable" content="yes">\n'
)
# Keeps an installed app current. The page is always fetched fresh when the app opens, but
# phones keep installed apps open for days: so whenever the app comes back into view (or
# back online, or a new version of the app takes over) it checks data/latest.json and
# reloads if a newer edition of the predictions has been published since it was loaded.
_APP_SCRIPT = """<script>
(function () {
  "use strict";
  if (!("serviceWorker" in navigator) || location.protocol === "file:") return;
  var registration = null, reloading = false, lastCheck = Date.now();
  var shown = document.documentElement.getAttribute("data-generated") || "";
  navigator.serviceWorker.register("sw.js").then(function (reg) { registration = reg; }).catch(function () {});
  function check() {
    if (!shown || reloading) return;
    lastCheck = Date.now();
    if (registration) registration.update().catch(function () {});
    fetch("data/latest.json", { cache: "no-store" })
      .then(function (response) { return response.ok ? response.json() : null; })
      .then(function (latest) {
        if (latest && latest.generated_at > shown && !reloading) { reloading = true; location.reload(); }
      })
      .catch(function () {});
  }
  navigator.serviceWorker.addEventListener("controllerchange", check);
  window.addEventListener("online", check);
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "visible" && Date.now() - lastCheck > 60000) check();
  });
  setInterval(function () { if (document.visibilityState === "visible") check(); }, 15 * 60 * 1000);
})();
</script>
"""


def render_html(report: dict, standalone: bool = True, app: bool = False) -> str:
    """Self-contained dashboard page with the report embedded as JSON.

    ``standalone=False`` returns just the head/body content, for hosts that
    supply their own document skeleton. ``app=True`` links the manifest,
    icons and service worker written next to it by :func:`write_outputs`,
    which makes the page installable as a desktop or phone app.
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
        f"{_APP_HEAD if app else ''}{head}</head>\n<body>\n{body}{_APP_SCRIPT if app else ''}"
        "</body>\n</html>\n"
    )

import csv
import io
import json
import re
from datetime import date, datetime, timezone

from footy_predictor.config import Settings
from footy_predictor.engine import Prediction
from footy_predictor.history import merge_day, track_record
from footy_predictor.markets import market_probabilities, score_matrix
from footy_predictor.render import (TELEGRAM_LIMIT, build_report, render_csv, render_html,
                                    render_markdown, render_telegram, render_text)
from footy_predictor.selection import select_picks
from helpers import fixture

DAY = date(2026, 9, 26)
NOW = datetime(2026, 9, 26, 6, 0, tzinfo=timezone.utc)


def report(n=3, home_name="Home"):
    preds = []
    for i in range(n):
        match = fixture("E0", DAY, f"{home_name} {i}", f"Away {i}", odds_1x2=(1.4, 4.8, 8.0),
                        odds_ou25=(1.55, 2.5))
        probs = market_probabilities(score_matrix(2.9, 1.8, -0.08))
        preds.append(Prediction(match, probs, 2.9, 1.8, 2.7, 1.7, None, 25, 25))
    settings = Settings()
    record = merge_day(None, DAY, preds, select_picks(preds, settings.selection), NOW)
    return build_report([record], track_record([record], DAY), settings, NOW)


def test_markdown_and_text_list_every_market():
    rep = report()
    md = render_markdown(rep)
    for title in ("BTTS & Over 2.5", "Over 2.5 Goals", "Both Teams To Score", "Double Chance"):
        assert title in md
    assert "Home 0 vs Away 0" in md
    assert "Gamble responsibly" in md
    text = render_text(rep)
    assert "OVER 2.5 GOALS" in text and "Home 0 v Away 0" in text
    assert "live dashboard" not in md
    rep["url"] = "https://example.github.io/footy/"
    assert "[Open the live dashboard](https://example.github.io/footy/)" in render_markdown(rep)


def test_day_without_upcoming_matches():
    rep = report()
    rep["days"].insert(0, {"date": "2026-09-25", "fixtures": [],
                           "picks": {m["key"]: [] for m in rep["markets"]}, "notified": []})
    md = render_markdown(rep)
    friday = md.split("## Friday 25 September 2026")[1].split("## Saturday")[0]
    assert "No upcoming matches" in friday
    assert "confidence threshold" not in friday
    assert "no upcoming matches" in render_text(rep)


def test_telegram_escapes_html_and_respects_length_limit():
    rep = report(n=60, home_name="Brighton & <Hove>")
    messages = render_telegram(rep)
    assert len(messages) > 1
    assert all(len(m) <= TELEGRAM_LIMIT for m in messages)
    joined = "\n".join(messages)
    assert "Brighton &amp; &lt;Hove&gt;" in joined
    assert "<Hove>" not in joined


def test_telegram_update_only_includes_requested_picks():
    rep = report(n=2)
    pick = rep["days"][0]["picks"]["over25"][0]
    messages = render_telegram(rep, only={f"over25|{pick['match_id']}"}, update=True)
    text = "\n".join(messages)
    assert "Update" in text
    assert text.count(" v Away ") == 1


def test_csv_has_one_row_per_fixture():
    rows = list(csv.DictReader(io.StringIO(render_csv(report(n=4)))))
    assert len(rows) == 4
    assert float(rows[0]["p_over25"]) > 0.5
    assert "Over 2.5" in rows[0]["picks"]


def test_html_embeds_report_safely():
    rep = report(n=2, home_name="</script><script>alert(1)</script>")
    page = render_html(rep)
    assert page.startswith("<!doctype html>")
    assert page.count("</script>") == 2  # only the page's own two script blocks
    payload = re.search(r'<script id="report-data" type="application/json">(.*?)</script>', page, re.S)
    data = json.loads(payload.group(1))
    assert data["days"][0]["fixtures"][0]["home"].startswith("</script>")
    fragment = render_html(rep, standalone=False)
    assert not fragment.lstrip().startswith("<!doctype") and fragment.startswith("<title>")
    assert "<!--BODY-->" not in page and "<!--BODY-->" not in fragment

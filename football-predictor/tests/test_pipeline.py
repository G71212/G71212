"""End-to-end runs of the daily job against an offline synthetic league."""

import json
from datetime import date, datetime, timedelta, timezone

import pytest

import footy_predictor.pipeline as pipeline
from footy_predictor.config import Settings
from footy_predictor.data import Match
from footy_predictor.history import HistoryStore
from footy_predictor.livescores import LiveScoreError, Score
from helpers import FakeSource, fixture, synthetic_league

DAY = date(2026, 5, 30)  # the synthetic 2025/26 season ends before this
MORNING = datetime(2026, 5, 30, 5, 0, tzinfo=timezone.utc)


@pytest.fixture
def world():
    results, truth = synthetic_league("E0", n_teams=12, seasons=(2023, 2024, 2025), seed=9)
    teams = truth["teams"]
    fixtures = [fixture("E0", DAY, teams[i], teams[i + 6], hour=14 + i % 3,
                        odds_1x2=(2.2, 3.4, 3.3), odds_ou25=(1.85, 2.0)) for i in range(6)]
    fixtures += [fixture("E0", DAY + timedelta(days=1), teams[6], teams[0])]
    settings = Settings(leagues=["E0"], days=2)
    settings.selection.min_team_matches = 1
    for market in ("btts_over25", "over25", "btts", "double_chance"):
        settings.selection.rule(market).min_probability = 0.3  # make sure picks appear
    return settings, FakeSource({"E0": results}, fixtures), results


def test_predict_days_for_a_past_date_grades_picks(world):
    settings, source, results = world
    past_day = results[-1].date
    records = pipeline.predict_days(settings, source, [past_day], MORNING)
    (record,) = records
    assert len(record["fixtures"]) == 6
    assert all(f["result"] is not None for f in record["fixtures"])
    statuses = {p["status"] for picks in record["picks"].values() for p in picks}
    assert statuses <= {"won", "lost"} and statuses


def test_daily_run_writes_site_and_history(world, tmp_path):
    settings, source, _ = world
    result = pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "history",
                                tmp_path / "site", notify=False)
    site = tmp_path / "site"
    for name in ("index.html", "predictions.md", "predictions.csv", "data/latest.json",
                 f"data/{DAY}.json", f"data/{DAY + timedelta(days=1)}.json"):
        assert (site / name).exists(), name
    latest = json.loads((site / "data" / "latest.json").read_text())
    assert [d["date"] for d in latest["days"]] == [str(DAY), str(DAY + timedelta(days=1))]
    assert len(latest["days"][0]["fixtures"]) == 6
    assert sum(len(v) for v in latest["days"][0]["picks"].values()) > 0
    assert HistoryStore(tmp_path / "history").load(DAY) is not None
    assert result.report["track_record"]["over25"]["all"]["pending"] > 0


def test_daily_notifications_are_sent_once(world, tmp_path, monkeypatch):
    settings, source, _ = world
    sent: list[list[str]] = []
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "42")
    monkeypatch.setattr(pipeline, "send_telegram", lambda token, chat, messages: sent.append(messages))

    first = pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None)
    assert first.sent and len(sent) == 1
    assert "Daily tips" in sent[0][0]
    again = pipeline.run_daily(settings, source, DAY, MORNING + timedelta(hours=2), tmp_path / "h", None)
    assert not again.sent and len(sent) == 1

    # A fixture published later in the day triggers an update with just the new picks.
    teams = sorted({m.home for m in source._results["E0"]})
    late = fixture("E0", DAY, teams[0], teams[1], hour=20, odds_1x2=(2.0, 3.5, 3.8),
                   odds_ou25=(1.7, 2.2))
    source._fixtures.append(late)
    third = pipeline.run_daily(settings, source, DAY, MORNING + timedelta(hours=10), tmp_path / "h", None)
    assert third.sent and len(sent) == 2
    assert "Update" in sent[1][0]
    assert teams[0] in "".join(sent[1])
    record = HistoryStore(tmp_path / "h").load(DAY)
    assert len(record["notified"]) == sum(len(v) for v in record["picks"].values())


def test_late_first_notification_skips_started_matches(world, tmp_path, monkeypatch):
    settings, source, _ = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)
    sent: list[list[str]] = []
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "42")
    monkeypatch.setattr(pipeline, "send_telegram", lambda token, chat, messages: sent.append(messages))
    # Fixtures kick off at 14:00, 15:00 and 16:00 UTC; this run is at 14:30.
    later = datetime(2026, 5, 30, 14, 30, tzinfo=timezone.utc)
    result = pipeline.run_daily(settings, source, DAY, later, tmp_path / "h", None)
    assert result.sent
    record = HistoryStore(tmp_path / "h").load(DAY)
    by_key = {f"{p['market']}|{p['match_id']}": p for ps in record["picks"].values() for p in ps}
    assert record["notified"]
    assert all(by_key[key]["kickoff"] > later.isoformat() for key in record["notified"])
    started = [p for p in by_key.values() if p["kickoff"] <= later.isoformat()]
    assert started, "expected some picks for the 14:00 kick-offs"
    text = "".join(sent[0])
    assert all(f"{p['home']} v {p['away']}" not in text for p in started)


def test_daily_grades_yesterdays_picks(world, tmp_path):
    settings, source, results = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)
    # The matches are played; results appear in the source the next day.
    played = [Match(f.league, f.season, f.date, f.home, f.away, f.kickoff, 2, 1)
              for f in source.fixtures() if f.date == DAY]
    source._results["E0"] = results + played
    source._fixtures = [f for f in source._fixtures if f.date != DAY]
    next_morning = MORNING + timedelta(days=1)
    result = pipeline.run_daily(settings, source, DAY + timedelta(days=1), next_morning,
                                tmp_path / "h", None, notify=False)
    record = HistoryStore(tmp_path / "h").load(DAY)
    over25 = record["picks"]["over25"]
    assert over25 and all(p["status"] == "won" for p in over25)  # 2-1 is over 2.5
    assert all(p["status"] == "won" for p in record["picks"]["btts"])
    assert result.report["track_record"]["over25"]["all"]["won"] == len(over25)
    # Yesterday stays on the dashboard, graded, ahead of the upcoming days.
    days = result.report["days"]
    assert [d["date"] for d in days] == [str(DAY + timedelta(days=i)) for i in range(3)]
    assert result.report["today"] == str(DAY + timedelta(days=1))
    assert days[0]["picks"]["over25"][0]["status"] == "won"
    assert days[0]["picks"]["over25"][0]["result"] == [2, 1]


def test_next_mornings_message_recaps_yesterday(world, tmp_path, monkeypatch):
    settings, source, results = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)
    played = [Match(f.league, f.season, f.date, f.home, f.away, f.kickoff, 0, 0)
              for f in source.fixtures() if f.date == DAY]
    source._results["E0"] = results + played
    source._fixtures = [f for f in source._fixtures if f.date != DAY]
    sent: list[list[str]] = []
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "42")
    monkeypatch.setattr(pipeline, "send_telegram", lambda token, chat, messages: sent.append(messages))
    result = pipeline.run_daily(settings, source, DAY + timedelta(days=1), MORNING + timedelta(days=1),
                                tmp_path / "h", None)
    assert result.sent
    text = "\n".join(sent[0])
    assert (DAY + timedelta(days=1)).strftime("%a %d %b %Y") in text  # today's tips, not yesterday's
    assert "Yesterday's results" in text
    over25 = len(HistoryStore(tmp_path / "h").load(DAY)["picks"]["over25"])
    assert f"Over 2.5 Goals: ✅ 0 won · ❌ {over25} lost" in text  # 0-0 loses every over 2.5 pick


def test_report_covers_yesterday_and_three_upcoming_days_by_default(world, tmp_path):
    settings, source, _ = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)
    settings.days = Settings().days
    result = pipeline.run_daily(settings, source, DAY + timedelta(days=1), MORNING + timedelta(days=1),
                                tmp_path / "h", tmp_path / "site", notify=False)
    # Viewers a day ahead of the site's time zone still get a "tomorrow".
    assert [d["date"] for d in result.report["days"]] == [str(DAY + timedelta(days=i)) for i in range(4)]
    assert (tmp_path / "site" / "data" / f"{DAY + timedelta(days=3)}.json").exists()


def test_faster_scores_grade_picks_until_the_main_source_confirms(tmp_path, monkeypatch):
    names = ["Arsenal", "Chelsea", "Everton", "Fulham", "Liverpool", "Brentford",
             "Burnley", "Wolves", "Man United", "Man City", "Newcastle", "Tottenham"]
    results, _ = synthetic_league("E0", teams=names, seasons=(2023, 2024, 2025), seed=9)
    fixtures = [fixture("E0", DAY, names[i], names[i + 6], hour=14 + i % 3, odds_1x2=(2.2, 3.4, 3.3),
                        odds_ou25=(1.85, 2.0)) for i in range(6)]
    source = FakeSource({"E0": results}, list(fixtures))
    settings = Settings(leagues=["E0"], days=2)
    settings.selection.min_team_matches = 1
    for market in ("btts_over25", "over25", "btts", "double_chance"):
        settings.selection.rule(market).min_probability = 0.3
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)

    official = {"Wolves": "Wolverhampton Wanderers FC", "Man United": "Manchester United FC",
                "Man City": "Manchester City FC", "Newcastle": "Newcastle United FC",
                "Tottenham": "Tottenham Hotspur FC"}
    requested = []

    def fake_fetch(token, start, end, competitions):
        requested.append((token, start, end, set(competitions)))
        return [Score("PL", f.kickoff, (official.get(f.home, f"{f.home} FC"),),
                      (official.get(f.away, f"{f.away} FC"),), 0, 0) for f in fixtures]

    monkeypatch.setenv("FOOTBALL_DATA_API_KEY", "key")
    monkeypatch.setattr(pipeline, "fetch_scores", fake_fetch)
    source._fixtures = []
    evening = datetime(2026, 5, 30, 21, 45, tzinfo=timezone.utc)
    result = pipeline.run_daily(settings, source, DAY, evening, tmp_path / "h", None, notify=False)
    assert requested == [("key", DAY - timedelta(days=1), DAY, {"PL"})]
    record = HistoryStore(tmp_path / "h").load(DAY)
    assert all(f["result"] == [0, 0] for f in record["fixtures"])
    over25 = record["picks"]["over25"]
    assert over25 and all(p["status"] == "lost" and p["provisional"] for p in over25)  # 0-0
    assert "Premier League" in result.report["fast_results"]
    # Days later football-data.co.uk publishes its scores (2-1): the grades are corrected.
    source._results["E0"] = results + [Match(f.league, f.season, f.date, f.home, f.away, f.kickoff, 2, 1)
                                       for f in fixtures]
    pipeline.run_daily(settings, source, DAY + timedelta(days=2), MORNING + timedelta(days=2),
                       tmp_path / "h", None, notify=False)
    over25 = HistoryStore(tmp_path / "h").load(DAY)["picks"]["over25"]
    assert all(p["status"] == "won" and "provisional" not in p for p in over25)


def test_faster_scores_problems_never_stop_the_daily_run(world, tmp_path, monkeypatch):
    settings, source, _ = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)
    monkeypatch.setenv("FOOTBALL_DATA_API_KEY", "bad-key")

    def refuse(*args, **kwargs):
        raise LiveScoreError("football-data.org refused the request (HTTP 403)")

    monkeypatch.setattr(pipeline, "fetch_scores", refuse)
    evening = datetime(2026, 5, 30, 21, 45, tzinfo=timezone.utc)
    result = pipeline.run_daily(settings, source, DAY, evening, tmp_path / "h", tmp_path / "site", notify=False)
    assert (tmp_path / "site" / "index.html").exists()
    assert all(p["status"] == "pending" for p in result.report["days"][0]["picks"]["over25"])


def test_past_days_can_be_turned_off(world, tmp_path):
    settings, source, _ = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", None, notify=False)
    settings.past_days = 0
    result = pipeline.run_daily(settings, source, DAY + timedelta(days=1), MORNING + timedelta(days=1),
                                tmp_path / "h", None, notify=False)
    assert result.report["days"][0]["date"] == str(DAY + timedelta(days=1))


def test_site_is_installable_as_an_app(world, tmp_path):
    settings, source, _ = world
    pipeline.run_daily(settings, source, DAY, MORNING, tmp_path / "h", tmp_path / "site", notify=False)
    site = tmp_path / "site"
    manifest = json.loads((site / "manifest.webmanifest").read_text())
    assert manifest["display"] == "standalone" and manifest["start_url"] == "./"
    assert manifest["name"] == "GOLDING'S PREDICTION" and manifest["short_name"] == "GOLDING'S"
    assert manifest["theme_color"] == manifest["background_color"] == "#05050b"
    assert {"any", "maskable"} == {icon["purpose"] for icon in manifest["icons"]}
    assert len(manifest["short_name"]) <= 12  # fits under an Android home-screen icon
    sizes = {icon["sizes"] for icon in manifest["icons"]}
    assert {"192x192", "512x512"} <= sizes
    for icon in manifest["icons"]:
        assert (site / icon["src"]).read_bytes().startswith(b"\x89PNG")
    worker = (site / "sw.js").read_text()
    assert "fetch" in worker and 'cache: "no-cache"' in worker
    page = (site / "index.html").read_text()
    assert '<link rel="manifest" href="manifest.webmanifest">' in page
    assert 'serviceWorker.register("sw.js")' in page
    # Installed apps reload when a new version takes over or newer predictions are published.
    assert "controllerchange" in page and 'fetch("data/latest.json"' in page

# ⚽ GOLDING'S PREDICTION

Daily football predictions for four markets:

| Market | Tip | Wins when |
|---|---|---|
| 🔥 **BTTS & Over 2.5** | BTTS & Over 2.5 | both teams score **and** there are 3+ goals |
| ⚽ **Over 2.5 Goals** | Over 2.5 | 3+ goals |
| 🎯 **Both Teams To Score** | BTTS Yes | both teams score |
| 🛡️ **Double Chance** | 1X, X2 or 12 | the result is one of the two covered outcomes |

Every day it downloads the latest results, fixtures and bookmaker odds for 38 leagues, rates every team, and publishes at least 15 picks per market (when enough matches are scheduled), each with a probability, a confidence rating and the fair odds. The day's safest tips are highlighted as 🔒 bankers. You get them as:

- a mobile-friendly **web dashboard** (GitHub Pages) that installs as a desktop or phone app, with a neon theme whose colours slowly shift and an opening animation (a golden "G" football bounces in, a welcome message glows (`site.welcome` in `config.toml`), a player kicks the ball away and green digits stream up the screen; tap to skip),
- a **Telegram** message to your channel or group,
- **Markdown, CSV and JSON** files, and
- the `footy` **command-line tool**.

Every published pick is graded automatically once the score is known: **✓ and the final score** when it won, **✕ and the score** when it lost, **Pending** until the match is played and **Awaiting result** after the final whistle until the score is published. The dashboard always has three day buttons, **Yesterday**, **Today** and **Tomorrow**, on your own calendar; yesterday's picks stay there with their results, the morning Telegram message starts with a recap of them, and the **track record** builds itself. Picks are never edited after they are published.

No API key or paid data is needed. Everything comes from the free CSV files at [football-data.co.uk](https://www.football-data.co.uk). Optionally, a free [football-data.org](https://www.football-data.org) key gets final scores for the big leagues within hours instead of days (see [Faster results](#faster-results-optional)).

---

## Install it as an app (desktop or phone)

Once the dashboard is online (see [Daily delivery](#daily-delivery-with-github-actions); it needs GitHub Pages switched on), open it at `https://<your-user>.github.io/<repo>/` and install it:

- **Windows / Mac / Linux, Chrome or Edge:** click the install icon at the right end of the address bar (a monitor with a down arrow), or ⋮ menu → **Cast, save and share → Install page as app**, then **Install**. It gets its own window, a desktop or Start-menu icon, and a taskbar or dock entry.
- **Android, Chrome:** ⋮ menu → **Install app** (or **Add to Home screen**). It then appears in the app drawer like any other app. If you opened the link from Telegram, first choose **Open in Chrome**, because Telegram's built-in browser can't install apps.
- **iPhone / iPad, Safari:** Share → **Add to Home Screen**.

The installed app keeps itself up to date: it loads the latest predictions every time you open it, checks for a newer edition whenever you switch back to it (and every 15 minutes while it's on screen), and reloads by itself when a new version of the app is published. It still opens with the last predictions when you're offline. A new app name or icon reaches installed apps through the browser, which may ask you to accept the change; to get it immediately, uninstall and install again. To remove it, right-click its icon and choose uninstall, as with any app.

---

## Quick start

Requires Python 3.11+.

```bash
cd football-predictor
pip install .

footy predict                      # today's picks in the terminal
footy predict --date tomorrow      # tomorrow's picks
footy predict --date yesterday     # yesterday's picks, graded against the real scores
footy predict --format html -o today.html   # the dashboard as a single file
```

Example output:

```
Saturday 26 September 2026  (39 matches analysed, times in UTC)
==============================================================================

⚽  OVER 2.5 GOALS  (min 62%)
   14:00  Solihull v Boreham Wood                 71%  fair 1.41  mkt 1.33
          England · National League
   14:00  Stockport v Peterboro                   68%  fair 1.46  mkt 1.37
          England · League One
   23:30  Philadelphia Union v Orlando City       68%  fair 1.46
          USA · MLS

🛡️  DOUBLE CHANCE  (min 80%)
   14:00  Stockport v Peterboro                   1X  87%  fair 1.16  mkt 1.07
          England · League One
```

`mkt` is the average bookmaker price, where the data has one.

`fair` is 1 ÷ probability. When your bookmaker pays more than the fair odds, the bet is priced above what the model thinks it is worth.

### Other commands

```bash
footy daily --dry-run      # full daily job; prints the Telegram message instead of sending it
footy record               # track record from the prediction history
footy backtest --leagues main --start 2024-08-01 --end 2026-06-30   # walk-forward evaluation
footy ratings E0           # attack/defence ratings for a league
footy leagues              # supported leagues and presets
footy livecheck            # compare football-data.org scores with football-data.co.uk (needs FOOTBALL_DATA_API_KEY)
```

Common options: `--leagues top5,E1`, `--timezone Africa/Nairobi`, `--offline` (cached data only), `-v` (progress logs).

---

## Daily delivery with GitHub Actions

`.github/workflows/football-predictions.yml` runs the daily job three times a day:

- **05:15 UTC**: today's picks, dashboard update and Telegram message.
- **17:15 UTC**: refresh. football-data.co.uk adds midweek fixtures on Tuesday afternoons and weekend fixtures on Friday afternoons. Any new picks for tonight are sent as a Telegram "Update", and tomorrow's picks go on the dashboard.
- **21:45 UTC**: night run. Grades the day's finished matches (same-evening ticks and crosses for the big leagues when the football-data.org key is set).

Scheduled workflows only run from the default branch (`main`). With no further setup, every run:

- saves the prediction history to a separate `predictions-data` branch, so `main` stays clean;
- makes that branch's README show the latest picks and track record (open the branch on GitHub to see it);
- shows the picks on the run's summary page (**Actions → Daily football predictions → a run**);
- uploads the dashboard, Markdown and CSV as a downloadable artifact.

Optional extras:

1. **Web dashboard**: in **Settings → Pages**, set *Source* to **GitHub Actions**. The workflow detects this by itself; from the next run the dashboard is live at `https://<your-user>.github.io/<repo>/`.
2. **Telegram**
   1. Talk to [@BotFather](https://t.me/BotFather), send `/newbot`, and copy the token.
   2. Add the bot to your channel (as an admin) or group. Get the chat id, e.g. `@yourchannel` for a public channel, or from `https://api.telegram.org/bot<token>/getUpdates` after posting in the group.
   3. Add repository **secrets** `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (**Settings → Secrets and variables → Actions**).
3. **Faster results**: see below.

### Faster results (optional)

football-data.co.uk updates most results only on Sunday and Wednesday nights, so a pick can show *Awaiting result* for a few days. With a free [football-data.org](https://www.football-data.org/client/register) key, picks in these leagues are ticked or crossed within hours of the final whistle: Premier League, Championship, Bundesliga, Serie A, La Liga, Ligue 1, Eredivisie, Primeira Liga and Brazil's Série A (the competitions in its free plan). Other leagues still wait for football-data.co.uk.

1. Register at football-data.org; the key arrives by email.
2. Add it as the repository secret `FOOTBALL_DATA_API_KEY`.
3. Optional check: **Actions → Check faster results (football-data.org) → Run workflow** compares the two sources over the last 10 days, match by match.

The two sites spell clubs differently ("Man United" vs "Manchester United FC"), so scores are matched by league, kick-off time and team names, and unclear pairings are skipped. A pick graded this way is provisional until football-data.co.uk publishes the same match: its score then confirms the grade, or corrects it. If football-data.org is down or the key stops working, the daily run carries on and logs a warning. The key is never printed.

To run it now instead of waiting for the schedule: **Actions → Daily football predictions → Run workflow**.

To change the schedule, edit the `cron` lines (they are in UTC). Set `timezone` in `config.toml` so "today" and the kick-off times match where you are.

In public repositories, GitHub pauses scheduled workflows after 60 days without repository activity and emails you first; re-enable it on the Actions tab with one click.

---

## Configuration

Settings live in [`config.toml`](config.toml); every value is optional. The most useful ones:

```toml
timezone = "Africa/Nairobi"     # defines "today" and kick-off times
leagues = ["top5", "E1", "USA"] # presets and/or league codes
days = 3                        # upcoming days in the report: today + the next two
past_days = 1                   # also show yesterday's picks with their results (0 = off)

[selection.over25]
min_probability = 0.62          # "strong" picks need at least this probability
min_picks = 15                  # top the list up to this many picks a day...
floor = 0.50                    # ...but never with a pick below this probability
max_picks = 20                  # most strong picks per day
banker_probability = 0.75       # picks this likely are flagged as bankers
# min_edge = 0.0                # also require probability × odds − 1 ≥ this (where odds exist)
```

The same settings exist for `btts_over25`, `btts` and `double_chance`, plus `selection.min_team_matches`, which skips teams with too little recent data. Model settings are documented inline in `config.toml`.

Every pick carries a label:

| Label | Meaning |
|---|---|
| 🔒 Banker | One of the day's safest tips: Double Chance at 88%+ or Over 2.5 at 75%+ |
| ★ to ★★★ | A strong pick: ★ just over the market's threshold, ★★ 5+ points over, ★★★ 10+ points over |
| ☆ Extra | Added to reach 15 picks on a day with too few strong ones. Weaker, but still above the floor |

---

## How it works

1. **Data.** football-data.co.uk has results with pre-match odds for 22 European leagues (from 2026/27 also xG), plus 16 extra leagues such as MLS, Brazil, Argentina and J1. Fixture files with odds come out twice a week. Downloads are cached; finished seasons are fetched once.
2. **Team ratings.** Each league gets a [Dixon-Coles](https://doi.org/10.1111/1467-9876.00065) model. Every team has an attack and a defence rating, and there is a home advantage and a low-score correction (ρ). It is fitted on up to three seasons:
   - Matches are time-weighted with a 365-day half-life.
   - Ratings are shrunk toward the league average; newly promoted teams start weaker, relegated teams start stronger.
   - xG is blended with goals where available.
3. **Market blend.** Bookmaker prices are converted into the expected goals they imply: Over/Under 2.5 gives the total, and 1X2 gives the split between the teams. These are blended 85/15 with the model's expected goals, because in testing the market was the sharper signal.
4. **One scoreline table, four markets.** Expected goals become a probability for every scoreline (0-0, 1-0, … 12-12), and all four markets are read from that one table. So they always agree with each other. In particular, BTTS & Over 2.5 is computed exactly (P(BTTS) − P(1-1)); multiplying P(BTTS) × P(Over 2.5) would understate it, because the two events are strongly correlated.
5. **Picks.** Matches above each market's threshold are strong picks (up to `max_picks`). If there are fewer than `min_picks`, the list is topped up with the next most likely matches, labelled ☆ extra, but never below the market's `floor` (for Over 2.5 and BTTS that is 50%, so every tip is more likely to win than lose). Picks are sorted most likely first, and the safest are flagged 🔒 bankers. For Double Chance the tip is the option that leaves out the least likely result. On quiet days (for example an international break, or a Tuesday before the midweek fixtures are published) there may simply not be 15 matches that clear the floor.
6. **History and grading.** Each day's predictions are saved as JSON. Later runs attach final scores and settle picks as won (✓), lost (✕) or void (no result 10 days after the match date, usually a postponement).

## Accuracy

Walk-forward backtests: the model was refitted every week using only matches played before that week, then used to predict the following week. That is exactly what the daily job does live.

**22 European leagues, Aug 2024 – Jun 2026 (15,319 matches), default settings:**

| Market | Pick threshold | Picks | Predicted | Actual hit rate | Base rate | ROI at average odds |
|---|---|---|---|---|---|---|
| BTTS & Over 2.5 | 50% | 1,227 | 53.3% | **53.2%** | 41.2% | no odds in data |
| Over 2.5 | 62% | 1,499 | 67.0% | **67.3%** | 51.4% | −4.7% |
| BTTS | 60% | 1,487 | 62.9% | **62.0%** | 53.5% | no odds in data |
| Double Chance | 80% | 3,884 | 85.9% | **87.7%** | 77.8% | −4.1% |

**16 extra leagues, Mar 2025 – Sep 2026 (7,541 matches, model only because their history files have no pre-match odds):** BTTS & Over 2.5 55.0% (1,109 picks), Over 2.5 70.6% (746), BTTS 63.0% (1,391), Double Chance 85.5% (971).

What this shows:

- **The probabilities are well calibrated.** When the app says 67%, it happens about 67% of the time, which is what makes the tips and fair odds trustworthy.
- **The picks beat the base rate by a wide margin.** Over 2.5 tips land 67% of the time against 51% for all matches.
- **This is not a proven money-making system.** Against average bookmaker odds, flat stakes lost about 4–5%, roughly the bookmaker's margin. The model matches the market's accuracy (Over 2.5 Brier 0.2433 vs 0.2431) but does not beat it. Use the fair odds to avoid bets that are priced too short, and treat any "edge" badge with caution.

**Strong picks, extra picks and bankers** (same backtest, 15 picks a day wherever enough matches cleared the floor):

| Market | Strong picks won | ☆ Extra picks won | 🔒 Bankers won |
|---|---|---|---|
| BTTS & Over 2.5 | 53.2% | 45.1% | none (never that certain) |
| Over 2.5 | 67.3% | 56.1% | **87.4%** (87 picks, 75%+) |
| BTTS | 62.0% | 56.9% | none (never that certain) |
| Double Chance | 88.3% | 74.1% | **94.5%** (1,159 picks, 88%+) |

No setting gets football tips close to 100%. Bankers are the closest: roughly 9 in 10 win, and they still lose sometimes. Longer lists mean more tips, not better ones; the extra picks are the weakest part of each list, which is why they are labelled. BTTS markets never reach banker-level certainty: even when two attacking teams with leaky defences meet, the chance that both score rarely goes above about 65%.

Reproduce these numbers with `footy backtest --leagues main --start 2024-08-01 --end 2026-06-30`.

## Limitations

- Fixtures appear only when football-data.co.uk publishes them (Tuesday and Friday afternoons, UK time). Matches on a Tuesday or Friday evening are usually picked up by the 17:15 UTC run, not the morning run.
- Results arrive when football-data.co.uk publishes them: for most leagues that is twice a week (Sunday and Wednesday nights, UK time). A Saturday pick is usually ticked or crossed on Monday morning; until then it shows *Awaiting result*. With a football-data.org key, the nine leagues in its free plan are graded the same day.
- Only league matches are covered: no cups, European competitions or internationals.
- The model knows nothing about injuries, suspensions, rotation or motivation, except through the bookmaker odds.
- Early in a season, promoted teams have little data; `min_team_matches` keeps them out of the picks until they have played a few games.

**Please gamble responsibly. Predictions are probabilities, not certainties. 18+ only.**

---

## Project layout

```
football-predictor/
├── config.toml                  # settings (all optional)
├── src/footy_predictor/
│   ├── data.py                  # football-data.co.uk download, cache and CSV parsing
│   ├── leagues.py               # league catalogue and presets
│   ├── model.py                 # time-weighted Dixon-Coles model
│   ├── markets.py               # scoreline table → market probabilities, odds maths
│   ├── engine.py                # fits a model per league and predicts fixtures
│   ├── selection.py             # thresholds → daily picks
│   ├── history.py               # day records, grading, track record
│   ├── render.py                # Markdown, Telegram, CSV, text and HTML output
│   ├── templates/dashboard.html # the web dashboard
│   ├── notify.py                # Telegram delivery
│   ├── livescores.py            # faster final scores from football-data.org (optional)
│   ├── pipeline.py              # predict + daily workflows
│   ├── backtest.py              # walk-forward evaluation
│   └── cli.py                   # the `footy` command
└── tests/                       # pytest suite (offline, synthetic leagues)
```

## Development

```bash
pip install -e ".[dev]"
pytest
```

The tests run offline against synthetic leagues with known team strengths. They check that:

- the model recovers those strengths;
- the market maths is internally consistent;
- published picks are frozen and grading is correct;
- the Telegram messages respect Telegram's length limit and escape HTML;
- the full daily job works end to end, including sending each pick only once.

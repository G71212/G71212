# HFT Scalper Pro - MetaTrader 5 Expert Advisor

A comprehensive, modular hybrid HFT scalping Expert Advisor for MT5 with **~630 configurable input parameters** across **84 categories**. Built with a clean, object-oriented architecture using separate include files for each subsystem.

## Architecture

```
MQL5/
  Experts/
    HFT_Scalper_Pro.mq5      Main EA file (event handlers, module orchestration)
    HFT_Scalper_EA.mq5       Lightweight standalone version (simpler alternative)
  Include/
    HFT/
      Enums.mqh               Custom enumerations
      Inputs.mqh              All ~630 input parameters (84 categories)
      Utils.mqh               Utility functions (lot calc, logging, license, etc.)
      SignalEngine.mqh         25+ indicator signal generators with scoring system
      RiskManager.mqh          Daily limits, drawdown, martingale, recovery, equity curve
      TradeManager.mqh         Order execution, trailing, BE, partial close, grid
      SessionFilter.mqh        Time, day, session, news, swap, weekend filters
      Dashboard.mqh            On-chart HUD with stats and control panel buttons
```

## Strategy Overview

The EA uses a **multi-indicator confluence** approach with an optional **signal scoring system**:

### Entry Signals (25+ indicators)
- Moving Average crossover (EMA/SMA/SMMA/LWMA)
- RSI momentum filter
- Stochastic oscillator
- MACD signal/zero-line crossover
- Bollinger Bands bounce/breakout/squeeze
- CCI overbought/oversold
- Momentum / Rate of Change
- Ichimoku cloud + TK cross
- ADX trend strength + DI direction
- Parabolic SAR
- Williams %R
- DeMarker
- Envelopes
- Bears/Bulls Power
- Fractals breakout
- Supertrend
- VWAP
- Pivot Points (Classic/Camarilla/Woodie/Fibonacci)
- Fibonacci retracement levels
- Price action patterns (engulfing, pin bar, inside bar, doji)
- Tick/volume burst detection
- Support/Resistance levels
- DOM (Depth of Market) order flow
- Spread scalping (pure HFT mode)
- 2 custom indicator slots

### Signal Modes
1. **Direct mode**: First indicator that generates a signal triggers the trade (with filters)
2. **Scoring mode**: Each indicator contributes a weighted score; trade fires when total score exceeds threshold

### Filters Applied Before Entry
- ATR volatility gate (min/max)
- ADX trend strength gate
- Candle size filter (body, range, wick ratios)
- Gap filter with cooldown
- Spike filter with cooldown
- Higher timeframe trend confirmation
- Multi-timeframe confirmation (up to 3 additional TFs)
- Market type detection (trending/ranging)

## Key Feature Categories

### Execution (Cat. 24)
- Market orders with retry logic
- Pending orders (limit) with expiry
- Fill policy selection (FOK/IOC/Return)
- Configurable slippage tolerance
- Async order mode for speed

### Risk Management (Cat. 25-27)
- Per-trade risk: fixed lot, % equity, % balance, % margin, fixed margin, Kelly Criterion
- Daily limits: max loss (USD/%), profit target, max trades, consecutive loss pause
- Drawdown protection: hard stop, soft pause, equity floor
- Recovery mode with configurable trigger and exit

### Trade Management (Cat. 4-5, 31)
- Trailing stop (fixed or ATR-based) with activation distance and step
- Break-even with configurable offset
- Multi-level partial close (TP1/TP2/TP3 with configurable percentages)
- Time-based exit (max duration in minutes/seconds)
- Hidden SL/TP (EA-managed, not visible to broker)
- Opposite signal exit
- Spread spike close

### Position Sizing Modifiers (Cat. 29-30, 56-58)
- Martingale / Anti-Martingale with configurable steps
- Grid trading with lot multiplier
- Pyramiding (scaling into winners)
- Averaging down
- Recovery mode lot multiplier
- Equity curve lot reduction
- Win-streak lot adjustment
- Session-based lot scaling
- Volatility regime lot scaling

### Session & Time Control (Cat. 20-22, 62)
- 3 configurable trading sessions
- GMT offset with auto DST
- Day-of-week filters
- No-trade zones (rollover, swap time)
- EOD close (all or profit only)
- Friday close / weekend protection
- News filter using MQL5 Economic Calendar (high/medium/low impact)

### Dashboard & Visualization (Cat. 33, 73-74, 81)
- On-chart HUD: spread, P&L, trade count, session, status
- Performance stats: win rate, profit factor, R:R, avg win/loss, max DD
- Commission and swap tracking
- Effective R:R after spread and commission
- Control panel buttons: Close All, Pause, Go Flat, Manual Buy/Sell
- Signal arrows and SL/TP lines on chart
- Color-customizable everything

### Protection & Licensing (Cat. 1, 37, 63, 83-84)
- Account number locking
- Broker whitelist
- Expiry date
- VPS-only mode
- Demo/Live account control
- Absolute equity floor
- Margin level requirements
- Global kill switch
- Stealth mode (no chart objects)

## Installation

1. Copy the entire `MQL5/` folder structure into your MT5 data directory:
   - `MQL5/Experts/HFT_Scalper_Pro.mq5`
   - `MQL5/Include/HFT/*.mqh` (all 8 include files)
2. Open MetaEditor, navigate to `Experts/HFT_Scalper_Pro.mq5`
3. Press Compile (F7)
4. Drag the EA onto a chart
5. Configure parameters and enable "Allow Algo Trading"

## Quick Start Configuration

### Conservative Scalping (recommended starting point)
- Lot Mode: % of Equity, Risk: 0.5%
- SL: 50 points, TP: 80 points
- Use MA Signal: true (5/20 EMA cross)
- Use RSI Filter: true (period 7)
- Use ATR Filter: true
- Use ADX Filter: true (min 20)
- Max Open Positions: 1
- Max Daily Loss: 2%
- Sessions: London + NY only

### Aggressive HFT
- Lot Mode: Fixed lot 0.1
- SL: 30 points, TP: 40 points
- Enable signal scoring with min score 3
- Enable multiple indicators
- Max Open Positions: 3
- Trailing Stop: enabled at 20 points
- Partial close: TP1 at 20pts (50%), trail remainder

## Recommended Environment
| Factor | Recommendation |
|--------|---------------|
| Broker | ECN/STP, raw spread < 0.3 pip on EURUSD |
| VPS latency | < 5ms to broker server |
| Timeframe | M1 primary, M5 higher TF filter |
| Best pairs | EURUSD, GBPUSD, USDJPY, XAUUSD |
| Avoid | High spread brokers, B-book market makers |

## Backtesting

The EA is fully compatible with MT5 Strategy Tester:
- Use "Every tick based on real ticks" model for accuracy
- Enable spread simulation
- All ~630 parameters are exposed for optimization
- Custom optimization criterion available (balance, PF, or custom formula)
- Walk-forward compatible parameter sets

## Parameter Count by Category

| # | Category | Params |
|---|----------|--------|
| 1 | EA Identity & License | 9 |
| 2 | Lot Sizing | 9 |
| 3 | SL & TP | 16 |
| 4 | Trailing Stop | 8 |
| 5 | Break-Even | 4 |
| 6-18 | Entry Signals (13 categories) | ~120 |
| 19 | Timeframe Settings | 7 |
| 20-22 | Session/Day/News Filters | 32 |
| 23 | Spread Control | 7 |
| 24 | Execution | 12 |
| 25-27 | Risk Management | 24 |
| 28 | Position Limits | 9 |
| 29-30 | Martingale/Grid | 15 |
| 31 | Exit Conditions | 10 |
| 32 | Alerts | 13 |
| 33 | Dashboard | 18 |
| 34 | Logging | 10 |
| 35-38 | Symbol/Backtest/Broker/VPS | 30 |
| 39-52 | Additional Indicators & Filters | ~100 |
| 53-84 | Advanced Features | ~180 |
| **Total** | **84 categories** | **~630** |

## Risk Disclaimer

This EA is provided for **educational and research purposes**. Trading forex, CFDs, and other leveraged instruments carries significant risk. Past performance does not guarantee future results. Always test thoroughly on a demo account before deploying with real funds. The author assumes no liability for financial losses.

## License

MIT License -- free to use, modify, and distribute.

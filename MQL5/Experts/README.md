# HFT Scalper EA for MetaTrader 5

A high-frequency trading scalping Expert Advisor for MT5 that combines EMA crossover signals, RSI momentum filtering, and Bollinger Band mean-reversion logic with strict risk management.

## Strategy Overview

The EA uses a multi-indicator confluence approach:

1. **EMA Crossover** (5/13 default) -- detects short-term trend shifts
2. **RSI Filter** (period 7) -- confirms momentum direction and avoids exhausted moves
3. **Bollinger Bands** (period 14, 2 std dev) -- adds mean-reversion context to filter entries

A trade is opened only when all three conditions align.

## Key Features

- **Spread Filter**: Skips entries when spread exceeds threshold (avoids slippage in volatile conditions)
- **Trading Hours Filter**: Restricts activity to configurable server-time windows
- **Break Even**: Automatically moves stop loss to entry price once position is in profit
- **Trailing Stop**: Locks in profits as price moves favorably
- **Daily Loss/Profit Limits**: Stops trading after hitting daily drawdown cap or profit target
- **Async Order Execution**: Uses asynchronous mode for faster order placement
- **Dynamic Position Sizing**: Risk-percentage-based lot calculation or fixed lot mode

## Installation

1. Copy `HFT_Scalper_EA.mq5` into your MT5 `MQL5/Experts/` directory
2. Open MetaEditor and compile the file (or restart MT5 to auto-compile)
3. Drag the EA onto a chart (M1 timeframe recommended)
4. Configure the input parameters in the EA properties dialog
5. Ensure "Allow Algo Trading" is enabled in MT5 settings

## Input Parameters

### General Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| Magic Number | 202504 | Unique identifier for this EA's trades |
| Timeframe | M1 | Chart timeframe for signal calculation |

### Risk Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| Risk per trade | 1.0% | Percentage of balance risked per trade |
| Fixed lots | 0.0 | Override lot size (0 = use risk %) |
| Max lots | 10.0 | Maximum allowed lot size |
| Max open trades | 3 | Simultaneous position limit |
| Max daily loss | 5.0% | Daily drawdown cap |
| Daily profit target | 10.0% | Stop trading after reaching this profit |

### Scalping Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| Take Profit | 5 pips | Target profit per trade |
| Stop Loss | 3 pips | Maximum loss per trade |
| Trailing Stop | 2 pips | Trail distance (0 = disabled) |
| Break Even | 3 pips | Activation distance (0 = disabled) |
| Max Spread | 15 points | Skip trades above this spread |
| Slippage | 5 points | Maximum allowed slippage |

### Indicator Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| Fast EMA | 5 | Fast moving average period |
| Slow EMA | 13 | Slow moving average period |
| RSI Period | 7 | RSI calculation period |
| RSI Overbought | 70 | Upper RSI threshold |
| RSI Oversold | 30 | Lower RSI threshold |
| BB Period | 14 | Bollinger Bands period |
| BB Deviation | 2.0 | Standard deviation multiplier |

## Recommended Setup

- **Symbol**: Major forex pairs (EURUSD, GBPUSD, USDJPY) or indices with tight spreads
- **Timeframe**: M1 (primary), M5 (less frequent signals)
- **Broker**: ECN/STP with low latency and tight spreads
- **VPS**: Strongly recommended for consistent execution speed

## Risk Disclaimer

This EA is provided for educational and research purposes. Trading forex and CFDs carries significant risk. Past performance does not guarantee future results. Always test thoroughly on a demo account before deploying with real funds. The author assumes no liability for financial losses.

## License

MIT License -- free to use, modify, and distribute.

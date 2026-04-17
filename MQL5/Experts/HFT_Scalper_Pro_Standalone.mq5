//+------------------------------------------------------------------+
//|                                HFT_Scalper_Pro_Standalone.mq5     |
//|          HFT Scalper Pro - Single-File Standalone Version          |
//|          ~630 parameters, 84 categories, 25+ indicators            |
//|          Copy this single file to MQL5/Experts/ and compile        |
//+------------------------------------------------------------------+
#property copyright   "HFT Scalper Pro"
#property link        "https://github.com/G71212/G71212"
#property version     "1.00"
#property description "Hybrid HFT Scalping EA - Standalone single-file version"
#property description "~630 configurable parameters across 84 categories"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>


// ==================================================================
// SOURCE: Enums.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                                      Enums.mqh   |
//|                        HFT Scalper Pro - Custom Enumerations      |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Lot sizing mode                                                   |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
{
   LOT_FIXED          = 0,  // Fixed Lot
   LOT_PERCENT_EQUITY = 1,  // % of Equity
   LOT_PERCENT_BALANCE= 2,  // % of Balance
   LOT_PERCENT_MARGIN = 3,  // % of Margin
   LOT_FIXED_MARGIN   = 4   // Fixed Margin Amount
};

//+------------------------------------------------------------------+
//| Trade direction control                                           |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIR
{
   TRADE_BOTH      = 0,  // Buy & Sell
   TRADE_BUY_ONLY  = 1,  // Buy Only
   TRADE_SELL_ONLY = 2   // Sell Only
};

//+------------------------------------------------------------------+
//| Pivot point calculation type                                      |
//+------------------------------------------------------------------+
enum ENUM_PP_TYPE
{
   PP_CLASSIC    = 0,  // Classic
   PP_CAMARILLA  = 1,  // Camarilla
   PP_WOODIE     = 2,  // Woodie
   PP_FIBONACCI  = 3   // Fibonacci
};

//+------------------------------------------------------------------+
//| Market type detection                                             |
//+------------------------------------------------------------------+
enum ENUM_MARKET_TYPE
{
   MARKET_UNKNOWN  = 0,  // Unknown
   MARKET_TRENDING = 1,  // Trending
   MARKET_RANGING  = 2   // Ranging
};

//+------------------------------------------------------------------+
//| Signal strength / score                                           |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_STRENGTH
{
   SIGNAL_NONE   = 0,  // No Signal
   SIGNAL_WEAK   = 1,  // Weak
   SIGNAL_MEDIUM = 2,  // Medium
   SIGNAL_STRONG = 3   // Strong
};

//+------------------------------------------------------------------+
//| Log level                                                         |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_NONE    = 0,  // None
   LOG_BASIC   = 1,  // Basic
   LOG_DETAIL  = 2,  // Detailed
   LOG_VERBOSE = 3   // Verbose
};

//+------------------------------------------------------------------+
//| Order fill policy                                                 |
//+------------------------------------------------------------------+
enum ENUM_FILL_POLICY
{
   FILL_FOK    = 0,  // Fill or Kill
   FILL_IOC    = 1,  // Immediate or Cancel
   FILL_RETURN = 2   // Return
};

//+------------------------------------------------------------------+
//| Optimization custom criterion                                     |
//+------------------------------------------------------------------+
enum ENUM_OPT_CRITERION
{
   OPT_BALANCE       = 0,  // Balance
   OPT_PROFIT_FACTOR = 1,  // Profit Factor
   OPT_CUSTOM        = 2   // Custom
};


// ==================================================================
// SOURCE: Inputs.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                                     Inputs.mqh   |
//|                   HFT Scalper Pro - All Input Parameters          |
//|                   ~630 parameters across 84 categories            |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| 1. EA IDENTITY & LICENSE                                          |
//+------------------------------------------------------------------+
input group "=== 1. EA Identity & License ==="
input string   EA_Name                = "HFT Scalper Pro";    // EA Name
input string   EA_Version             = "1.0.0";              // EA Version
input long     Magic_Number           = 123456;               // Magic Number
input string   Order_Comment          = "HFT_SCALP";          // Order Comment
input long     Licensed_Account       = 0;                    // Licensed Account (0=any)
input string   License_Key            = "";                    // License Key
input datetime EA_Expiry_Date         = 0;                    // Expiry Date (0=none)
input bool     Run_On_VPS_Only        = false;                // Run Only on VPS
input string   Allowed_Broker_Name    = "";                   // Allowed Broker (blank=all)

//+------------------------------------------------------------------+
//| 2. LOT SIZE & POSITION SIZING                                     |
//+------------------------------------------------------------------+
input group "=== 2. Lot Size & Position Sizing ==="
input ENUM_LOT_MODE Lot_Mode          = LOT_FIXED;            // Lot Sizing Mode
input double   Fixed_Lot              = 0.01;                 // Fixed Lot Size
input double   Risk_Percent           = 1.0;                  // Risk % per Trade
input double   Fixed_Margin_Amount    = 100.0;                // Fixed Margin (USD)
input double   Min_Lot                = 0.01;                 // Minimum Lot
input double   Max_Lot                = 10.0;                 // Maximum Lot
input double   Lot_Step               = 0.01;                 // Lot Step
input int      Decimal_Lots           = 2;                    // Lot Decimal Places
input bool     Round_Lot_Down         = true;                 // Round Lots Down

//+------------------------------------------------------------------+
//| 3. STOP LOSS & TAKE PROFIT                                        |
//+------------------------------------------------------------------+
input group "=== 3. Stop Loss & Take Profit ==="
input double   Stop_Loss_Points       = 50;                   // Stop Loss (points)
input double   Take_Profit_Points     = 80;                   // Take Profit (points)
input double   Min_SL_Points          = 10;                   // Minimum SL (points)
input double   Max_SL_Points          = 300;                  // Maximum SL (points)
input bool     Use_Dynamic_SL         = false;                // Use ATR-Based SL
input double   ATR_SL_Multiplier      = 1.5;                  // ATR SL Multiplier
input int      ATR_Period             = 14;                   // ATR Period (SL/TP)
input bool     Use_Dynamic_TP         = false;                // Use ATR-Based TP
input double   ATR_TP_Multiplier      = 2.0;                  // ATR TP Multiplier
input double   TP1_Points             = 40;                   // TP1 Partial Close (points)
input double   TP2_Points             = 80;                   // TP2 Second Close (points)
input double   TP3_Points             = 120;                  // TP3 Final Close (points)
input double   TP1_Close_Percent      = 50.0;                 // TP1 Close %
input double   TP2_Close_Percent      = 30.0;                 // TP2 Close %
input double   TP3_Close_Percent      = 20.0;                 // TP3 Close %
input bool     Use_Hidden_SL          = false;                // Hidden SL (EA-managed)
input bool     Use_Hidden_TP          = false;                // Hidden TP (EA-managed)

//+------------------------------------------------------------------+
//| 4. TRAILING STOP                                                  |
//+------------------------------------------------------------------+
input group "=== 4. Trailing Stop ==="
input bool     Use_Trailing_Stop      = true;                 // Enable Trailing Stop
input double   Trail_Start_Points     = 30;                   // Trail Activation (points)
input double   Trail_Step_Points      = 10;                   // Trail Step (points)
input double   Trail_Distance_Points  = 20;                   // Trail Distance (points)
input bool     Use_ATR_Trail          = false;                // ATR-Based Trail
input double   ATR_Trail_Multiplier   = 1.0;                  // ATR Trail Multiplier
input bool     Trail_All_Positions    = true;                 // Trail All Positions
input bool     Trail_From_Open        = false;                // Trail from Open Price

//+------------------------------------------------------------------+
//| 5. BREAK-EVEN                                                     |
//+------------------------------------------------------------------+
input group "=== 5. Break-Even ==="
input bool     Use_BreakEven          = true;                 // Enable Break-Even
input double   BE_Activation_Points   = 20;                   // BE Activation (points)
input double   BE_Offset_Points       = 2;                    // BE Offset (points)
input bool     BE_After_TP1           = true;                 // Move to BE after TP1

//+------------------------------------------------------------------+
//| 6. ENTRY SIGNAL - MOVING AVERAGES                                 |
//+------------------------------------------------------------------+
input group "=== 6. Moving Average Signal ==="
input bool     Use_MA_Signal          = true;                 // Enable MA Signal
input int      Fast_MA_Period         = 5;                    // Fast MA Period
input int      Slow_MA_Period         = 20;                   // Slow MA Period
input ENUM_MA_METHOD MA_Method        = MODE_EMA;             // MA Method
input ENUM_APPLIED_PRICE MA_Price     = PRICE_CLOSE;          // MA Applied Price
input int      Signal_MA_Period       = 3;                    // Signal Line Period
input bool     MA_Cross_Only          = false;                // Enter Only on Cross
input double   MA_Gap_Min_Points      = 5;                    // Min MA Gap (points)

//+------------------------------------------------------------------+
//| 7. ENTRY SIGNAL - RSI                                             |
//+------------------------------------------------------------------+
input group "=== 7. RSI Filter ==="
input bool     Use_RSI_Filter         = true;                 // Enable RSI Filter
input int      RSI_Period             = 7;                    // RSI Period
input ENUM_APPLIED_PRICE RSI_Price    = PRICE_CLOSE;          // RSI Applied Price
input double   RSI_Overbought         = 70;                   // RSI Overbought
input double   RSI_Oversold           = 30;                   // RSI Oversold
input double   RSI_Buy_Level          = 50;                   // RSI Buy Above Level
input double   RSI_Sell_Level         = 50;                   // RSI Sell Below Level
input bool     RSI_Divergence         = false;                // Use RSI Divergence

//+------------------------------------------------------------------+
//| 8. ENTRY SIGNAL - STOCHASTIC                                      |
//+------------------------------------------------------------------+
input group "=== 8. Stochastic Filter ==="
input bool     Use_Stoch_Filter       = false;                // Enable Stochastic
input int      Stoch_K_Period         = 5;                    // %K Period
input int      Stoch_D_Period         = 3;                    // %D Period
input int      Stoch_Slowing          = 3;                    // Slowing
input double   Stoch_Overbought       = 80;                   // Overbought Level
input double   Stoch_Oversold         = 20;                   // Oversold Level
input ENUM_MA_METHOD Stoch_MA_Method  = MODE_SMA;             // Stochastic MA Method
input ENUM_STO_PRICE Stoch_Price      = STO_LOWHIGH;          // Stochastic Price

//+------------------------------------------------------------------+
//| 9. ENTRY SIGNAL - MACD                                            |
//+------------------------------------------------------------------+
input group "=== 9. MACD Signal ==="
input bool     Use_MACD_Signal        = false;                // Enable MACD
input int      MACD_Fast_Period       = 12;                   // MACD Fast Period
input int      MACD_Slow_Period       = 26;                   // MACD Slow Period
input int      MACD_Signal_Period     = 9;                    // MACD Signal Period
input ENUM_APPLIED_PRICE MACD_Price   = PRICE_CLOSE;          // MACD Applied Price
input bool     MACD_Cross_Signal      = true;                 // Signal Line Cross
input bool     MACD_Zero_Cross        = false;                // Zero Line Cross
input double   MACD_Min_Histogram     = 0.0001;               // Min Histogram Value

//+------------------------------------------------------------------+
//| 10. ENTRY SIGNAL - BOLLINGER BANDS                                |
//+------------------------------------------------------------------+
input group "=== 10. Bollinger Bands ==="
input bool     Use_BB_Signal          = false;                // Enable Bollinger Bands
input int      BB_Period              = 20;                   // BB Period
input double   BB_Deviation           = 2.0;                  // BB Deviation
input ENUM_APPLIED_PRICE BB_Price     = PRICE_CLOSE;          // BB Applied Price
input bool     BB_Bounce_Signal       = true;                 // Bounce Signal
input bool     BB_Breakout_Signal     = false;                // Breakout Signal
input bool     BB_Squeeze_Filter      = false;                // Squeeze Filter
input double   BB_Squeeze_Threshold   = 0.0010;               // Squeeze Threshold

//+------------------------------------------------------------------+
//| 11. ENTRY SIGNAL - ATR VOLATILITY FILTER                          |
//+------------------------------------------------------------------+
input group "=== 11. ATR Volatility Filter ==="
input bool     Use_ATR_Filter         = true;                 // Enable ATR Filter
input int      ATR_Filter_Period      = 14;                   // ATR Period
input double   ATR_Min_Value          = 0.0003;               // Min ATR to Trade
input double   ATR_Max_Value          = 0.0050;               // Max ATR to Trade
input ENUM_TIMEFRAMES ATR_Timeframe   = PERIOD_M1;            // ATR Timeframe

//+------------------------------------------------------------------+
//| 12. ENTRY SIGNAL - CCI                                            |
//+------------------------------------------------------------------+
input group "=== 12. CCI Filter ==="
input bool     Use_CCI_Filter         = false;                // Enable CCI Filter
input int      CCI_Period             = 14;                   // CCI Period
input ENUM_APPLIED_PRICE CCI_Price    = PRICE_TYPICAL;        // CCI Applied Price
input double   CCI_Overbought         = 100;                  // CCI Overbought
input double   CCI_Oversold           = -100;                 // CCI Oversold

//+------------------------------------------------------------------+
//| 13. ENTRY SIGNAL - MOMENTUM / ROC                                 |
//+------------------------------------------------------------------+
input group "=== 13. Momentum / ROC ==="
input bool     Use_Momentum_Signal    = false;                // Enable Momentum
input int      Momentum_Period        = 10;                   // Momentum Period
input double   Momentum_Level         = 100.1;                // Momentum Level
input bool     Use_ROC_Signal         = false;                // Enable ROC
input int      ROC_Period             = 10;                   // ROC Period
input double   ROC_Threshold          = 0.1;                  // ROC Threshold

//+------------------------------------------------------------------+
//| 14. ENTRY SIGNAL - ICHIMOKU                                       |
//+------------------------------------------------------------------+
input group "=== 14. Ichimoku ==="
input bool     Use_Ichimoku           = false;                // Enable Ichimoku
input int      Tenkan_Period          = 9;                    // Tenkan-sen Period
input int      Kijun_Period           = 26;                   // Kijun-sen Period
input int      Senkou_B_Period        = 52;                   // Senkou Span B Period
input bool     Trade_Above_Cloud      = true;                 // Trade Above Cloud Only
input bool     TK_Cross_Signal        = true;                 // TK Cross Signal

//+------------------------------------------------------------------+
//| 15. ENTRY SIGNAL - PRICE ACTION                                   |
//+------------------------------------------------------------------+
input group "=== 15. Price Action Patterns ==="
input bool     Use_Candle_Patterns    = false;                // Enable Candle Patterns
input bool     PA_Engulfing           = true;                 // Engulfing Pattern
input bool     PA_Pin_Bar             = true;                 // Pin Bar
input bool     PA_Inside_Bar          = false;                // Inside Bar
input bool     PA_Doji                = false;                // Doji
input double   PA_Min_Body_Ratio      = 0.6;                  // Min Body/Range Ratio
input double   PA_Min_Wick_Ratio      = 0.3;                  // Min Wick Ratio
input int      PA_Lookback_Bars       = 3;                    // Lookback Bars

//+------------------------------------------------------------------+
//| 16. ENTRY SIGNAL - TICK / VOLUME                                  |
//+------------------------------------------------------------------+
input group "=== 16. Tick & Volume ==="
input bool     Use_Tick_Volume        = true;                 // Enable Volume Filter
input int      Volume_MA_Period       = 20;                   // Volume MA Period
input double   Volume_Multiplier      = 1.5;                  // Volume Multiplier
input bool     Use_Delta_Volume       = false;                // Delta Volume
input double   Delta_Threshold        = 100;                  // Delta Threshold
input bool     Volume_Spike_Filter    = true;                 // Spike Filter
input double   Spike_Volume_x         = 3.0;                  // Spike Volume Multiplier

//+------------------------------------------------------------------+
//| 17. ENTRY SIGNAL - SUPPORT & RESISTANCE                           |
//+------------------------------------------------------------------+
input group "=== 17. Support & Resistance ==="
input bool     Use_SR_Levels          = false;                // Enable S/R Levels
input int      SR_Lookback_Bars       = 100;                  // S/R Lookback Bars
input double   SR_Zone_Points         = 10;                   // S/R Zone Width (points)
input bool     Trade_SR_Bounce        = true;                 // Trade S/R Bounce
input bool     Trade_SR_Breakout      = false;                // Trade S/R Breakout
input int      SR_Touch_Count_Min     = 2;                    // Min Touch Count

//+------------------------------------------------------------------+
//| 18. ENTRY SIGNAL - SPREAD SCALPING (PURE HFT)                    |
//+------------------------------------------------------------------+
input group "=== 18. Spread Scalping (Pure HFT) ==="
input bool     Use_Spread_Scalp       = false;                // Enable Spread Scalp
input double   Spread_Entry_Threshold = 5;                    // Entry Spread Threshold
input double   Spread_Profit_Target   = 3;                    // Spread Profit Target
input int      Tick_Burst_Count       = 5;                    // Tick Burst Count
input int      Tick_Burst_MS          = 100;                  // Tick Burst Window (ms)

//+------------------------------------------------------------------+
//| 19. TIMEFRAME & SIGNAL SETTINGS                                   |
//+------------------------------------------------------------------+
input group "=== 19. Timeframe & Signal Settings ==="
input ENUM_TIMEFRAMES Signal_TF       = PERIOD_M1;            // Signal Timeframe
input ENUM_TIMEFRAMES Higher_TF       = PERIOD_M5;            // Higher TF Filter
input ENUM_TIMEFRAMES Confirm_TF      = PERIOD_M1;            // Confirmation TF
input bool     Use_Higher_TF_Filter   = true;                 // Enable Higher TF Filter
input bool     Wait_For_Bar_Close     = false;                // Wait for Bar Close
input int      Bars_To_Analyze        = 500;                  // Bars to Analyze
input int      Signal_Confirmation_Ticks = 3;                 // Confirmation Ticks

//+------------------------------------------------------------------+
//| 20. SESSION TIME FILTERS                                          |
//+------------------------------------------------------------------+
input group "=== 20. Session Time Filters ==="
input bool     Use_Time_Filter        = true;                 // Enable Time Filter
input string   Session1_Start         = "07:00";              // Session 1 Start (London)
input string   Session1_End           = "12:00";              // Session 1 End
input bool     Session1_Active        = true;                 // Session 1 Active
input string   Session2_Start         = "12:00";              // Session 2 Start (NY)
input string   Session2_End           = "17:00";              // Session 2 End
input bool     Session2_Active        = true;                 // Session 2 Active
input string   Session3_Start         = "00:00";              // Session 3 Start (Tokyo)
input string   Session3_End           = "06:00";              // Session 3 End
input bool     Session3_Active        = false;                // Session 3 Active
input bool     Use_GMT_Offset         = true;                 // Use GMT Offset
input int      GMT_Offset             = 3;                    // Broker GMT Offset
input bool     Auto_DST               = true;                 // Auto DST Adjust
input string   No_Trade_Start         = "23:45";              // No-Trade Start
input string   No_Trade_End           = "00:15";              // No-Trade End

//+------------------------------------------------------------------+
//| 21. DAY OF WEEK FILTERS                                           |
//+------------------------------------------------------------------+
input group "=== 21. Day of Week Filters ==="
input bool     Trade_Monday           = true;                 // Trade Monday
input bool     Trade_Tuesday          = true;                 // Trade Tuesday
input bool     Trade_Wednesday        = true;                 // Trade Wednesday
input bool     Trade_Thursday         = true;                 // Trade Thursday
input bool     Trade_Friday           = true;                 // Trade Friday
input bool     Trade_Saturday         = false;                // Trade Saturday
input bool     Trade_Sunday           = false;                // Trade Sunday
input string   Monday_Start           = "00:00";              // Monday Start Time
input string   Monday_End             = "23:59";              // Monday End Time
input string   Friday_Close_Time      = "20:00";              // Friday Close Time
input bool     Close_All_Friday       = true;                 // Close All on Friday

//+------------------------------------------------------------------+
//| 22. NEWS FILTER                                                   |
//+------------------------------------------------------------------+
input group "=== 22. News Filter ==="
input bool     Use_News_Filter        = true;                 // Enable News Filter
input int      News_Before_Minutes    = 30;                   // No Trade Before News (min)
input int      News_After_Minutes     = 30;                   // No Trade After News (min)
input bool     Filter_High_Impact     = true;                 // Filter High Impact
input bool     Filter_Medium_Impact   = false;                // Filter Medium Impact
input bool     Filter_Low_Impact      = false;                // Filter Low Impact
input string   News_Currencies        = "USD,EUR,GBP,JPY";   // News Currencies
input string   News_URL               = "https://nfs.faireconomy.media/ff_calendar_thisweek.xml"; // News URL
input bool     Close_On_News          = false;                // Close Positions on News

//+------------------------------------------------------------------+
//| 23. SPREAD CONTROL                                                |
//+------------------------------------------------------------------+
input group "=== 23. Spread Control ==="
input double   Max_Spread_Points      = 20;                   // Max Spread to Open
input double   Max_Spread_Close       = 30;                   // Max Spread to Close
input bool     Pause_On_High_Spread   = true;                 // Pause on High Spread
input double   Spread_Alert_Level     = 15;                   // Spread Alert Level
input bool     Use_Spread_Average     = false;                // Use Spread Average
input int      Spread_Average_Bars    = 20;                   // Spread Average Bars
input double   Spread_Avg_Multiplier  = 1.5;                  // Spread Avg Multiplier

//+------------------------------------------------------------------+
//| 24. EXECUTION SETTINGS                                            |
//+------------------------------------------------------------------+
input group "=== 24. Execution Settings ==="
input int      Slippage_Points        = 3;                    // Max Slippage (points)
input int      Max_Retry_Attempts     = 3;                    // Max Retry Attempts
input int      Retry_Delay_MS         = 200;                  // Retry Delay (ms)
input bool     Use_Market_Order       = true;                 // Use Market Orders
input bool     Use_Pending_Orders     = false;                // Use Pending Orders
input double   Pending_Offset_Points  = 5;                    // Pending Offset (points)
input int      Pending_Expiry_Bars    = 2;                    // Pending Expiry (bars)
input bool     Fill_Or_Kill           = false;                // Fill or Kill
input bool     Immediate_Or_Cancel    = false;                // Immediate or Cancel
input bool     Return_Order_On_Partial= true;                 // Return on Partial Fill
input bool     Async_Order_Send       = false;                // Async Order Send
input int      Max_Order_Wait_MS      = 3000;                 // Max Order Wait (ms)

//+------------------------------------------------------------------+
//| 25. RISK MANAGEMENT - PER TRADE                                   |
//+------------------------------------------------------------------+
input group "=== 25. Risk Per Trade ==="
input double   Max_Risk_Per_Trade_USD = 50.0;                 // Max Risk per Trade (USD)
input double   Max_Risk_Percent       = 2.0;                  // Max Risk (% equity)
input bool     Use_Kelly_Criterion    = false;                // Use Kelly Criterion
input double   Kelly_Fraction         = 0.25;                 // Fractional Kelly
input double   Win_Rate_Estimate      = 0.55;                 // Est. Win Rate
input double   RR_Ratio_Estimate      = 1.5;                  // Est. R:R Ratio

//+------------------------------------------------------------------+
//| 26. RISK MANAGEMENT - DAILY LIMITS                                |
//+------------------------------------------------------------------+
input group "=== 26. Daily Limits ==="
input double   Max_Daily_Loss_USD     = 200.0;                // Max Daily Loss (USD)
input double   Max_Daily_Loss_Percent = 5.0;                  // Max Daily Loss (%)
input double   Max_Daily_Profit_USD   = 500.0;                // Daily Profit Target (USD)
input double   Max_Daily_Profit_Pct   = 10.0;                 // Daily Profit Target (%)
input int      Max_Daily_Trades       = 50;                   // Max Daily Trades
input int      Max_Consecutive_Losses = 5;                    // Max Consecutive Losses
input int      Pause_After_Loss_Min   = 30;                   // Pause After Loss (min)
input bool     Reset_Daily_At         = true;                 // Reset Daily Stats
input string   Daily_Reset_Time       = "00:00";              // Daily Reset Time

//+------------------------------------------------------------------+
//| 27. RISK MANAGEMENT - DRAWDOWN PROTECTION                         |
//+------------------------------------------------------------------+
input group "=== 27. Drawdown Protection ==="
input double   Max_Drawdown_USD       = 500.0;                // Max Drawdown (USD)
input double   Max_Drawdown_Percent   = 10.0;                 // Max Drawdown (%)
input bool     Hard_Stop_On_DD        = true;                 // Hard Stop on Drawdown
input bool     Soft_Pause_On_DD       = false;                // Soft Pause on Drawdown
input int      DD_Pause_Hours         = 24;                   // DD Pause Duration (hours)
input double   Equity_Stop_USD        = 5000.0;               // Equity Floor (USD)
input bool     Close_All_On_DD        = true;                 // Close All on Max DD

//+------------------------------------------------------------------+
//| 28. POSITION & ORDER LIMITS                                       |
//+------------------------------------------------------------------+
input group "=== 28. Position & Order Limits ==="
input int      Max_Open_Positions     = 3;                    // Max Open Positions
input int      Max_Buy_Positions      = 2;                    // Max Buy Positions
input int      Max_Sell_Positions     = 2;                    // Max Sell Positions
input int      Max_Positions_Per_Symbol = 1;                  // Max Per Symbol
input bool     Allow_Hedge            = false;                // Allow Hedging
input bool     One_Trade_Per_Bar      = true;                 // One Trade Per Bar
input int      Min_Bars_Between_Trades= 1;                   // Min Bars Between Trades
input int      Min_Seconds_Between_Trades = 30;              // Min Seconds Between Trades
input bool     Only_One_Direction     = false;                // One Direction Only

//+------------------------------------------------------------------+
//| 29. MARTINGALE / ANTI-MARTINGALE                                  |
//+------------------------------------------------------------------+
input group "=== 29. Martingale (High Risk) ==="
input bool     Use_Martingale         = false;                // Enable Martingale
input double   Martingale_Multiplier  = 2.0;                  // Martingale Multiplier
input int      Max_Martingale_Steps   = 3;                    // Max Martingale Steps
input bool     Use_Anti_Martingale    = false;                // Enable Anti-Martingale
input double   Anti_Martin_Multiplier = 1.5;                  // Anti-Martingale Multiplier
input int      Max_Anti_Martin_Steps  = 4;                    // Max Anti-Martin Steps
input bool     Reset_After_Win        = true;                 // Reset After Win
input bool     Reset_After_Loss       = true;                 // Reset After Loss

//+------------------------------------------------------------------+
//| 30. GRID SETTINGS                                                 |
//+------------------------------------------------------------------+
input group "=== 30. Grid Settings ==="
input bool     Use_Grid               = false;                // Enable Grid Trading
input double   Grid_Step_Points       = 50;                   // Grid Step (points)
input int      Max_Grid_Orders        = 5;                    // Max Grid Orders
input double   Grid_Lot_Multiplier    = 1.0;                  // Grid Lot Multiplier
input bool     Grid_Close_All_On_TP   = true;                 // Close All on Grid TP
input double   Grid_Total_TP_Points   = 200;                  // Grid Total TP (points)
input bool     Grid_Hedged            = false;                // Hedged Grid

//+------------------------------------------------------------------+
//| 31. TRADE EXIT - ADDITIONAL CONDITIONS                            |
//+------------------------------------------------------------------+
input group "=== 31. Exit Conditions ==="
input bool     Close_On_Opposite_Signal = true;               // Close on Opposite Signal
input bool     Close_On_Time_Expiry   = true;                 // Close on Time Expiry
input int      Max_Trade_Duration_Min = 30;                   // Max Duration (minutes)
input int      Max_Trade_Duration_Sec = 0;                    // Max Duration (seconds)
input bool     Close_On_Candle_Close  = false;                // Close on Candle Close
input bool     Close_Profit_EOD       = true;                 // Close Profits at EOD
input bool     Close_All_EOD          = false;                // Close All at EOD
input string   EOD_Close_Time         = "22:00";              // EOD Close Time
input bool     Close_On_Spread_Spike  = true;                 // Close on Spread Spike
input double   Spread_Spike_Close_Pts = 25;                   // Spread Spike Close Level

//+------------------------------------------------------------------+
//| 32. ALERTS & NOTIFICATIONS                                        |
//+------------------------------------------------------------------+
input group "=== 32. Alerts & Notifications ==="
input bool     Alert_On_Signal        = true;                 // Alert on Signal
input bool     Alert_On_Open          = true;                 // Alert on Open
input bool     Alert_On_Close         = true;                 // Alert on Close
input bool     Alert_On_SL_Hit        = true;                 // Alert on SL Hit
input bool     Alert_On_TP_Hit        = true;                 // Alert on TP Hit
input bool     Alert_On_DD_Limit      = true;                 // Alert on DD Limit
input bool     Alert_On_Daily_Limit   = true;                 // Alert on Daily Limit
input bool     Push_Notification      = true;                 // Push Notifications
input bool     Email_Notification     = false;                // Email Notifications
input string   Email_Address          = "";                   // Email Address
input bool     Sound_Alert            = true;                 // Sound Alerts
input string   Alert_Sound_File       = "alert.wav";          // Sound File
input bool     MT5_Alert_Popup        = false;                // MT5 Popup Alert

//+------------------------------------------------------------------+
//| 33. DASHBOARD / HUD DISPLAY                                       |
//+------------------------------------------------------------------+
input group "=== 33. Dashboard / HUD ==="
input bool     Show_Dashboard         = true;                 // Show Dashboard
input int      Dashboard_X            = 10;                   // Dashboard X Position
input int      Dashboard_Y            = 30;                   // Dashboard Y Position
input color    Dashboard_BG_Color     = clrDarkSlateGray;     // Background Color
input color    Dashboard_Text_Color   = clrWhite;             // Text Color
input color    Profit_Color           = clrLime;              // Profit Color
input color    Loss_Color             = clrRed;               // Loss Color
input int      Dashboard_Font_Size    = 9;                    // Font Size
input string   Dashboard_Font         = "Consolas";           // Font Name
input bool     Show_Signal_Arrows     = true;                 // Show Signal Arrows
input bool     Show_SL_TP_Lines       = true;                 // Show SL/TP Lines
input bool     Show_Entry_Line        = true;                 // Show Entry Lines
input bool     Show_Trade_Stats       = true;                 // Show Trade Stats
input bool     Show_Spread_Live       = true;                 // Show Live Spread
input bool     Show_Session_Box       = true;                 // Show Session Boxes
input bool     Show_News_Lines        = false;                // Show News Lines
input bool     Show_Equity_Curve      = false;                // Show Equity Curve

//+------------------------------------------------------------------+
//| 34. LOGGING & DEBUGGING                                           |
//+------------------------------------------------------------------+
input group "=== 34. Logging & Debugging ==="
input bool     Enable_Logging         = true;                 // Enable Logging
input bool     Log_To_File            = false;                // Log to File
input string   Log_File_Name          = "HFT_Log.txt";        // Log File Name
input bool     Log_All_Ticks          = false;                // Log All Ticks
input bool     Log_Signals            = true;                 // Log Signals
input bool     Log_Orders             = true;                 // Log Orders
input bool     Log_Errors             = true;                 // Log Errors
input ENUM_LOG_LEVEL Log_Level        = LOG_DETAIL;           // Log Level
input bool     Print_To_Journal       = true;                 // Print to Journal

//+------------------------------------------------------------------+
//| 35. SYMBOL SETTINGS                                               |
//+------------------------------------------------------------------+
input group "=== 35. Symbol Settings ==="
input string   Trade_Symbol           = "";                   // Trade Symbol (blank=current)
input bool     Allow_All_Symbols      = false;                // Allow All Symbols
input string   Allowed_Symbols        = "EURUSD,GBPUSD,USDJPY,XAUUSD"; // Allowed Symbols
input double   Symbol_Point_Value     = 0;                    // Point Value (0=auto)
input int      Symbol_Digits          = 5;                    // Digits
input bool     Auto_Detect_Digits     = true;                 // Auto Detect Digits
input double   Contract_Size          = 100000;               // Contract Size
input double   Tick_Value             = 0;                    // Tick Value (0=auto)

//+------------------------------------------------------------------+
//| 36. OPTIMIZATION & BACKTESTING                                    |
//+------------------------------------------------------------------+
input group "=== 36. Optimization & Backtesting ==="
input bool     Optimization_Mode      = false;                // Optimization Mode
input bool     Use_Tick_Data          = true;                 // Use Tick Data
input bool     Simulate_Spread        = true;                 // Simulate Spread
input double   Test_Spread_Points     = 10;                   // Test Spread (points)
input bool     Use_Real_Spread        = false;                // Use Real Spread
input bool     Skip_Weekend_Gaps      = true;                 // Skip Weekend Gaps
input bool     Simulate_Slippage      = true;                 // Simulate Slippage
input int      Test_Slippage_Points   = 2;                    // Test Slippage (points)
input double   Commission_Per_Lot     = 3.5;                  // Commission per Lot
input double   Swap_Long              = -0.5;                 // Swap Long
input double   Swap_Short             = -0.3;                 // Swap Short

//+------------------------------------------------------------------+
//| 37. BROKER COMPATIBILITY                                          |
//+------------------------------------------------------------------+
input group "=== 37. Broker Compatibility ==="
input bool     ECN_Mode               = true;                 // ECN Mode
input bool     FIFO_Mode              = false;                // FIFO Mode (US)
input bool     Hedging_Account        = true;                 // Hedging Account
input bool     Micro_Lot_Support      = true;                 // Micro Lot Support
input ENUM_FILL_POLICY Order_Fill_Policy = FILL_IOC;          // Fill Policy
input int      Max_Order_Wait_MS_Broker= 3000;               // Max Order Wait (ms)

//+------------------------------------------------------------------+
//| 38. VPS & LATENCY SETTINGS                                        |
//+------------------------------------------------------------------+
input group "=== 38. VPS & Latency ==="
input bool     VPS_Mode               = false;                // VPS Mode
input int      Max_Ping_MS            = 50;                   // Max Ping (ms)
input bool     Check_Ping             = false;                // Check Ping
input int      Ping_Check_Interval    = 60;                   // Ping Check Interval (sec)
input bool     Reduce_CPU_Load        = false;                // Reduce CPU Load
input int      Sleep_Between_Ticks_MS = 0;                    // Sleep Between Ticks (ms)

//+------------------------------------------------------------------+
//| 39. ADX - TREND STRENGTH FILTER                                   |
//+------------------------------------------------------------------+
input group "=== 39. ADX Trend Strength ==="
input bool     Use_ADX_Filter         = true;                 // Enable ADX Filter
input int      ADX_Period             = 14;                   // ADX Period
input double   ADX_Min_Level          = 20.0;                 // ADX Min Level
input double   ADX_Max_Level          = 60.0;                 // ADX Max Level
input bool     ADX_Direction_Filter   = true;                 // ADX Direction Filter
input double   ADX_DI_Gap_Min         = 2.0;                  // Min DI Gap

//+------------------------------------------------------------------+
//| 40. PARABOLIC SAR                                                 |
//+------------------------------------------------------------------+
input group "=== 40. Parabolic SAR ==="
input bool     Use_PSAR_Filter        = false;                // Enable PSAR Filter
input double   PSAR_Step             = 0.02;                  // PSAR Step
input double   PSAR_Max              = 0.2;                   // PSAR Maximum
input bool     PSAR_Trend_Only       = true;                  // Trend Direction Only

//+------------------------------------------------------------------+
//| 41. SUPERTREND                                                    |
//+------------------------------------------------------------------+
input group "=== 41. Supertrend ==="
input bool     Use_Supertrend        = false;                 // Enable Supertrend
input int      ST_ATR_Period         = 10;                    // ST ATR Period
input double   ST_Multiplier         = 3.0;                   // ST Multiplier
input bool     ST_Trend_Filter       = true;                  // ST Trend Filter
input bool     ST_Signal_Entry       = false;                 // ST Signal Entry

//+------------------------------------------------------------------+
//| 42. WILLIAMS %R                                                   |
//+------------------------------------------------------------------+
input group "=== 42. Williams %R ==="
input bool     Use_WPR_Filter        = false;                 // Enable Williams %R
input int      WPR_Period            = 14;                    // WPR Period
input double   WPR_Overbought        = -20;                   // WPR Overbought
input double   WPR_Oversold          = -80;                   // WPR Oversold

//+------------------------------------------------------------------+
//| 43. DEMARKER                                                      |
//+------------------------------------------------------------------+
input group "=== 43. DeMarker ==="
input bool     Use_DeMarker          = false;                 // Enable DeMarker
input int      DeM_Period            = 14;                    // DeMarker Period
input double   DeM_Overbought        = 0.7;                   // DeMarker Overbought
input double   DeM_Oversold          = 0.3;                   // DeMarker Oversold

//+------------------------------------------------------------------+
//| 44. ENVELOPES                                                     |
//+------------------------------------------------------------------+
input group "=== 44. Envelopes ==="
input bool     Use_Envelopes         = false;                 // Enable Envelopes
input int      Env_Period            = 14;                    // Envelope Period
input double   Env_Deviation         = 0.1;                   // Envelope Deviation
input ENUM_MA_METHOD Env_MA_Method   = MODE_SMA;              // Envelope MA Method
input ENUM_APPLIED_PRICE Env_Price   = PRICE_CLOSE;           // Envelope Price

//+------------------------------------------------------------------+
//| 45. BEARS / BULLS POWER                                           |
//+------------------------------------------------------------------+
input group "=== 45. Bears / Bulls Power ==="
input bool     Use_Bears_Bulls       = false;                 // Enable Bears/Bulls
input int      BB_Power_Period       = 13;                    // Bears/Bulls Period
input double   Bulls_Min_Level       = 0.0;                   // Bulls Min Level
input double   Bears_Max_Level       = 0.0;                   // Bears Max Level

//+------------------------------------------------------------------+
//| 46. FRACTALS                                                      |
//+------------------------------------------------------------------+
input group "=== 46. Fractals ==="
input bool     Use_Fractals          = false;                 // Enable Fractals
input int      Fractals_Lookback     = 5;                     // Fractals Lookback
input bool     Trade_Fractal_Break   = false;                 // Fractal Breakout Trade
input bool     Use_Fractal_as_SL     = true;                  // Use Fractal as SL
input double   Fractal_SL_Buffer_Pts = 5;                     // Fractal SL Buffer

//+------------------------------------------------------------------+
//| 47. PIVOT POINTS                                                  |
//+------------------------------------------------------------------+
input group "=== 47. Pivot Points ==="
input bool     Use_Pivot_Points      = false;                 // Enable Pivot Points
input ENUM_PP_TYPE Pivot_Type        = PP_CLASSIC;            // Pivot Type
input ENUM_TIMEFRAMES Pivot_TF       = PERIOD_D1;             // Pivot Timeframe
input bool     Trade_PP_Bounce       = true;                  // PP Bounce Trade
input bool     Trade_PP_Breakout     = false;                 // PP Breakout Trade
input double   PP_Zone_Points        = 10;                    // PP Zone Width
input bool     Show_Pivot_Lines      = true;                  // Show Pivot Lines

//+------------------------------------------------------------------+
//| 48. FIBONACCI LEVELS                                              |
//+------------------------------------------------------------------+
input group "=== 48. Fibonacci Levels ==="
input bool     Use_Fibonacci         = false;                 // Enable Fibonacci
input int      Fib_Swing_Lookback    = 50;                    // Swing Lookback Bars
input double   Fib_38_Zone           = 5;                     // 38.2% Zone Width
input double   Fib_50_Zone           = 5;                     // 50% Zone Width
input double   Fib_61_Zone           = 5;                     // 61.8% Zone Width
input bool     Fib_Retracement_Entry = true;                  // Retracement Entry
input bool     Fib_Extension_TP      = true;                  // Extension as TP
input double   Fib_TP_Level          = 161.8;                 // Fibonacci TP Level

//+------------------------------------------------------------------+
//| 49. VWAP                                                          |
//+------------------------------------------------------------------+
input group "=== 49. VWAP ==="
input bool     Use_VWAP_Filter       = false;                 // Enable VWAP
input bool     Trade_Above_VWAP      = true;                  // Buy Above VWAP
input bool     Trade_Below_VWAP      = true;                  // Sell Below VWAP
input bool     VWAP_Bounce_Entry     = false;                 // VWAP Bounce Entry
input double   VWAP_Zone_Points      = 5;                     // VWAP Zone Width
input ENUM_TIMEFRAMES VWAP_Reset_TF  = PERIOD_D1;             // VWAP Reset TF

//+------------------------------------------------------------------+
//| 50. CANDLE SIZE FILTER                                            |
//+------------------------------------------------------------------+
input group "=== 50. Candle Size Filter ==="
input bool     Use_Candle_Filter     = true;                  // Enable Candle Filter
input double   Min_Candle_Body_Pts   = 3;                     // Min Body (points)
input double   Max_Candle_Body_Pts   = 100;                   // Max Body (points)
input double   Min_Candle_Range_Pts  = 5;                     // Min Range (points)
input double   Max_Candle_Range_Pts  = 200;                   // Max Range (points)
input double   Max_Upper_Wick_Ratio  = 0.6;                   // Max Upper Wick Ratio
input double   Max_Lower_Wick_Ratio  = 0.6;                   // Max Lower Wick Ratio
input bool     Ignore_Doji_Candles   = true;                  // Ignore Doji

//+------------------------------------------------------------------+
//| 51. PRICE GAP FILTER                                              |
//+------------------------------------------------------------------+
input group "=== 51. Price Gap Filter ==="
input bool     Use_Gap_Filter        = true;                  // Enable Gap Filter
input double   Max_Gap_Points        = 50;                    // Max Gap (points)
input bool     Skip_After_Gap        = true;                  // Skip After Gap
input int      Skip_Bars_After_Gap   = 3;                     // Skip Bars After Gap
input bool     Close_Into_Gap        = false;                 // Close Into Gap

//+------------------------------------------------------------------+
//| 52. PRICE SPIKE FILTER                                            |
//+------------------------------------------------------------------+
input group "=== 52. Price Spike Filter ==="
input bool     Use_Spike_Filter      = true;                  // Enable Spike Filter
input double   Spike_Points          = 100;                   // Spike Threshold (points)
input int      Spike_Cooldown_Bars   = 5;                     // Spike Cooldown Bars
input bool     Close_On_Spike        = false;                 // Close on Spike

//+------------------------------------------------------------------+
//| 53. SIGNAL SCORING SYSTEM                                         |
//+------------------------------------------------------------------+
input group "=== 53. Signal Scoring ==="
input bool     Use_Signal_Score      = false;                 // Enable Signal Scoring
input int      Min_Score_To_Trade    = 3;                     // Min Score to Trade
input int      MA_Score_Weight       = 1;                     // MA Weight
input int      RSI_Score_Weight      = 1;                     // RSI Weight
input int      MACD_Score_Weight     = 1;                     // MACD Weight
input int      BB_Score_Weight       = 1;                     // BB Weight
input int      ADX_Score_Weight      = 1;                     // ADX Weight
input int      Volume_Score_Weight   = 1;                     // Volume Weight
input int      PA_Score_Weight       = 2;                     // Price Action Weight

//+------------------------------------------------------------------+
//| 54. TRADE DIRECTION CONTROL                                       |
//+------------------------------------------------------------------+
input group "=== 54. Trade Direction ==="
input ENUM_TRADE_DIR Trade_Direction  = TRADE_BOTH;           // Trade Direction
input bool     Flip_Direction        = false;                 // Flip All Signals
input bool     One_Direction_Per_Session = false;             // One Direction Per Session
input bool     Allow_Buy_Monday      = true;                  // Allow Buy on Monday
input bool     Allow_Sell_Friday     = false;                 // Allow Sell on Friday

//+------------------------------------------------------------------+
//| 55. MULTI-TIMEFRAME CONFIRMATION                                  |
//+------------------------------------------------------------------+
input group "=== 55. Multi-Timeframe ==="
input bool     Require_MTF_Confirm   = true;                  // Require MTF Confirm
input ENUM_TIMEFRAMES MTF_TF1        = PERIOD_M5;             // MTF Timeframe 1
input ENUM_TIMEFRAMES MTF_TF2        = PERIOD_M15;            // MTF Timeframe 2
input ENUM_TIMEFRAMES MTF_TF3        = PERIOD_H1;             // MTF Timeframe 3
input bool     MTF_TF1_Active        = true;                  // MTF TF1 Active
input bool     MTF_TF2_Active        = false;                 // MTF TF2 Active
input bool     MTF_TF3_Active        = false;                 // MTF TF3 Active
input bool     MTF_All_Must_Agree    = false;                 // All Must Agree

//+------------------------------------------------------------------+
//| 56. PYRAMIDING / SCALING                                          |
//+------------------------------------------------------------------+
input group "=== 56. Pyramiding ==="
input bool     Use_Pyramid           = false;                 // Enable Pyramiding
input int      Max_Pyramid_Levels    = 3;                     // Max Pyramid Levels
input double   Pyramid_Trigger_Pts   = 20;                    // Pyramid Trigger (points)
input double   Pyramid_Lot_Ratio     = 0.5;                   // Pyramid Lot Ratio
input bool     Move_SL_On_Pyramid    = true;                  // Move SL on Pyramid
input double   Pyramid_SL_Points     = 10;                    // Pyramid SL (points)

//+------------------------------------------------------------------+
//| 57. AVERAGING DOWN                                                |
//+------------------------------------------------------------------+
input group "=== 57. Averaging Down ==="
input bool     Use_Average_Down      = false;                 // Enable Averaging
input int      Max_Average_Levels    = 3;                     // Max Average Levels
input double   Average_Step_Points   = 30;                    // Average Step (points)
input double   Average_Lot_Multiplier= 1.5;                   // Average Lot Multiplier
input double   Average_Total_TP_Pts  = 20;                    // Average TP (points)
input bool     Close_All_On_Average_TP = true;                // Close All on Avg TP

//+------------------------------------------------------------------+
//| 58. RECOVERY MODE                                                 |
//+------------------------------------------------------------------+
input group "=== 58. Recovery Mode ==="
input bool     Use_Recovery_Mode     = false;                 // Enable Recovery
input double   Recovery_Trigger_DD   = 5.0;                   // Recovery DD Trigger (%)
input double   Recovery_Lot_Multiplier = 1.5;                 // Recovery Lot Multiplier
input int      Max_Recovery_Steps    = 3;                     // Max Recovery Steps
input bool     Stricter_Filter_Recovery = true;               // Stricter Recovery Filters
input double   Recovery_End_Profit_Pct = 2.0;                 // Recovery End Profit (%)

//+------------------------------------------------------------------+
//| 59. EQUITY CURVE TRADING                                          |
//+------------------------------------------------------------------+
input group "=== 59. Equity Curve Trading ==="
input bool     Use_Equity_Curve      = false;                 // Enable Equity Curve
input int      EC_MA_Period          = 20;                    // Equity Curve MA Period
input bool     Pause_Below_EC_MA     = true;                  // Pause Below EC MA
input bool     Reduce_Lot_Below_EC   = false;                 // Reduce Lot Below EC
input double   EC_Reduced_Lot_Pct    = 50.0;                  // Reduced Lot (%)
input bool     Show_Equity_MA        = false;                 // Show Equity MA

//+------------------------------------------------------------------+
//| 60. PROFIT LOCK / PROTECTION                                      |
//+------------------------------------------------------------------+
input group "=== 60. Profit Lock ==="
input bool     Use_Profit_Lock       = false;                 // Enable Profit Lock
input double   Profit_Lock_Start_USD = 100.0;                 // Lock Activation (USD)
input double   Profit_Lock_Percent   = 50.0;                  // Lock Percentage
input bool     Reduce_Risk_In_Profit = false;                 // Reduce Risk in Profit
input double   Reduced_Risk_Pct      = 0.5;                   // Reduced Risk (%)
input bool     Stop_After_Daily_Target = true;                // Stop After Target

//+------------------------------------------------------------------+
//| 61. COMPOUND / REINVESTMENT                                       |
//+------------------------------------------------------------------+
input group "=== 61. Compound Mode ==="
input bool     Use_Compound_Mode     = true;                  // Enable Compounding
input bool     Use_Fixed_Balance     = false;                 // Use Fixed Balance
input double   Fixed_Balance_Amount  = 10000;                 // Fixed Balance Amount
input bool     Compound_Weekly       = false;                 // Compound Weekly
input bool     Compound_Monthly      = false;                 // Compound Monthly

//+------------------------------------------------------------------+
//| 62. WEEKEND / OVERNIGHT PROTECTION                                |
//+------------------------------------------------------------------+
input group "=== 62. Weekend/Overnight ==="
input bool     Close_Before_Weekend  = true;                  // Close Before Weekend
input string   Weekend_Close_Time    = "23:00";               // Weekend Close Time
input bool     Close_Before_Holidays = false;                 // Close Before Holidays
input bool     No_New_Trades_EOD     = true;                  // No New Trades EOD
input int      No_New_Trades_Min_EOD = 30;                    // No Trades Min Before EOD
input bool     Avoid_Swap_Time       = true;                  // Avoid Swap Time
input string   Swap_Time             = "23:55";               // Swap Time
input int      Swap_Avoid_Minutes    = 15;                    // Swap Avoid (minutes)

//+------------------------------------------------------------------+
//| 63. DEMO vs LIVE ACCOUNT                                          |
//+------------------------------------------------------------------+
input group "=== 63. Demo vs Live ==="
input bool     Trade_On_Demo         = true;                  // Trade on Demo
input bool     Trade_On_Live         = true;                  // Trade on Live
input double   Demo_Max_Lot          = 1.0;                   // Demo Max Lot
input bool     Warn_If_Demo          = true;                  // Warn if Demo
input bool     Different_Lot_Live    = false;                 // Different Lot for Live
input double   Live_Lot_Multiplier   = 1.0;                   // Live Lot Multiplier

//+------------------------------------------------------------------+
//| 64. MULTI-SYMBOL / BASKET                                         |
//+------------------------------------------------------------------+
input group "=== 64. Multi-Symbol / Basket ==="
input bool     Multi_Symbol_Mode     = false;                 // Enable Multi-Symbol
input string   Symbol_List           = "EURUSD,GBPUSD,USDJPY"; // Symbol List
input bool     Sync_Direction        = false;                 // Sync Direction
input int      Max_Total_Positions   = 5;                     // Max Total Positions
input double   Basket_TP_USD         = 100.0;                 // Basket TP (USD)
input double   Basket_SL_USD         = 50.0;                  // Basket SL (USD)
input bool     Correlate_Filter      = false;                 // Correlation Filter
input double   Max_Correlation       = 0.8;                   // Max Correlation

//+------------------------------------------------------------------+
//| 65. EXTERNAL SIGNAL INPUT                                         |
//+------------------------------------------------------------------+
input group "=== 65. External Signals ==="
input bool     Use_External_Signals  = false;                 // Enable External Signals
input string   Signal_File_Path      = "signals.csv";         // Signal File Path
input int      Signal_Read_Interval  = 1;                     // Read Interval (sec)
input bool     Use_Named_Pipe        = false;                 // Use Named Pipe
input string   Pipe_Name             = "\\\\.\\pipe\\HFT_Signal"; // Pipe Name
input bool     Use_Socket_Signal     = false;                 // Use Socket
input int      Socket_Port           = 9090;                  // Socket Port

//+------------------------------------------------------------------+
//| 66. TELEGRAM / WEBHOOK                                            |
//+------------------------------------------------------------------+
input group "=== 66. Telegram / Webhook ==="
input bool     Use_Telegram          = false;                 // Enable Telegram
input string   Telegram_Token        = "";                    // Telegram Bot Token
input string   Telegram_Chat_ID      = "";                    // Telegram Chat ID
input bool     Telegram_On_Open      = true;                  // Telegram on Open
input bool     Telegram_On_Close     = true;                  // Telegram on Close
input bool     Telegram_On_SL        = true;                  // Telegram on SL
input bool     Telegram_On_DD        = true;                  // Telegram on DD
input bool     Use_Webhook           = false;                 // Enable Webhook
input string   Webhook_URL           = "";                    // Webhook URL
input string   Webhook_Secret        = "";                    // Webhook Secret

//+------------------------------------------------------------------+
//| 67. CUSTOM INDICATOR SUPPORT                                      |
//+------------------------------------------------------------------+
input group "=== 67. Custom Indicators ==="
input bool     Use_Custom_Ind_1      = false;                 // Enable Custom Ind 1
input string   Custom_Ind_1_Name     = "";                    // Custom Ind 1 Name
input int      Custom_Ind_1_Buffer   = 0;                     // Custom Ind 1 Buffer
input double   Custom_Ind_1_Buy_Val  = 1.0;                   // Custom Ind 1 Buy Value
input double   Custom_Ind_1_Sell_Val = -1.0;                  // Custom Ind 1 Sell Value
input bool     Use_Custom_Ind_2      = false;                 // Enable Custom Ind 2
input string   Custom_Ind_2_Name     = "";                    // Custom Ind 2 Name
input int      Custom_Ind_2_Buffer   = 0;                     // Custom Ind 2 Buffer
input double   Custom_Ind_2_Buy_Val  = 1.0;                   // Custom Ind 2 Buy Value
input double   Custom_Ind_2_Sell_Val = -1.0;                  // Custom Ind 2 Sell Value

//+------------------------------------------------------------------+
//| 68. BROKER SYMBOL PREFIX / SUFFIX                                 |
//+------------------------------------------------------------------+
input group "=== 68. Symbol Prefix/Suffix ==="
input string   Symbol_Prefix         = "";                    // Symbol Prefix
input string   Symbol_Suffix         = "";                    // Symbol Suffix
input bool     Auto_Detect_Suffix    = true;                  // Auto Detect Suffix
input bool     Auto_Detect_Prefix    = true;                  // Auto Detect Prefix

//+------------------------------------------------------------------+
//| 69. STOP LEVEL & FREEZE LEVEL                                     |
//+------------------------------------------------------------------+
input group "=== 69. Stop/Freeze Level ==="
input bool     Auto_Adjust_For_StopLevel = true;              // Auto Adjust Stop Level
input int      StopLevel_Buffer_Pts  = 5;                     // Stop Level Buffer
input bool     Check_Freeze_Level    = true;                  // Check Freeze Level
input int      Freeze_Buffer_Pts     = 3;                     // Freeze Buffer

//+------------------------------------------------------------------+
//| 70. ORDER FLOW / DOM                                              |
//+------------------------------------------------------------------+
input group "=== 70. Order Flow / DOM ==="
input bool     Use_DOM_Filter        = false;                 // Enable DOM Filter
input double   DOM_Bid_Ask_Ratio_Min = 1.5;                   // Min Bid/Ask Ratio
input int      DOM_Depth_Levels      = 5;                     // DOM Depth Levels
input bool     DOM_Buy_On_Bid_Pressure = true;                // Buy on Bid Pressure
input double   DOM_Min_Volume        = 50;                    // DOM Min Volume

//+------------------------------------------------------------------+
//| 71. CONSECUTIVE WIN/LOSS MANAGEMENT                               |
//+------------------------------------------------------------------+
input group "=== 71. Win/Loss Streaks ==="
input int      Max_Consecutive_Wins  = 10;                    // Max Consecutive Wins
input bool     Reduce_After_Win_Streak = false;               // Reduce After Win Streak
input double   Win_Streak_Lot_Pct    = 80.0;                  // Win Streak Lot (%)
input int      Pause_After_X_Losses  = 3;                     // Pause After X Losses
input int      Loss_Pause_Minutes    = 60;                    // Loss Pause (minutes)
input bool     Reset_Streak_Daily    = true;                  // Reset Streak Daily

//+------------------------------------------------------------------+
//| 72. MINIMUM TRADE DURATION                                        |
//+------------------------------------------------------------------+
input group "=== 72. Min Trade Duration ==="
input int      Min_Trade_Duration_Sec = 0;                    // Min Duration (sec)
input bool     Block_Instant_Close   = false;                 // Block Instant Close
input int      Instant_Close_Block_Sec = 5;                   // Block Duration (sec)

//+------------------------------------------------------------------+
//| 73. MANUAL CONTROL PANEL                                          |
//+------------------------------------------------------------------+
input group "=== 73. Control Panel ==="
input bool     Show_Control_Panel    = true;                  // Show Control Panel
input bool     Show_Close_All_Button = true;                  // Close All Button
input bool     Show_Pause_Button     = true;                  // Pause Button
input bool     Show_Buy_Button       = false;                 // Buy Button
input bool     Show_Sell_Button      = false;                 // Sell Button
input bool     Show_Flat_Button      = true;                  // Flat Button
input bool     Show_Lot_Input        = false;                 // Lot Input
input int      Panel_X               = 10;                    // Panel X Position
input int      Panel_Y               = 200;                   // Panel Y Position

//+------------------------------------------------------------------+
//| 74. PERFORMANCE TRACKING                                          |
//+------------------------------------------------------------------+
input group "=== 74. Performance Display ==="
input bool     Show_Win_Rate         = true;                  // Show Win Rate
input bool     Show_Profit_Factor    = true;                  // Show Profit Factor
input bool     Show_Sharpe_Ratio     = false;                 // Show Sharpe Ratio
input bool     Show_Avg_Win_Loss     = true;                  // Show Avg Win/Loss
input bool     Show_Max_DD_Live      = true;                  // Show Max DD Live
input bool     Show_RR_Ratio         = true;                  // Show R:R Ratio
input bool     Show_Total_Trades     = true;                  // Show Total Trades
input bool     Show_Commission_Paid  = true;                  // Show Commission
input bool     Show_Swap_Paid        = true;                  // Show Swap

//+------------------------------------------------------------------+
//| 75. VOLATILITY REGIME SWITCHING                                   |
//+------------------------------------------------------------------+
input group "=== 75. Volatility Regime ==="
input bool     Use_Volatility_Regime = false;                 // Enable Vol Regime
input double   Low_Vol_ATR_Level     = 0.0003;                // Low Vol ATR Level
input double   High_Vol_ATR_Level    = 0.0015;                // High Vol ATR Level
input double   Low_Vol_Lot_Multiplier= 0.5;                   // Low Vol Lot Multiplier
input double   High_Vol_Lot_Multiplier = 1.5;                 // High Vol Lot Multiplier
input double   Low_Vol_TP_Multiplier = 0.7;                   // Low Vol TP Multiplier
input double   High_Vol_TP_Multiplier = 1.5;                  // High Vol TP Multiplier

//+------------------------------------------------------------------+
//| 76. RE-ENTRY LOGIC                                                |
//+------------------------------------------------------------------+
input group "=== 76. Re-Entry Logic ==="
input bool     Allow_Reentry         = false;                 // Allow Re-Entry
input int      Min_Bars_Before_Reentry = 2;                   // Min Bars Before Re-Entry
input bool     Reentry_Same_Direction = true;                 // Same Direction Only
input bool     Reentry_Only_After_BE  = false;                // Only After Break-Even
input int      Max_Reentries_Per_Day  = 3;                    // Max Re-Entries/Day
input double   Reentry_Lot_Multiplier = 1.0;                  // Re-Entry Lot Multiplier

//+------------------------------------------------------------------+
//| 77. MARKET TYPE DETECTION                                         |
//+------------------------------------------------------------------+
input group "=== 77. Market Type Detection ==="
input bool     Use_Market_Type       = false;                 // Enable Market Type
input bool     Trade_Trending_Market = true;                  // Trade Trending Market
input bool     Trade_Ranging_Market  = false;                 // Trade Ranging Market
input double   Range_ADX_Max         = 20;                    // Range ADX Max
input double   Trend_ADX_Min         = 25;                    // Trend ADX Min
input int      Market_Type_Lookback  = 20;                    // Market Type Lookback

//+------------------------------------------------------------------+
//| 78. SESSION LOT SCALING                                           |
//+------------------------------------------------------------------+
input group "=== 78. Session Lot Scaling ==="
input bool     Use_Session_Lot_Scale = false;                 // Enable Session Lot Scale
input double   Tokyo_Lot_Multiplier  = 0.5;                   // Tokyo Lot Multiplier
input double   London_Lot_Multiplier = 1.0;                   // London Lot Multiplier
input double   NY_Lot_Multiplier     = 1.0;                   // NY Lot Multiplier
input double   Overlap_Lot_Multiplier= 1.5;                   // Overlap Lot Multiplier

//+------------------------------------------------------------------+
//| 79. SPREAD COST AWARENESS                                         |
//+------------------------------------------------------------------+
input group "=== 79. Spread Cost Awareness ==="
input bool     Include_Spread_In_RR  = true;                  // Include Spread in R:R
input bool     Skip_If_Spread_Kills_RR = true;                // Skip if Spread Kills R:R
input double   Min_Net_RR_After_Spread = 1.0;                 // Min Net R:R
input bool     Show_Effective_RR     = true;                  // Show Effective R:R
input bool     Factor_Commission     = true;                  // Factor Commission
input double   Commission_Per_Lot_RT = 7.0;                   // Round-Turn Commission

//+------------------------------------------------------------------+
//| 80. CONNECTION & PLATFORM MONITORING                              |
//+------------------------------------------------------------------+
input group "=== 80. Connection Monitor ==="
input bool     Monitor_Connection    = true;                  // Monitor Connection
input int      Reconnect_Wait_Sec    = 30;                    // Reconnect Wait (sec)
input bool     Close_On_Disconnect   = false;                 // Close on Disconnect
input bool     Pause_On_Disconnect   = true;                  // Pause on Disconnect
input bool     Alert_On_Disconnect   = true;                  // Alert on Disconnect
input int      Max_No_Tick_Seconds   = 30;                    // Max No-Tick (sec)
input bool     Restart_On_No_Tick    = false;                 // Restart on No Tick

//+------------------------------------------------------------------+
//| 81. CHART VISUAL SETTINGS                                         |
//+------------------------------------------------------------------+
input group "=== 81. Chart Visuals ==="
input color    Buy_Arrow_Color       = clrDodgerBlue;         // Buy Arrow Color
input color    Sell_Arrow_Color      = clrOrangeRed;          // Sell Arrow Color
input int      Arrow_Size            = 2;                     // Arrow Size
input color    SL_Line_Color         = clrRed;                // SL Line Color
input color    TP_Line_Color         = clrLime;               // TP Line Color
input color    Entry_Line_Color      = clrYellow;             // Entry Line Color
input int      Line_Width            = 1;                     // Line Width
input ENUM_LINE_STYLE Line_Style     = STYLE_DASH;            // Line Style
input color    Session_Box_Color     = clrNavy;               // Session Box Color
input int      Session_Box_Opacity   = 30;                    // Session Box Opacity
input bool     Delete_Objects_On_Remove = true;               // Delete Objects on Remove

//+------------------------------------------------------------------+
//| 82. OPTIMIZATION FILTERS                                          |
//+------------------------------------------------------------------+
input group "=== 82. Optimization Filters ==="
input bool     Opt_Skip_Low_Trades   = true;                  // Skip Low Trade Count
input int      Opt_Min_Trades        = 30;                    // Min Trades
input bool     Opt_Min_PF            = true;                  // Min Profit Factor
input double   Opt_Min_Profit_Factor = 1.3;                   // Min PF Value
input bool     Opt_Max_DD_Filter     = true;                  // Max DD Filter
input double   Opt_Max_DD_Pct        = 20.0;                  // Max DD (%)
input bool     Opt_Min_Win_Rate      = false;                 // Min Win Rate Filter
input double   Opt_Min_Win_Rate_Pct  = 45.0;                  // Min Win Rate (%)
input ENUM_OPT_CRITERION Opt_Custom_Criterion = OPT_BALANCE;  // Optimization Criterion

//+------------------------------------------------------------------+
//| 83. GLOBAL KILL SWITCH                                            |
//+------------------------------------------------------------------+
input group "=== 83. Global Kill Switch ==="
input bool     EA_Active             = true;                  // EA Active (Master Switch)
input bool     Close_All_On_Disable  = true;                  // Close All on Disable
input bool     Stealth_Mode          = false;                 // Stealth Mode (No Objects)
input bool     Allow_Manual_Trades   = true;                  // Allow Manual Trades
input bool     Manage_Manual_Trades  = false;                 // Manage Manual Trades
input long     Manual_Magic_Number   = 0;                     // Manual Trade Magic

//+------------------------------------------------------------------+
//| 84. ACCOUNT PROTECTION - FINAL LAYER                              |
//+------------------------------------------------------------------+
input group "=== 84. Account Protection ==="
input double   Absolute_Min_Equity   = 1000.0;                // Absolute Min Equity (USD)
input double   Max_Margin_Level_Pct  = 500.0;                 // Max Margin Level (%)
input double   Min_Free_Margin_USD   = 200.0;                 // Min Free Margin (USD)
input bool     Check_Margin_Before_Order = true;              // Check Margin Before Order
input double   Required_Margin_Buffer= 1.5;                   // Margin Buffer Multiplier


// ==================================================================
// SOURCE: Utils.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                                      Utils.mqh   |
//|                      HFT Scalper Pro - Utility Functions           |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| CUtils - Utility helper class                                     |
//+------------------------------------------------------------------+
class CUtils
{
private:
   CSymbolInfo       m_symbol;
   CAccountInfo      m_account;
   string            m_tradeSymbol;
   double            m_pipValue;
   double            m_pointMultiplier;
   int               m_pipDigits;
   int               m_fileHandle;
   datetime          m_lastTickTime;

public:
                     CUtils();
                    ~CUtils();

   // Initialization
   bool              Init(string symbol = "");
   string            GetTradeSymbol() { return m_tradeSymbol; }

   // Pip/Point calculations
   double            PipValue()       { return m_pipValue; }
   double            PointMultiplier(){ return m_pointMultiplier; }
   int               PipDigits()     { return m_pipDigits; }
   double            PointsToPrice(double points);
   double            PriceToPoints(double price);
   double            PipsToPriceDistance(double pips);

   // Lot calculations
   double            NormalizeLots(double lots);
   double            CalculateLotSize(double slPoints);
   double            GetKellyLot(double slPoints);
   double            ApplySessionLotScale(double lots);
   double            ApplyVolatilityRegimeLot(double lots);

   // Price normalization
   double            NormalizePrice(double price);
   double            GetAsk();
   double            GetBid();
   double            GetSpread();
   double            GetSpreadPoints();

   // Symbol info accessors
   double            TickValue()     { m_symbol.RefreshRates(); return m_symbol.TickValue(); }
   double            TickSize()      { m_symbol.RefreshRates(); return m_symbol.TickSize(); }
   int               Digits()        { return m_symbol.Digits(); }
   double            Point()         { return m_symbol.Point(); }
   double            LotsMin()       { return m_symbol.LotsMin(); }
   double            LotsMax()       { return m_symbol.LotsMax(); }
   double            LotsStep()      { return m_symbol.LotsStep(); }
   long              StopLevel()     { return m_symbol.StopsLevel(); }
   long              FreezeLevel()   { return m_symbol.FreezeLevel(); }

   // Account info
   double            Balance()       { return m_account.Balance(); }
   double            Equity()        { return m_account.Equity(); }
   double            FreeMargin()    { return m_account.FreeMargin(); }
   double            MarginLevel()   { return (m_account.Margin() > 0) ? (m_account.Equity() / m_account.Margin() * 100.0) : 0; }
   bool              IsDemo()        { return (m_account.TradeMode() == ACCOUNT_TRADE_MODE_DEMO); }
   bool              IsHedging()     { return (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; }

   // Time utilities
   bool              IsNewBar(ENUM_TIMEFRAMES tf);
   int               GetServerHour();
   int               GetServerMinute();
   int               GetAdjustedHour();
   int               GetDayOfWeek();
   bool              ParseTimeString(string timeStr, int &hour, int &minute);
   bool              IsTimeBetween(string startTime, string endTime);
   datetime          GetDayStart();

   // Stop level / Freeze level validation
   double            ValidateSL(double entryPrice, double sl, bool isBuy);
   double            ValidateTP(double entryPrice, double tp, bool isBuy);

   // Logging
   void              Log(string message, ENUM_LOG_LEVEL level = LOG_BASIC);
   void              LogToFile(string message);
   void              InitFileLog();
   void              CloseFileLog();

   // Alerts
   void              SendAlert(string message);
   void              SendPushNotification(string message);
   void              SendEmailAlert(string subject, string body);
   void              PlaySound(string soundFile);

   // Tick monitoring
   void              UpdateTickTime() { m_lastTickTime = TimeCurrent(); }
   bool              IsTickTimeout();

   // License / Protection
   bool              CheckLicense();
   bool              CheckAccountLicense();
   bool              CheckBrokerAllowed();
   bool              CheckExpiry();
   bool              CheckVPSMode();

   // Candle utilities
   double            CandleBody(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double            CandleRange(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double            UpperWick(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double            LowerWick(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool              IsBullish(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);

   // Gap detection
   bool              HasGap(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   double            GapSize(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);

   // Spike detection
   bool              IsPriceSpike();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CUtils::CUtils()
{
   m_tradeSymbol = "";
   m_pipValue = 0;
   m_pointMultiplier = 1;
   m_pipDigits = 0;
   m_fileHandle = INVALID_HANDLE;
   m_lastTickTime = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CUtils::~CUtils()
{
   CloseFileLog();
}

//+------------------------------------------------------------------+
//| Initialize utility class                                          |
//+------------------------------------------------------------------+
bool CUtils::Init(string symbol = "")
{
   // Determine trade symbol
   if(symbol != "")
      m_tradeSymbol = symbol;
   else if(Trade_Symbol != "")
      m_tradeSymbol = Trade_Symbol;
   else
      m_tradeSymbol = _Symbol;

   // Apply prefix/suffix
   if(Symbol_Prefix != "" && !Auto_Detect_Prefix)
      m_tradeSymbol = Symbol_Prefix + m_tradeSymbol;
   if(Symbol_Suffix != "" && !Auto_Detect_Suffix)
      m_tradeSymbol = m_tradeSymbol + Symbol_Suffix;

   if(!m_symbol.Name(m_tradeSymbol))
   {
      Print("ERROR: Failed to initialize symbol: ", m_tradeSymbol);
      return false;
   }
   m_symbol.Refresh();

   // Calculate pip values
   int digits = m_symbol.Digits();
   if(Auto_Detect_Digits)
   {
      m_pipDigits = (digits == 3 || digits == 5) ? 1 : 0;
   }
   else
   {
      m_pipDigits = (Symbol_Digits == 5 || Symbol_Digits == 3) ? 1 : 0;
   }

   m_pointMultiplier = m_pipDigits ? 10.0 : 1.0;
   m_pipValue = m_symbol.Point() * m_pointMultiplier;

   // Init file logging
   if(Log_To_File)
      InitFileLog();

   m_lastTickTime = TimeCurrent();

   Log("Utils initialized: Symbol=" + m_tradeSymbol +
       " Digits=" + IntegerToString(digits) +
       " PipValue=" + DoubleToString(m_pipValue, digits),
       LOG_DETAIL);

   return true;
}

//+------------------------------------------------------------------+
//| Convert points to price distance                                  |
//+------------------------------------------------------------------+
double CUtils::PointsToPrice(double points)
{
   return points * m_symbol.Point();
}

//+------------------------------------------------------------------+
//| Convert price distance to points                                  |
//+------------------------------------------------------------------+
double CUtils::PriceToPoints(double price)
{
   if(m_symbol.Point() == 0) return 0;
   return price / m_symbol.Point();
}

//+------------------------------------------------------------------+
//| Convert pips to price distance                                    |
//+------------------------------------------------------------------+
double CUtils::PipsToPriceDistance(double pips)
{
   return pips * m_pipValue;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                                |
//+------------------------------------------------------------------+
double CUtils::NormalizeLots(double lots)
{
   double minLot  = m_symbol.LotsMin();
   double maxLot  = m_symbol.LotsMax();
   double lotStep = m_symbol.LotsStep();

   if(lotStep == 0) lotStep = 0.01;

   if(Round_Lot_Down)
      lots = MathFloor(lots / lotStep) * lotStep;
   else
      lots = MathRound(lots / lotStep) * lotStep;

   lots = MathMax(lots, minLot);
   lots = MathMin(lots, Max_Lot);
   lots = MathMin(lots, maxLot);

   // Demo lot limit
   if(IsDemo() && Demo_Max_Lot > 0)
      lots = MathMin(lots, Demo_Max_Lot);

   // Live lot multiplier
   if(!IsDemo() && Different_Lot_Live)
      lots *= Live_Lot_Multiplier;

   return NormalizeDouble(lots, Decimal_Lots);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CUtils::CalculateLotSize(double slPoints)
{
   double lots = Fixed_Lot;

   switch(Lot_Mode)
   {
      case LOT_FIXED:
         lots = Fixed_Lot;
         break;

      case LOT_PERCENT_EQUITY:
      {
         double riskAmount = m_account.Equity() * Risk_Percent / 100.0;
         double tickVal = m_symbol.TickValue();
         double tickSize = m_symbol.TickSize();
         if(tickVal > 0 && tickSize > 0 && slPoints > 0)
            lots = (riskAmount * tickSize) / (slPoints * m_symbol.Point() * tickVal / tickSize);
         else
            lots = Fixed_Lot;
         break;
      }

      case LOT_PERCENT_BALANCE:
      {
         double riskAmount = m_account.Balance() * Risk_Percent / 100.0;
         double tickVal = m_symbol.TickValue();
         double tickSize = m_symbol.TickSize();
         if(tickVal > 0 && tickSize > 0 && slPoints > 0)
            lots = (riskAmount * tickSize) / (slPoints * m_symbol.Point() * tickVal / tickSize);
         else
            lots = Fixed_Lot;
         break;
      }

      case LOT_PERCENT_MARGIN:
      {
         double freeMargin = m_account.FreeMargin();
         lots = (freeMargin * Risk_Percent / 100.0) / (m_symbol.Ask() * Contract_Size / 100.0);
         break;
      }

      case LOT_FIXED_MARGIN:
      {
         double marginRequired = 0;
         if(OrderCalcMargin(ORDER_TYPE_BUY, m_tradeSymbol, 1.0, m_symbol.Ask(), marginRequired) && marginRequired > 0)
            lots = Fixed_Margin_Amount / marginRequired;
         else
            lots = Fixed_Lot;
         break;
      }
   }

   // Apply Kelly Criterion if enabled
   if(Use_Kelly_Criterion)
      lots = GetKellyLot(slPoints);

   // Cap risk per trade
   if(Max_Risk_Per_Trade_USD > 0)
   {
      double tickVal = m_symbol.TickValue();
      double tickSize = m_symbol.TickSize();
      if(tickVal > 0 && tickSize > 0 && slPoints > 0)
      {
         double maxLots = (Max_Risk_Per_Trade_USD * tickSize) / (slPoints * m_symbol.Point() * tickVal / tickSize);
         lots = MathMin(lots, maxLots);
      }
   }

   // Apply session lot scaling
   if(Use_Session_Lot_Scale)
      lots = ApplySessionLotScale(lots);

   // Apply volatility regime
   if(Use_Volatility_Regime)
      lots = ApplyVolatilityRegimeLot(lots);

   return NormalizeLots(lots);
}

//+------------------------------------------------------------------+
//| Kelly Criterion lot calculation                                   |
//+------------------------------------------------------------------+
double CUtils::GetKellyLot(double slPoints)
{
   double W = Win_Rate_Estimate;
   double R = RR_Ratio_Estimate;

   double kelly = W - ((1.0 - W) / R);
   kelly = MathMax(kelly, 0.0);
   kelly *= Kelly_Fraction; // Fractional Kelly

   double riskAmount = m_account.Equity() * kelly;
   double tickVal = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();

   if(tickVal > 0 && tickSize > 0 && slPoints > 0)
      return (riskAmount * tickSize) / (slPoints * m_symbol.Point() * tickVal / tickSize);

   return Fixed_Lot;
}

//+------------------------------------------------------------------+
//| Apply session-based lot scaling                                   |
//+------------------------------------------------------------------+
double CUtils::ApplySessionLotScale(double lots)
{
   int hour = GetAdjustedHour();

   // Tokyo: 00:00-06:00
   if(hour >= 0 && hour < 6)
      return lots * Tokyo_Lot_Multiplier;
   // London: 07:00-12:00
   else if(hour >= 7 && hour < 12)
      return lots * London_Lot_Multiplier;
   // Overlap: 12:00-17:00
   else if(hour >= 12 && hour < 17)
      return lots * Overlap_Lot_Multiplier;
   // NY: 17:00-22:00
   else if(hour >= 17 && hour < 22)
      return lots * NY_Lot_Multiplier;

   return lots;
}

//+------------------------------------------------------------------+
//| Apply volatility regime lot scaling                               |
//+------------------------------------------------------------------+
double CUtils::ApplyVolatilityRegimeLot(double lots)
{
   int handle = iATR(m_tradeSymbol, ATR_Timeframe, ATR_Filter_Period);
   if(handle == INVALID_HANDLE) return lots;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handle, 0, 0, 1, atr) < 1)
   {
      IndicatorRelease(handle);
      return lots;
   }
   IndicatorRelease(handle);

   if(atr[0] <= Low_Vol_ATR_Level)
      return lots * Low_Vol_Lot_Multiplier;
   else if(atr[0] >= High_Vol_ATR_Level)
      return lots * High_Vol_Lot_Multiplier;

   return lots;
}

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                  |
//+------------------------------------------------------------------+
double CUtils::NormalizePrice(double price)
{
   return NormalizeDouble(price, m_symbol.Digits());
}

//+------------------------------------------------------------------+
//| Get Ask price                                                     |
//+------------------------------------------------------------------+
double CUtils::GetAsk()
{
   m_symbol.RefreshRates();
   return m_symbol.Ask();
}

//+------------------------------------------------------------------+
//| Get Bid price                                                     |
//+------------------------------------------------------------------+
double CUtils::GetBid()
{
   m_symbol.RefreshRates();
   return m_symbol.Bid();
}

//+------------------------------------------------------------------+
//| Get current spread                                                |
//+------------------------------------------------------------------+
double CUtils::GetSpread()
{
   m_symbol.RefreshRates();
   return m_symbol.Ask() - m_symbol.Bid();
}

//+------------------------------------------------------------------+
//| Get spread in points                                              |
//+------------------------------------------------------------------+
double CUtils::GetSpreadPoints()
{
   return PriceToPoints(GetSpread());
}

//+------------------------------------------------------------------+
//| Check for new bar on given timeframe                              |
//+------------------------------------------------------------------+
bool CUtils::IsNewBar(ENUM_TIMEFRAMES tf)
{
   static datetime lastBarTimes[];
   static ENUM_TIMEFRAMES trackedTFs[];
   static int tfCount = 0;

   // Find or add timeframe
   int idx = -1;
   for(int i = 0; i < tfCount; i++)
   {
      if(trackedTFs[i] == tf) { idx = i; break; }
   }

   if(idx == -1)
   {
      tfCount++;
      ArrayResize(trackedTFs, tfCount);
      ArrayResize(lastBarTimes, tfCount);
      idx = tfCount - 1;
      trackedTFs[idx] = tf;
      lastBarTimes[idx] = 0;
   }

   datetime current = iTime(m_tradeSymbol, tf, 0);
   if(current != lastBarTimes[idx])
   {
      lastBarTimes[idx] = current;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get server hour                                                   |
//+------------------------------------------------------------------+
int CUtils::GetServerHour()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return dt.hour;
}

//+------------------------------------------------------------------+
//| Get server minute                                                 |
//+------------------------------------------------------------------+
int CUtils::GetServerMinute()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return dt.min;
}

//+------------------------------------------------------------------+
//| Get GMT-adjusted hour                                             |
//+------------------------------------------------------------------+
int CUtils::GetAdjustedHour()
{
   int hour = GetServerHour();
   if(Use_GMT_Offset)
      hour = (hour - GMT_Offset + 24) % 24;
   return hour;
}

//+------------------------------------------------------------------+
//| Get day of week (0=Sunday)                                        |
//+------------------------------------------------------------------+
int CUtils::GetDayOfWeek()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return dt.day_of_week;
}

//+------------------------------------------------------------------+
//| Parse time string "HH:MM" into hour and minute                    |
//+------------------------------------------------------------------+
bool CUtils::ParseTimeString(string timeStr, int &hour, int &minute)
{
   string parts[];
   int count = StringSplit(timeStr, ':', parts);
   if(count != 2) return false;

   hour = (int)StringToInteger(parts[0]);
   minute = (int)StringToInteger(parts[1]);
   return (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
}

//+------------------------------------------------------------------+
//| Check if current time is between start and end                    |
//+------------------------------------------------------------------+
bool CUtils::IsTimeBetween(string startTime, string endTime)
{
   int startH, startM, endH, endM;
   if(!ParseTimeString(startTime, startH, startM)) return false;
   if(!ParseTimeString(endTime, endH, endM)) return false;

   int hour = GetAdjustedHour();
   int minute = GetServerMinute();
   int currentMinutes = hour * 60 + minute;
   int startMinutes = startH * 60 + startM;
   int endMinutes = endH * 60 + endM;

   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   else // Wraps midnight
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
}

//+------------------------------------------------------------------+
//| Get start of current day                                          |
//+------------------------------------------------------------------+
datetime CUtils::GetDayStart()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Validate SL against broker stop levels                            |
//+------------------------------------------------------------------+
double CUtils::ValidateSL(double entryPrice, double sl, bool isBuy)
{
   if(!Auto_Adjust_For_StopLevel) return NormalizePrice(sl);

   long stopLevel = m_symbol.StopsLevel();
   double minDistance = (stopLevel + StopLevel_Buffer_Pts) * m_symbol.Point();

   if(isBuy)
   {
      double maxSL = entryPrice - minDistance;
      if(sl > maxSL) sl = maxSL;
   }
   else
   {
      double minSL = entryPrice + minDistance;
      if(sl < minSL) sl = minSL;
   }

   return NormalizePrice(sl);
}

//+------------------------------------------------------------------+
//| Validate TP against broker stop levels                            |
//+------------------------------------------------------------------+
double CUtils::ValidateTP(double entryPrice, double tp, bool isBuy)
{
   if(!Auto_Adjust_For_StopLevel) return NormalizePrice(tp);

   long stopLevel = m_symbol.StopsLevel();
   double minDistance = (stopLevel + StopLevel_Buffer_Pts) * m_symbol.Point();

   if(isBuy)
   {
      double minTP = entryPrice + minDistance;
      if(tp < minTP) tp = minTP;
   }
   else
   {
      double maxTP = entryPrice - minDistance;
      if(tp > maxTP) tp = maxTP;
   }

   return NormalizePrice(tp);
}

//+------------------------------------------------------------------+
//| Log message                                                       |
//+------------------------------------------------------------------+
void CUtils::Log(string message, ENUM_LOG_LEVEL level = LOG_BASIC)
{
   if(!Enable_Logging) return;
   if((int)level > (int)Log_Level) return;

   string prefix = "[HFT] ";
   string fullMsg = prefix + message;

   if(Print_To_Journal)
      Print(fullMsg);

   if(Log_To_File)
      LogToFile(fullMsg);
}

//+------------------------------------------------------------------+
//| Log to file                                                       |
//+------------------------------------------------------------------+
void CUtils::LogToFile(string message)
{
   if(m_fileHandle == INVALID_HANDLE) return;

   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   FileWriteString(m_fileHandle, timestamp + " | " + message + "\n");
   FileFlush(m_fileHandle);
}

//+------------------------------------------------------------------+
//| Initialize file logging                                           |
//+------------------------------------------------------------------+
void CUtils::InitFileLog()
{
   if(m_fileHandle != INVALID_HANDLE) return;

   m_fileHandle = FileOpen(Log_File_Name, FILE_WRITE | FILE_TXT | FILE_SHARE_READ);
   if(m_fileHandle == INVALID_HANDLE)
      Print("WARNING: Failed to open log file: ", Log_File_Name);
}

//+------------------------------------------------------------------+
//| Close file log                                                    |
//+------------------------------------------------------------------+
void CUtils::CloseFileLog()
{
   if(m_fileHandle != INVALID_HANDLE)
   {
      FileClose(m_fileHandle);
      m_fileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Send alert                                                        |
//+------------------------------------------------------------------+
void CUtils::SendAlert(string message)
{
   if(MT5_Alert_Popup)
      Alert(message);

   if(Push_Notification)
      SendPushNotification(message);

   if(Email_Notification && Email_Address != "")
      SendEmailAlert("HFT Scalper Alert", message);

   if(Sound_Alert)
      PlaySound(Alert_Sound_File);
}

//+------------------------------------------------------------------+
//| Send push notification                                            |
//+------------------------------------------------------------------+
void CUtils::SendPushNotification(string message)
{
   if(!Push_Notification) return;
   SendNotification(message);
}

//+------------------------------------------------------------------+
//| Send email alert                                                  |
//+------------------------------------------------------------------+
void CUtils::SendEmailAlert(string subject, string body)
{
   if(!Email_Notification) return;
   SendMail(subject, body);
}

//+------------------------------------------------------------------+
//| Play sound                                                        |
//+------------------------------------------------------------------+
void CUtils::PlaySound(string soundFile)
{
   if(!Sound_Alert) return;
   PlaySound(soundFile);
}

//+------------------------------------------------------------------+
//| Check tick timeout                                                |
//+------------------------------------------------------------------+
bool CUtils::IsTickTimeout()
{
   if(!Monitor_Connection) return false;
   if(Max_No_Tick_Seconds <= 0) return false;

   return ((TimeCurrent() - m_lastTickTime) > Max_No_Tick_Seconds);
}

//+------------------------------------------------------------------+
//| Check license validity                                            |
//+------------------------------------------------------------------+
bool CUtils::CheckLicense()
{
   if(!CheckAccountLicense()) return false;
   if(!CheckBrokerAllowed()) return false;
   if(!CheckExpiry()) return false;
   if(!CheckVPSMode()) return false;

   // Demo/Live check
   if(IsDemo() && !Trade_On_Demo)
   {
      Log("Trading on demo account not allowed", LOG_BASIC);
      return false;
   }
   if(!IsDemo() && !Trade_On_Live)
   {
      Log("Trading on live account not allowed", LOG_BASIC);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check account number license                                      |
//+------------------------------------------------------------------+
bool CUtils::CheckAccountLicense()
{
   if(Licensed_Account == 0) return true;
   return (AccountInfoInteger(ACCOUNT_LOGIN) == Licensed_Account);
}

//+------------------------------------------------------------------+
//| Check broker whitelist                                            |
//+------------------------------------------------------------------+
bool CUtils::CheckBrokerAllowed()
{
   if(Allowed_Broker_Name == "") return true;
   string brokerName = AccountInfoString(ACCOUNT_COMPANY);
   return (StringFind(brokerName, Allowed_Broker_Name) >= 0);
}

//+------------------------------------------------------------------+
//| Check expiry date                                                 |
//+------------------------------------------------------------------+
bool CUtils::CheckExpiry()
{
   if(EA_Expiry_Date == 0) return true;
   return (TimeCurrent() < EA_Expiry_Date);
}

//+------------------------------------------------------------------+
//| Check VPS mode requirement                                        |
//+------------------------------------------------------------------+
bool CUtils::CheckVPSMode()
{
   if(!Run_On_VPS_Only) return true;
   return (bool)TerminalInfoInteger(TERMINAL_VPS);
}

//+------------------------------------------------------------------+
//| Get candle body size in points                                    |
//+------------------------------------------------------------------+
double CUtils::CandleBody(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double open  = iOpen(m_tradeSymbol, tf, shift);
   double close = iClose(m_tradeSymbol, tf, shift);
   return PriceToPoints(MathAbs(close - open));
}

//+------------------------------------------------------------------+
//| Get candle range in points                                        |
//+------------------------------------------------------------------+
double CUtils::CandleRange(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double high = iHigh(m_tradeSymbol, tf, shift);
   double low  = iLow(m_tradeSymbol, tf, shift);
   return PriceToPoints(high - low);
}

//+------------------------------------------------------------------+
//| Get upper wick in points                                          |
//+------------------------------------------------------------------+
double CUtils::UpperWick(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double high  = iHigh(m_tradeSymbol, tf, shift);
   double open  = iOpen(m_tradeSymbol, tf, shift);
   double close = iClose(m_tradeSymbol, tf, shift);
   return PriceToPoints(high - MathMax(open, close));
}

//+------------------------------------------------------------------+
//| Get lower wick in points                                          |
//+------------------------------------------------------------------+
double CUtils::LowerWick(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double low   = iLow(m_tradeSymbol, tf, shift);
   double open  = iOpen(m_tradeSymbol, tf, shift);
   double close = iClose(m_tradeSymbol, tf, shift);
   return PriceToPoints(MathMin(open, close) - low);
}

//+------------------------------------------------------------------+
//| Check if candle is bullish                                        |
//+------------------------------------------------------------------+
bool CUtils::IsBullish(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   return (iClose(m_tradeSymbol, tf, shift) > iOpen(m_tradeSymbol, tf, shift));
}

//+------------------------------------------------------------------+
//| Check for price gap                                               |
//+------------------------------------------------------------------+
bool CUtils::HasGap(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   if(!Use_Gap_Filter) return false;
   double gap = GapSize(shift, tf);
   return (gap > Max_Gap_Points);
}

//+------------------------------------------------------------------+
//| Get gap size in points                                            |
//+------------------------------------------------------------------+
double CUtils::GapSize(int shift, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double prevClose = iClose(m_tradeSymbol, tf, shift + 1);
   double currOpen  = iOpen(m_tradeSymbol, tf, shift);
   return PriceToPoints(MathAbs(currOpen - prevClose));
}

//+------------------------------------------------------------------+
//| Check for price spike                                             |
//+------------------------------------------------------------------+
bool CUtils::IsPriceSpike()
{
   if(!Use_Spike_Filter) return false;

   double range = CandleRange(0, Signal_TF);
   return (range > Spike_Points);
}


// ==================================================================
// SOURCE: SignalEngine.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                                SignalEngine.mqh   |
//|                    HFT Scalper Pro - Signal Generation Engine      |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| CSignalEngine - Generates buy/sell signals from all indicators    |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   CUtils*           m_utils;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;

   // Indicator handles
   int               m_hFastMA;
   int               m_hSlowMA;
   int               m_hSignalMA;
   int               m_hRSI;
   int               m_hStoch;
   int               m_hMACD;
   int               m_hBB;
   int               m_hATR;
   int               m_hCCI;
   int               m_hMomentum;
   int               m_hROC;
   int               m_hIchimoku;
   int               m_hADX;
   int               m_hPSAR;
   int               m_hWPR;
   int               m_hDeMarker;
   int               m_hEnvelopes;
   int               m_hBullsPower;
   int               m_hBearsPower;
   int               m_hFractals;
   int               m_hCustom1;
   int               m_hCustom2;

   // Higher TF handles
   int               m_hHTF_FastMA;
   int               m_hHTF_SlowMA;
   int               m_hMTF1_FastMA;
   int               m_hMTF1_SlowMA;
   int               m_hMTF2_FastMA;
   int               m_hMTF2_SlowMA;
   int               m_hMTF3_FastMA;
   int               m_hMTF3_SlowMA;

   // Supertrend calculated values
   double            m_supertrendUp[];
   double            m_supertrendDn[];
   int               m_supertrendDir;

   // Tick burst tracking
   datetime          m_tickTimes[];
   int               m_tickCount;

   // Signal scoring
   int               m_buyScore;
   int               m_sellScore;

   // Individual signal methods
   int               GetMASignal();
   int               GetRSISignal();
   int               GetStochSignal();
   int               GetMACDSignal();
   int               GetBBSignal();
   bool              GetATRFilter();
   int               GetCCISignal();
   int               GetMomentumSignal();
   int               GetROCSignal();
   int               GetIchimokuSignal();
   int               GetADXSignal();
   bool              GetADXFilter();
   int               GetPSARSignal();
   int               GetWPRSignal();
   int               GetDeMarkerSignal();
   int               GetEnvelopesSignal();
   int               GetBearsBullsSignal();
   int               GetFractalsSignal();
   int               GetPriceActionSignal();
   int               GetVolumeSignal();
   int               GetSRSignal();
   int               GetSpreadScalpSignal();
   int               GetCustomInd1Signal();
   int               GetCustomInd2Signal();

   // MTF / Higher TF
   int               GetHigherTFTrend();
   int               GetMTFConfirmation();

   // Market type
   ENUM_MARKET_TYPE  DetectMarketType();

   // Candle filters
   bool              PassesCandleFilter();
   bool              PassesGapFilter();
   bool              PassesSpikeFilter();

   // Supertrend calculation
   void              CalculateSupertrend();

   // VWAP
   double            CalculateVWAP();
   int               GetVWAPSignal();

   // Pivot Points
   void              CalculatePivots(double &pp, double &r1, double &s1, double &r2, double &s2);
   int               GetPivotSignal();

   // Fibonacci
   int               GetFibonacciSignal();

   // DOM
   int               GetDOMSignal();

   // Helper
   int               CopyIndicator(int handle, int buffer, int count, double &arr[]);

public:
                     CSignalEngine();
                    ~CSignalEngine();

   bool              Init(CUtils *utils);
   void              Deinit();

   // Main signal generation
   int               GetSignal();        // Returns: 1=Buy, -1=Sell, 0=None
   int               GetBuyScore()  { return m_buyScore; }
   int               GetSellScore() { return m_sellScore; }

   // Tick tracking for HFT
   void              OnTick();
   bool              IsTickBurst();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine()
{
   m_hFastMA = m_hSlowMA = m_hSignalMA = INVALID_HANDLE;
   m_hRSI = m_hStoch = m_hMACD = m_hBB = INVALID_HANDLE;
   m_hATR = m_hCCI = m_hMomentum = m_hROC = INVALID_HANDLE;
   m_hIchimoku = m_hADX = m_hPSAR = INVALID_HANDLE;
   m_hWPR = m_hDeMarker = m_hEnvelopes = INVALID_HANDLE;
   m_hBullsPower = m_hBearsPower = m_hFractals = INVALID_HANDLE;
   m_hCustom1 = m_hCustom2 = INVALID_HANDLE;
   m_hHTF_FastMA = m_hHTF_SlowMA = INVALID_HANDLE;
   m_hMTF1_FastMA = m_hMTF1_SlowMA = INVALID_HANDLE;
   m_hMTF2_FastMA = m_hMTF2_SlowMA = INVALID_HANDLE;
   m_hMTF3_FastMA = m_hMTF3_SlowMA = INVALID_HANDLE;
   m_tickCount = 0;
   m_buyScore = 0;
   m_sellScore = 0;
   m_supertrendDir = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSignalEngine::~CSignalEngine()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize all indicator handles                                  |
//+------------------------------------------------------------------+
bool CSignalEngine::Init(CUtils *utils)
{
   m_utils = utils;
   m_symbol = utils.GetTradeSymbol();
   m_tf = Signal_TF;

   // MA handles
   if(Use_MA_Signal)
   {
      m_hFastMA   = iMA(m_symbol, m_tf, Fast_MA_Period, 0, MA_Method, MA_Price);
      m_hSlowMA   = iMA(m_symbol, m_tf, Slow_MA_Period, 0, MA_Method, MA_Price);
      m_hSignalMA = iMA(m_symbol, m_tf, Signal_MA_Period, 0, MA_Method, MA_Price);
      if(m_hFastMA == INVALID_HANDLE || m_hSlowMA == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create MA handles");
         return false;
      }
   }

   // RSI
   if(Use_RSI_Filter)
   {
      m_hRSI = iRSI(m_symbol, m_tf, RSI_Period, RSI_Price);
      if(m_hRSI == INVALID_HANDLE) { Print("ERROR: RSI handle failed"); return false; }
   }

   // Stochastic
   if(Use_Stoch_Filter)
   {
      m_hStoch = iStochastic(m_symbol, m_tf, Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, Stoch_MA_Method, Stoch_Price);
      if(m_hStoch == INVALID_HANDLE) { Print("ERROR: Stochastic handle failed"); return false; }
   }

   // MACD
   if(Use_MACD_Signal)
   {
      m_hMACD = iMACD(m_symbol, m_tf, MACD_Fast_Period, MACD_Slow_Period, MACD_Signal_Period, MACD_Price);
      if(m_hMACD == INVALID_HANDLE) { Print("ERROR: MACD handle failed"); return false; }
   }

   // Bollinger Bands
   if(Use_BB_Signal)
   {
      m_hBB = iBands(m_symbol, m_tf, BB_Period, 0, BB_Deviation, BB_Price);
      if(m_hBB == INVALID_HANDLE) { Print("ERROR: BB handle failed"); return false; }
   }

   // ATR
   if(Use_ATR_Filter || Use_Dynamic_SL || Use_Dynamic_TP)
   {
      m_hATR = iATR(m_symbol, ATR_Timeframe, ATR_Filter_Period);
      if(m_hATR == INVALID_HANDLE) { Print("ERROR: ATR handle failed"); return false; }
   }

   // CCI
   if(Use_CCI_Filter)
   {
      m_hCCI = iCCI(m_symbol, m_tf, CCI_Period, CCI_Price);
      if(m_hCCI == INVALID_HANDLE) { Print("ERROR: CCI handle failed"); return false; }
   }

   // Momentum
   if(Use_Momentum_Signal)
   {
      m_hMomentum = iMomentum(m_symbol, m_tf, Momentum_Period, PRICE_CLOSE);
      if(m_hMomentum == INVALID_HANDLE) { Print("ERROR: Momentum handle failed"); return false; }
   }

   // Ichimoku
   if(Use_Ichimoku)
   {
      m_hIchimoku = iIchimoku(m_symbol, m_tf, Tenkan_Period, Kijun_Period, Senkou_B_Period);
      if(m_hIchimoku == INVALID_HANDLE) { Print("ERROR: Ichimoku handle failed"); return false; }
   }

   // ADX
   if(Use_ADX_Filter)
   {
      m_hADX = iADX(m_symbol, m_tf, ADX_Period);
      if(m_hADX == INVALID_HANDLE) { Print("ERROR: ADX handle failed"); return false; }
   }

   // Parabolic SAR
   if(Use_PSAR_Filter)
   {
      m_hPSAR = iSAR(m_symbol, m_tf, PSAR_Step, PSAR_Max);
      if(m_hPSAR == INVALID_HANDLE) { Print("ERROR: PSAR handle failed"); return false; }
   }

   // Williams %R
   if(Use_WPR_Filter)
   {
      m_hWPR = iWPR(m_symbol, m_tf, WPR_Period);
      if(m_hWPR == INVALID_HANDLE) { Print("ERROR: WPR handle failed"); return false; }
   }

   // DeMarker
   if(Use_DeMarker)
   {
      m_hDeMarker = iDeMarker(m_symbol, m_tf, DeM_Period);
      if(m_hDeMarker == INVALID_HANDLE) { Print("ERROR: DeMarker handle failed"); return false; }
   }

   // Envelopes
   if(Use_Envelopes)
   {
      m_hEnvelopes = iEnvelopes(m_symbol, m_tf, Env_Period, 0, Env_MA_Method, Env_Price, Env_Deviation);
      if(m_hEnvelopes == INVALID_HANDLE) { Print("ERROR: Envelopes handle failed"); return false; }
   }

   // Bears/Bulls Power
   if(Use_Bears_Bulls)
   {
      m_hBullsPower = iBullsPower(m_symbol, m_tf, BB_Power_Period);
      m_hBearsPower = iBearsPower(m_symbol, m_tf, BB_Power_Period);
      if(m_hBullsPower == INVALID_HANDLE || m_hBearsPower == INVALID_HANDLE)
      { Print("ERROR: Bears/Bulls handle failed"); return false; }
   }

   // Fractals
   if(Use_Fractals)
   {
      m_hFractals = iFractals(m_symbol, m_tf);
      if(m_hFractals == INVALID_HANDLE) { Print("ERROR: Fractals handle failed"); return false; }
   }

   // Higher TF filter
   if(Use_Higher_TF_Filter)
   {
      m_hHTF_FastMA = iMA(m_symbol, Higher_TF, Fast_MA_Period, 0, MA_Method, MA_Price);
      m_hHTF_SlowMA = iMA(m_symbol, Higher_TF, Slow_MA_Period, 0, MA_Method, MA_Price);
   }

   // MTF confirmation
   if(Require_MTF_Confirm)
   {
      if(MTF_TF1_Active)
      {
         m_hMTF1_FastMA = iMA(m_symbol, MTF_TF1, Fast_MA_Period, 0, MA_Method, MA_Price);
         m_hMTF1_SlowMA = iMA(m_symbol, MTF_TF1, Slow_MA_Period, 0, MA_Method, MA_Price);
      }
      if(MTF_TF2_Active)
      {
         m_hMTF2_FastMA = iMA(m_symbol, MTF_TF2, Fast_MA_Period, 0, MA_Method, MA_Price);
         m_hMTF2_SlowMA = iMA(m_symbol, MTF_TF2, Slow_MA_Period, 0, MA_Method, MA_Price);
      }
      if(MTF_TF3_Active)
      {
         m_hMTF3_FastMA = iMA(m_symbol, MTF_TF3, Fast_MA_Period, 0, MA_Method, MA_Price);
         m_hMTF3_SlowMA = iMA(m_symbol, MTF_TF3, Slow_MA_Period, 0, MA_Method, MA_Price);
      }
   }

   // Custom indicators
   if(Use_Custom_Ind_1 && Custom_Ind_1_Name != "")
   {
      m_hCustom1 = iCustom(m_symbol, m_tf, Custom_Ind_1_Name);
   }
   if(Use_Custom_Ind_2 && Custom_Ind_2_Name != "")
   {
      m_hCustom2 = iCustom(m_symbol, m_tf, Custom_Ind_2_Name);
   }

   // Allocate tick tracking array
   ArrayResize(m_tickTimes, 0);

   m_utils.Log("SignalEngine initialized with " + IntegerToString(CountActiveIndicators()) + " active indicators", LOG_BASIC);
   return true;
}

//+------------------------------------------------------------------+
//| Count active indicators                                           |
//+------------------------------------------------------------------+
int CountActiveIndicators()
{
   int count = 0;
   if(Use_MA_Signal) count++;
   if(Use_RSI_Filter) count++;
   if(Use_Stoch_Filter) count++;
   if(Use_MACD_Signal) count++;
   if(Use_BB_Signal) count++;
   if(Use_ATR_Filter) count++;
   if(Use_CCI_Filter) count++;
   if(Use_Momentum_Signal) count++;
   if(Use_ROC_Signal) count++;
   if(Use_Ichimoku) count++;
   if(Use_ADX_Filter) count++;
   if(Use_PSAR_Filter) count++;
   if(Use_WPR_Filter) count++;
   if(Use_DeMarker) count++;
   if(Use_Envelopes) count++;
   if(Use_Bears_Bulls) count++;
   if(Use_Fractals) count++;
   if(Use_Candle_Patterns) count++;
   if(Use_Tick_Volume) count++;
   if(Use_SR_Levels) count++;
   if(Use_Spread_Scalp) count++;
   if(Use_Supertrend) count++;
   if(Use_VWAP_Filter) count++;
   if(Use_Pivot_Points) count++;
   if(Use_Fibonacci) count++;
   if(Use_DOM_Filter) count++;
   if(Use_Custom_Ind_1) count++;
   if(Use_Custom_Ind_2) count++;
   return count;
}

//+------------------------------------------------------------------+
//| Release all indicator handles                                     |
//+------------------------------------------------------------------+
void CSignalEngine::Deinit()
{
   int handles[] = {};
   // Release all valid handles
   if(m_hFastMA != INVALID_HANDLE) IndicatorRelease(m_hFastMA);
   if(m_hSlowMA != INVALID_HANDLE) IndicatorRelease(m_hSlowMA);
   if(m_hSignalMA != INVALID_HANDLE) IndicatorRelease(m_hSignalMA);
   if(m_hRSI != INVALID_HANDLE) IndicatorRelease(m_hRSI);
   if(m_hStoch != INVALID_HANDLE) IndicatorRelease(m_hStoch);
   if(m_hMACD != INVALID_HANDLE) IndicatorRelease(m_hMACD);
   if(m_hBB != INVALID_HANDLE) IndicatorRelease(m_hBB);
   if(m_hATR != INVALID_HANDLE) IndicatorRelease(m_hATR);
   if(m_hCCI != INVALID_HANDLE) IndicatorRelease(m_hCCI);
   if(m_hMomentum != INVALID_HANDLE) IndicatorRelease(m_hMomentum);
   if(m_hROC != INVALID_HANDLE) IndicatorRelease(m_hROC);
   if(m_hIchimoku != INVALID_HANDLE) IndicatorRelease(m_hIchimoku);
   if(m_hADX != INVALID_HANDLE) IndicatorRelease(m_hADX);
   if(m_hPSAR != INVALID_HANDLE) IndicatorRelease(m_hPSAR);
   if(m_hWPR != INVALID_HANDLE) IndicatorRelease(m_hWPR);
   if(m_hDeMarker != INVALID_HANDLE) IndicatorRelease(m_hDeMarker);
   if(m_hEnvelopes != INVALID_HANDLE) IndicatorRelease(m_hEnvelopes);
   if(m_hBullsPower != INVALID_HANDLE) IndicatorRelease(m_hBullsPower);
   if(m_hBearsPower != INVALID_HANDLE) IndicatorRelease(m_hBearsPower);
   if(m_hFractals != INVALID_HANDLE) IndicatorRelease(m_hFractals);
   if(m_hHTF_FastMA != INVALID_HANDLE) IndicatorRelease(m_hHTF_FastMA);
   if(m_hHTF_SlowMA != INVALID_HANDLE) IndicatorRelease(m_hHTF_SlowMA);
   if(m_hMTF1_FastMA != INVALID_HANDLE) IndicatorRelease(m_hMTF1_FastMA);
   if(m_hMTF1_SlowMA != INVALID_HANDLE) IndicatorRelease(m_hMTF1_SlowMA);
   if(m_hMTF2_FastMA != INVALID_HANDLE) IndicatorRelease(m_hMTF2_FastMA);
   if(m_hMTF2_SlowMA != INVALID_HANDLE) IndicatorRelease(m_hMTF2_SlowMA);
   if(m_hMTF3_FastMA != INVALID_HANDLE) IndicatorRelease(m_hMTF3_FastMA);
   if(m_hMTF3_SlowMA != INVALID_HANDLE) IndicatorRelease(m_hMTF3_SlowMA);
   if(m_hCustom1 != INVALID_HANDLE) IndicatorRelease(m_hCustom1);
   if(m_hCustom2 != INVALID_HANDLE) IndicatorRelease(m_hCustom2);
}

//+------------------------------------------------------------------+
//| Helper: Copy indicator buffer                                     |
//+------------------------------------------------------------------+
int CSignalEngine::CopyIndicator(int handle, int buffer, int count, double &arr[])
{
   ArraySetAsSeries(arr, true);
   return CopyBuffer(handle, buffer, 0, count, arr);
}

//+------------------------------------------------------------------+
//| Track tick times for burst detection                              |
//+------------------------------------------------------------------+
void CSignalEngine::OnTick()
{
   datetime now = TimeCurrent();
   int size = ArraySize(m_tickTimes);
   ArrayResize(m_tickTimes, size + 1);
   m_tickTimes[size] = now;

   // Cleanup old ticks (keep last 100)
   if(ArraySize(m_tickTimes) > 100)
   {
      int remove = ArraySize(m_tickTimes) - 100;
      for(int i = 0; i < 100; i++)
         m_tickTimes[i] = m_tickTimes[i + remove];
      ArrayResize(m_tickTimes, 100);
   }
}

//+------------------------------------------------------------------+
//| Check for tick burst (HFT mode)                                   |
//+------------------------------------------------------------------+
bool CSignalEngine::IsTickBurst()
{
   if(!Use_Spread_Scalp) return false;

   int size = ArraySize(m_tickTimes);
   if(size < Tick_Burst_Count) return false;

   // Check if last N ticks happened within Tick_Burst_MS milliseconds
   // Note: MQL5 TimeCurrent() is in seconds, so this is approximate
   datetime windowStart = m_tickTimes[size - 1] - (Tick_Burst_MS / 1000 + 1);
   int count = 0;
   for(int i = size - 1; i >= 0; i--)
   {
      if(m_tickTimes[i] >= windowStart) count++;
      else break;
   }

   return (count >= Tick_Burst_Count);
}

//+------------------------------------------------------------------+
//| MAIN SIGNAL GENERATION                                            |
//| Combines all active indicator signals                             |
//| Returns: 1=Buy, -1=Sell, 0=No signal                             |
//+------------------------------------------------------------------+
int CSignalEngine::GetSignal()
{
   m_buyScore = 0;
   m_sellScore = 0;

   // --- Pre-filters (must pass to generate any signal) ---

   // ATR volatility filter
   if(Use_ATR_Filter && !GetATRFilter())
      return 0;

   // Candle filter
   if(Use_Candle_Filter && !PassesCandleFilter())
      return 0;

   // Gap filter
   if(Use_Gap_Filter && !PassesGapFilter())
      return 0;

   // Spike filter
   if(Use_Spike_Filter && !PassesSpikeFilter())
      return 0;

   // ADX filter (trend strength gate)
   if(Use_ADX_Filter && !GetADXFilter())
      return 0;

   // Market type detection
   if(Use_Market_Type)
   {
      ENUM_MARKET_TYPE mt = DetectMarketType();
      if(mt == MARKET_TRENDING && !Trade_Trending_Market) return 0;
      if(mt == MARKET_RANGING && !Trade_Ranging_Market) return 0;
   }

   // Volume filter
   int volSig = 0;
   if(Use_Tick_Volume)
   {
      volSig = GetVolumeSignal();
      if(volSig == 0) return 0; // No volume confirmation
   }

   // --- Score-based or direct signal generation ---

   // Moving Averages
   if(Use_MA_Signal)
   {
      int sig = GetMASignal();
      if(sig > 0) m_buyScore += MA_Score_Weight;
      if(sig < 0) m_sellScore += MA_Score_Weight;
      if(!Use_Signal_Score && sig != 0)
      {
         // In non-scoring mode, MA is the primary signal
      }
   }

   // RSI
   if(Use_RSI_Filter)
   {
      int sig = GetRSISignal();
      if(sig > 0) m_buyScore += RSI_Score_Weight;
      if(sig < 0) m_sellScore += RSI_Score_Weight;
   }

   // Stochastic
   if(Use_Stoch_Filter)
   {
      int sig = GetStochSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // MACD
   if(Use_MACD_Signal)
   {
      int sig = GetMACDSignal();
      if(sig > 0) m_buyScore += MACD_Score_Weight;
      if(sig < 0) m_sellScore += MACD_Score_Weight;
   }

   // Bollinger Bands
   if(Use_BB_Signal)
   {
      int sig = GetBBSignal();
      if(sig > 0) m_buyScore += BB_Score_Weight;
      if(sig < 0) m_sellScore += BB_Score_Weight;
   }

   // CCI
   if(Use_CCI_Filter)
   {
      int sig = GetCCISignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Momentum
   if(Use_Momentum_Signal)
   {
      int sig = GetMomentumSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Ichimoku
   if(Use_Ichimoku)
   {
      int sig = GetIchimokuSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // ADX direction
   if(Use_ADX_Filter && ADX_Direction_Filter)
   {
      int sig = GetADXSignal();
      if(sig > 0) m_buyScore += ADX_Score_Weight;
      if(sig < 0) m_sellScore += ADX_Score_Weight;
   }

   // Parabolic SAR
   if(Use_PSAR_Filter)
   {
      int sig = GetPSARSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Williams %R
   if(Use_WPR_Filter)
   {
      int sig = GetWPRSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // DeMarker
   if(Use_DeMarker)
   {
      int sig = GetDeMarkerSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Envelopes
   if(Use_Envelopes)
   {
      int sig = GetEnvelopesSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Bears/Bulls Power
   if(Use_Bears_Bulls)
   {
      int sig = GetBearsBullsSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Fractals
   if(Use_Fractals)
   {
      int sig = GetFractalsSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Price Action
   if(Use_Candle_Patterns)
   {
      int sig = GetPriceActionSignal();
      if(sig > 0) m_buyScore += PA_Score_Weight;
      if(sig < 0) m_sellScore += PA_Score_Weight;
   }

   // S/R Levels
   if(Use_SR_Levels)
   {
      int sig = GetSRSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Supertrend
   if(Use_Supertrend)
   {
      CalculateSupertrend();
      if(m_supertrendDir > 0) m_buyScore += 1;
      if(m_supertrendDir < 0) m_sellScore += 1;
   }

   // VWAP
   if(Use_VWAP_Filter)
   {
      int sig = GetVWAPSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Pivot Points
   if(Use_Pivot_Points)
   {
      int sig = GetPivotSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Fibonacci
   if(Use_Fibonacci)
   {
      int sig = GetFibonacciSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // DOM
   if(Use_DOM_Filter)
   {
      int sig = GetDOMSignal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // Spread Scalp (pure HFT)
   if(Use_Spread_Scalp)
   {
      int sig = GetSpreadScalpSignal();
      if(sig > 0) m_buyScore += 2;
      if(sig < 0) m_sellScore += 2;
   }

   // Custom indicators
   if(Use_Custom_Ind_1)
   {
      int sig = GetCustomInd1Signal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }
   if(Use_Custom_Ind_2)
   {
      int sig = GetCustomInd2Signal();
      if(sig > 0) m_buyScore += 1;
      if(sig < 0) m_sellScore += 1;
   }

   // --- Determine final signal ---
   int signal = 0;

   if(Use_Signal_Score)
   {
      // Score-based: need minimum score
      if(m_buyScore >= Min_Score_To_Trade && m_buyScore > m_sellScore)
         signal = 1;
      else if(m_sellScore >= Min_Score_To_Trade && m_sellScore > m_buyScore)
         signal = -1;
   }
   else
   {
      // Non-scoring: buy if more buy signals, sell if more sell signals
      if(m_buyScore > 0 && m_buyScore > m_sellScore)
         signal = 1;
      else if(m_sellScore > 0 && m_sellScore > m_buyScore)
         signal = -1;
   }

   // --- Post-filters ---

   // Higher TF trend filter
   if(signal != 0 && Use_Higher_TF_Filter)
   {
      int htfTrend = GetHigherTFTrend();
      if(htfTrend != 0 && htfTrend != signal)
         signal = 0;
   }

   // MTF confirmation
   if(signal != 0 && Require_MTF_Confirm)
   {
      int mtfConfirm = GetMTFConfirmation();
      if(mtfConfirm != signal && MTF_All_Must_Agree)
         signal = 0;
   }

   // Direction filter
   if(signal > 0 && Trade_Direction == TRADE_SELL_ONLY) signal = 0;
   if(signal < 0 && Trade_Direction == TRADE_BUY_ONLY) signal = 0;

   // Flip direction
   if(Flip_Direction && signal != 0)
      signal = -signal;

   // Day-specific direction
   int dow = m_utils.GetDayOfWeek();
   if(signal > 0 && dow == 1 && !Allow_Buy_Monday) signal = 0;
   if(signal < 0 && dow == 5 && !Allow_Sell_Friday) signal = 0;

   if(signal != 0)
   {
      m_utils.Log("Signal generated: " + (signal > 0 ? "BUY" : "SELL") +
                  " | BuyScore=" + IntegerToString(m_buyScore) +
                  " SellScore=" + IntegerToString(m_sellScore), LOG_DETAIL);
   }

   return signal;
}

//+------------------------------------------------------------------+
//| MA Signal                                                         |
//+------------------------------------------------------------------+
int CSignalEngine::GetMASignal()
{
   double fast[], slow[];
   if(CopyIndicator(m_hFastMA, 0, 3, fast) < 3) return 0;
   if(CopyIndicator(m_hSlowMA, 0, 3, slow) < 3) return 0;

   if(MA_Cross_Only)
   {
      // Crossover detection
      if(fast[1] > slow[1] && fast[2] <= slow[2]) return 1;
      if(fast[1] < slow[1] && fast[2] >= slow[2]) return -1;
   }
   else
   {
      // Direction + gap
      double gap = m_utils.PriceToPoints(MathAbs(fast[1] - slow[1]));
      if(gap < MA_Gap_Min_Points) return 0;

      if(fast[1] > slow[1]) return 1;
      if(fast[1] < slow[1]) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| RSI Signal                                                        |
//+------------------------------------------------------------------+
int CSignalEngine::GetRSISignal()
{
   double rsi[];
   if(CopyIndicator(m_hRSI, 0, 3, rsi) < 3) return 0;

   // Oversold bounce = buy, Overbought bounce = sell
   if(rsi[1] > RSI_Buy_Level && rsi[1] < RSI_Overbought && rsi[1] > rsi[2])
      return 1;
   if(rsi[1] < RSI_Sell_Level && rsi[1] > RSI_Oversold && rsi[1] < rsi[2])
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Stochastic Signal                                                 |
//+------------------------------------------------------------------+
int CSignalEngine::GetStochSignal()
{
   double k[], d[];
   if(CopyIndicator(m_hStoch, 0, 3, k) < 3) return 0;
   if(CopyIndicator(m_hStoch, 1, 3, d) < 3) return 0;

   // %K crosses above %D from oversold
   if(k[1] > d[1] && k[2] <= d[2] && k[1] < Stoch_Overbought)
      return 1;
   // %K crosses below %D from overbought
   if(k[1] < d[1] && k[2] >= d[2] && k[1] > Stoch_Oversold)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| MACD Signal                                                       |
//+------------------------------------------------------------------+
int CSignalEngine::GetMACDSignal()
{
   double macd[], signal[];
   if(CopyIndicator(m_hMACD, 0, 3, macd) < 3) return 0;
   if(CopyIndicator(m_hMACD, 1, 3, signal) < 3) return 0;

   if(MACD_Cross_Signal)
   {
      // Signal line cross
      if(macd[1] > signal[1] && macd[2] <= signal[2] &&
         MathAbs(macd[1] - signal[1]) > MACD_Min_Histogram)
         return 1;
      if(macd[1] < signal[1] && macd[2] >= signal[2] &&
         MathAbs(macd[1] - signal[1]) > MACD_Min_Histogram)
         return -1;
   }

   if(MACD_Zero_Cross)
   {
      if(macd[1] > 0 && macd[2] <= 0) return 1;
      if(macd[1] < 0 && macd[2] >= 0) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Bollinger Bands Signal                                            |
//+------------------------------------------------------------------+
int CSignalEngine::GetBBSignal()
{
   double upper[], middle[], lower[];
   if(CopyIndicator(m_hBB, 1, 3, upper) < 3) return 0;
   if(CopyIndicator(m_hBB, 0, 3, middle) < 3) return 0;
   if(CopyIndicator(m_hBB, 2, 3, lower) < 3) return 0;

   double close1 = iClose(m_symbol, m_tf, 1);
   double close2 = iClose(m_symbol, m_tf, 2);

   // Squeeze filter
   if(BB_Squeeze_Filter)
   {
      double bandwidth = (upper[1] - lower[1]) / middle[1];
      if(bandwidth > BB_Squeeze_Threshold) return 0;
   }

   if(BB_Bounce_Signal)
   {
      // Price touches lower band and bounces up
      if(close2 <= lower[2] && close1 > lower[1]) return 1;
      // Price touches upper band and bounces down
      if(close2 >= upper[2] && close1 < upper[1]) return -1;
   }

   if(BB_Breakout_Signal)
   {
      if(close1 > upper[1] && close2 <= upper[2]) return 1;
      if(close1 < lower[1] && close2 >= lower[2]) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| ATR Volatility Filter (gate, not signal)                          |
//+------------------------------------------------------------------+
bool CSignalEngine::GetATRFilter()
{
   double atr[];
   if(CopyIndicator(m_hATR, 0, 1, atr) < 1) return true;

   if(atr[0] < ATR_Min_Value) return false;
   if(atr[0] > ATR_Max_Value) return false;

   return true;
}

//+------------------------------------------------------------------+
//| CCI Signal                                                        |
//+------------------------------------------------------------------+
int CSignalEngine::GetCCISignal()
{
   double cci[];
   if(CopyIndicator(m_hCCI, 0, 3, cci) < 3) return 0;

   if(cci[1] > CCI_Oversold && cci[2] <= CCI_Oversold) return 1;   // Crosses above oversold
   if(cci[1] < CCI_Overbought && cci[2] >= CCI_Overbought) return -1; // Crosses below overbought

   return 0;
}

//+------------------------------------------------------------------+
//| Momentum Signal                                                   |
//+------------------------------------------------------------------+
int CSignalEngine::GetMomentumSignal()
{
   double mom[];
   if(CopyIndicator(m_hMomentum, 0, 3, mom) < 3) return 0;

   if(mom[1] > Momentum_Level && mom[1] > mom[2]) return 1;
   if(mom[1] < (200 - Momentum_Level) && mom[1] < mom[2]) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| ROC Signal                                                        |
//+------------------------------------------------------------------+
int CSignalEngine::GetROCSignal()
{
   // ROC can be calculated from momentum or custom
   if(!Use_ROC_Signal) return 0;

   double close0 = iClose(m_symbol, m_tf, 1);
   double closeN = iClose(m_symbol, m_tf, 1 + ROC_Period);
   if(closeN == 0) return 0;

   double roc = ((close0 - closeN) / closeN) * 100.0;

   if(roc > ROC_Threshold) return 1;
   if(roc < -ROC_Threshold) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Ichimoku Signal                                                   |
//+------------------------------------------------------------------+
int CSignalEngine::GetIchimokuSignal()
{
   double tenkan[], kijun[], spanA[], spanB[];
   if(CopyIndicator(m_hIchimoku, 0, 3, tenkan) < 3) return 0;    // Tenkan-sen
   if(CopyIndicator(m_hIchimoku, 1, 3, kijun) < 3) return 0;     // Kijun-sen
   if(CopyIndicator(m_hIchimoku, 2, 3, spanA) < 3) return 0;     // Senkou Span A
   if(CopyIndicator(m_hIchimoku, 3, 3, spanB) < 3) return 0;     // Senkou Span B

   double close1 = iClose(m_symbol, m_tf, 1);

   // Cloud filter
   double cloudTop = MathMax(spanA[1], spanB[1]);
   double cloudBot = MathMin(spanA[1], spanB[1]);

   if(Trade_Above_Cloud && close1 < cloudTop) return 0;

   // TK cross signal
   if(TK_Cross_Signal)
   {
      if(tenkan[1] > kijun[1] && tenkan[2] <= kijun[2] && close1 > cloudTop)
         return 1;
      if(tenkan[1] < kijun[1] && tenkan[2] >= kijun[2] && close1 < cloudBot)
         return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| ADX Direction Signal                                              |
//+------------------------------------------------------------------+
int CSignalEngine::GetADXSignal()
{
   double adx[], diPlus[], diMinus[];
   if(CopyIndicator(m_hADX, 0, 2, adx) < 2) return 0;
   if(CopyIndicator(m_hADX, 1, 2, diPlus) < 2) return 0;
   if(CopyIndicator(m_hADX, 2, 2, diMinus) < 2) return 0;

   double gap = MathAbs(diPlus[0] - diMinus[0]);
   if(gap < ADX_DI_Gap_Min) return 0;

   if(diPlus[0] > diMinus[0]) return 1;
   if(diMinus[0] > diPlus[0]) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| ADX Filter (strength gate)                                        |
//+------------------------------------------------------------------+
bool CSignalEngine::GetADXFilter()
{
   double adx[];
   if(CopyIndicator(m_hADX, 0, 1, adx) < 1) return true;

   if(adx[0] < ADX_Min_Level) return false;
   if(adx[0] > ADX_Max_Level) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Parabolic SAR Signal                                              |
//+------------------------------------------------------------------+
int CSignalEngine::GetPSARSignal()
{
   double sar[];
   if(CopyIndicator(m_hPSAR, 0, 3, sar) < 3) return 0;

   double close1 = iClose(m_symbol, m_tf, 1);
   double close2 = iClose(m_symbol, m_tf, 2);

   if(PSAR_Trend_Only)
   {
      if(close1 > sar[1]) return 1;
      if(close1 < sar[1]) return -1;
   }
   else
   {
      // SAR flip
      if(close1 > sar[1] && close2 <= sar[2]) return 1;
      if(close1 < sar[1] && close2 >= sar[2]) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Williams %R Signal                                                |
//+------------------------------------------------------------------+
int CSignalEngine::GetWPRSignal()
{
   double wpr[];
   if(CopyIndicator(m_hWPR, 0, 3, wpr) < 3) return 0;

   if(wpr[1] > WPR_Oversold && wpr[2] <= WPR_Oversold) return 1;
   if(wpr[1] < WPR_Overbought && wpr[2] >= WPR_Overbought) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| DeMarker Signal                                                   |
//+------------------------------------------------------------------+
int CSignalEngine::GetDeMarkerSignal()
{
   double dem[];
   if(CopyIndicator(m_hDeMarker, 0, 3, dem) < 3) return 0;

   if(dem[1] > DeM_Oversold && dem[2] <= DeM_Oversold) return 1;
   if(dem[1] < DeM_Overbought && dem[2] >= DeM_Overbought) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Envelopes Signal                                                  |
//+------------------------------------------------------------------+
int CSignalEngine::GetEnvelopesSignal()
{
   double upper[], lower[];
   if(CopyIndicator(m_hEnvelopes, 0, 3, upper) < 3) return 0;
   if(CopyIndicator(m_hEnvelopes, 1, 3, lower) < 3) return 0;

   double close1 = iClose(m_symbol, m_tf, 1);
   double close2 = iClose(m_symbol, m_tf, 2);

   if(close2 <= lower[2] && close1 > lower[1]) return 1;
   if(close2 >= upper[2] && close1 < upper[1]) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Bears/Bulls Power Signal                                          |
//+------------------------------------------------------------------+
int CSignalEngine::GetBearsBullsSignal()
{
   double bulls[], bears[];
   if(CopyIndicator(m_hBullsPower, 0, 2, bulls) < 2) return 0;
   if(CopyIndicator(m_hBearsPower, 0, 2, bears) < 2) return 0;

   if(bulls[0] > Bulls_Min_Level && bears[0] > Bears_Max_Level) return 1;
   if(bears[0] < Bears_Max_Level && bulls[0] < Bulls_Min_Level) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Fractals Signal                                                   |
//+------------------------------------------------------------------+
int CSignalEngine::GetFractalsSignal()
{
   double fracUp[], fracDn[];
   if(CopyIndicator(m_hFractals, 0, 10, fracUp) < 10) return 0;
   if(CopyIndicator(m_hFractals, 1, 10, fracDn) < 10) return 0;

   double close1 = iClose(m_symbol, m_tf, 1);

   if(Trade_Fractal_Break)
   {
      // Find last valid fractal
      for(int i = 2; i < 10; i++)
      {
         if(fracUp[i] != EMPTY_VALUE && fracUp[i] != 0)
         {
            if(close1 > fracUp[i]) return 1;
            break;
         }
      }
      for(int i = 2; i < 10; i++)
      {
         if(fracDn[i] != EMPTY_VALUE && fracDn[i] != 0)
         {
            if(close1 < fracDn[i]) return -1;
            break;
         }
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Price Action Candle Pattern Signal                                |
//+------------------------------------------------------------------+
int CSignalEngine::GetPriceActionSignal()
{
   for(int shift = 1; shift <= PA_Lookback_Bars; shift++)
   {
      double open1  = iOpen(m_symbol, m_tf, shift);
      double close1 = iClose(m_symbol, m_tf, shift);
      double high1  = iHigh(m_symbol, m_tf, shift);
      double low1   = iLow(m_symbol, m_tf, shift);
      double range1 = high1 - low1;
      if(range1 == 0) continue;

      double body1 = MathAbs(close1 - open1);
      double bodyRatio = body1 / range1;

      // Pin Bar
      if(PA_Pin_Bar)
      {
         double upperWick = high1 - MathMax(open1, close1);
         double lowerWick = MathMin(open1, close1) - low1;

         // Bullish pin bar (long lower wick)
         if(lowerWick / range1 > PA_Min_Wick_Ratio && bodyRatio < (1.0 - PA_Min_Wick_Ratio))
            return 1;
         // Bearish pin bar (long upper wick)
         if(upperWick / range1 > PA_Min_Wick_Ratio && bodyRatio < (1.0 - PA_Min_Wick_Ratio))
            return -1;
      }

      // Engulfing
      if(PA_Engulfing && shift >= 2)
      {
         double open2  = iOpen(m_symbol, m_tf, shift + 1);
         double close2 = iClose(m_symbol, m_tf, shift + 1);

         // Bullish engulfing
         if(close1 > open1 && close2 < open2 &&
            close1 > open2 && open1 < close2 &&
            bodyRatio >= PA_Min_Body_Ratio)
            return 1;
         // Bearish engulfing
         if(close1 < open1 && close2 > open2 &&
            close1 < open2 && open1 > close2 &&
            bodyRatio >= PA_Min_Body_Ratio)
            return -1;
      }

      // Inside Bar
      if(PA_Inside_Bar && shift >= 2)
      {
         double high2 = iHigh(m_symbol, m_tf, shift + 1);
         double low2  = iLow(m_symbol, m_tf, shift + 1);

         if(high1 < high2 && low1 > low2)
         {
            if(close1 > open1) return 1;
            if(close1 < open1) return -1;
         }
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Volume Signal                                                     |
//+------------------------------------------------------------------+
int CSignalEngine::GetVolumeSignal()
{
   long volumes[];
   ArraySetAsSeries(volumes, true);
   if(CopyTickVolume(m_symbol, m_tf, 0, Volume_MA_Period + 1, volumes) < Volume_MA_Period + 1)
      return 1; // Can't check, allow

   // Calculate volume MA
   double volMA = 0;
   for(int i = 1; i <= Volume_MA_Period; i++)
      volMA += (double)volumes[i];
   volMA /= Volume_MA_Period;

   double currentVol = (double)volumes[0];

   // Spike filter: too much volume = avoid
   if(Volume_Spike_Filter && currentVol > volMA * Spike_Volume_x)
      return 0;

   // Volume confirmation: current vol should be above average
   if(currentVol >= volMA * Volume_Multiplier)
      return 1; // Volume confirmed (direction neutral)

   return 0; // Volume too low
}

//+------------------------------------------------------------------+
//| Support/Resistance Signal                                         |
//+------------------------------------------------------------------+
int CSignalEngine::GetSRSignal()
{
   double close1 = iClose(m_symbol, m_tf, 1);
   double zoneWidth = SR_Zone_Points * m_utils.Point();

   // Find S/R levels from recent highs/lows
   double levels[];
   int levelCount = 0;
   ArrayResize(levels, 0);

   for(int i = 2; i < SR_Lookback_Bars - 2; i++)
   {
      double high = iHigh(m_symbol, m_tf, i);
      double low  = iLow(m_symbol, m_tf, i);

      // Check if this is a local high (resistance)
      bool isHigh = true;
      bool isLow = true;
      for(int j = 1; j <= 2; j++)
      {
         if(iHigh(m_symbol, m_tf, i - j) > high || iHigh(m_symbol, m_tf, i + j) > high)
            isHigh = false;
         if(iLow(m_symbol, m_tf, i - j) < low || iLow(m_symbol, m_tf, i + j) < low)
            isLow = false;
      }

      if(isHigh)
      {
         ArrayResize(levels, levelCount + 1);
         levels[levelCount++] = high;
      }
      if(isLow)
      {
         ArrayResize(levels, levelCount + 1);
         levels[levelCount++] = low;
      }
   }

   // Check price relative to S/R
   for(int i = 0; i < levelCount; i++)
   {
      double dist = MathAbs(close1 - levels[i]);
      if(dist <= zoneWidth)
      {
         if(Trade_SR_Bounce)
         {
            if(close1 > levels[i]) return 1; // Bouncing off support
            else return -1; // Bouncing off resistance
         }
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Spread Scalp Signal (Pure HFT)                                    |
//+------------------------------------------------------------------+
int CSignalEngine::GetSpreadScalpSignal()
{
   double spread = m_utils.GetSpreadPoints();
   if(spread > Spread_Entry_Threshold) return 0;

   if(!IsTickBurst()) return 0;

   // Determine direction from last tick movement
   double close0 = iClose(m_symbol, m_tf, 0);
   double close1 = iClose(m_symbol, m_tf, 1);

   if(close0 > close1) return 1;
   if(close0 < close1) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Custom Indicator 1 Signal                                         |
//+------------------------------------------------------------------+
int CSignalEngine::GetCustomInd1Signal()
{
   if(m_hCustom1 == INVALID_HANDLE) return 0;

   double val[];
   if(CopyIndicator(m_hCustom1, Custom_Ind_1_Buffer, 2, val) < 2) return 0;

   if(val[0] >= Custom_Ind_1_Buy_Val) return 1;
   if(val[0] <= Custom_Ind_1_Sell_Val) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Custom Indicator 2 Signal                                         |
//+------------------------------------------------------------------+
int CSignalEngine::GetCustomInd2Signal()
{
   if(m_hCustom2 == INVALID_HANDLE) return 0;

   double val[];
   if(CopyIndicator(m_hCustom2, Custom_Ind_2_Buffer, 2, val) < 2) return 0;

   if(val[0] >= Custom_Ind_2_Buy_Val) return 1;
   if(val[0] <= Custom_Ind_2_Sell_Val) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Higher TF Trend Filter                                            |
//+------------------------------------------------------------------+
int CSignalEngine::GetHigherTFTrend()
{
   if(m_hHTF_FastMA == INVALID_HANDLE || m_hHTF_SlowMA == INVALID_HANDLE) return 0;

   double fast[], slow[];
   if(CopyIndicator(m_hHTF_FastMA, 0, 2, fast) < 2) return 0;
   if(CopyIndicator(m_hHTF_SlowMA, 0, 2, slow) < 2) return 0;

   if(fast[0] > slow[0]) return 1;
   if(fast[0] < slow[0]) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Multi-Timeframe Confirmation                                      |
//+------------------------------------------------------------------+
int CSignalEngine::GetMTFConfirmation()
{
   int buyVotes = 0;
   int sellVotes = 0;
   int totalVotes = 0;

   // TF1
   if(MTF_TF1_Active && m_hMTF1_FastMA != INVALID_HANDLE)
   {
      double fast[], slow[];
      if(CopyIndicator(m_hMTF1_FastMA, 0, 2, fast) >= 2 &&
         CopyIndicator(m_hMTF1_SlowMA, 0, 2, slow) >= 2)
      {
         totalVotes++;
         if(fast[0] > slow[0]) buyVotes++;
         else sellVotes++;
      }
   }

   // TF2
   if(MTF_TF2_Active && m_hMTF2_FastMA != INVALID_HANDLE)
   {
      double fast[], slow[];
      if(CopyIndicator(m_hMTF2_FastMA, 0, 2, fast) >= 2 &&
         CopyIndicator(m_hMTF2_SlowMA, 0, 2, slow) >= 2)
      {
         totalVotes++;
         if(fast[0] > slow[0]) buyVotes++;
         else sellVotes++;
      }
   }

   // TF3
   if(MTF_TF3_Active && m_hMTF3_FastMA != INVALID_HANDLE)
   {
      double fast[], slow[];
      if(CopyIndicator(m_hMTF3_FastMA, 0, 2, fast) >= 2 &&
         CopyIndicator(m_hMTF3_SlowMA, 0, 2, slow) >= 2)
      {
         totalVotes++;
         if(fast[0] > slow[0]) buyVotes++;
         else sellVotes++;
      }
   }

   if(totalVotes == 0) return 0;

   if(MTF_All_Must_Agree)
   {
      if(buyVotes == totalVotes) return 1;
      if(sellVotes == totalVotes) return -1;
      return 0;
   }
   else
   {
      // Majority
      if(buyVotes > sellVotes) return 1;
      if(sellVotes > buyVotes) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Market Type Detection                                             |
//+------------------------------------------------------------------+
ENUM_MARKET_TYPE CSignalEngine::DetectMarketType()
{
   if(!Use_ADX_Filter || m_hADX == INVALID_HANDLE) return MARKET_UNKNOWN;

   double adx[];
   if(CopyIndicator(m_hADX, 0, 1, adx) < 1) return MARKET_UNKNOWN;

   if(adx[0] >= Trend_ADX_Min) return MARKET_TRENDING;
   if(adx[0] <= Range_ADX_Max) return MARKET_RANGING;

   return MARKET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Candle size filter                                                |
//+------------------------------------------------------------------+
bool CSignalEngine::PassesCandleFilter()
{
   double body = m_utils.CandleBody(1, m_tf);
   double range = m_utils.CandleRange(1, m_tf);

   if(body < Min_Candle_Body_Pts) return false;
   if(body > Max_Candle_Body_Pts) return false;
   if(range < Min_Candle_Range_Pts) return false;
   if(range > Max_Candle_Range_Pts) return false;

   if(range > 0)
   {
      double upperWickRatio = m_utils.UpperWick(1, m_tf) / range;
      double lowerWickRatio = m_utils.LowerWick(1, m_tf) / range;
      if(upperWickRatio > Max_Upper_Wick_Ratio) return false;
      if(lowerWickRatio > Max_Lower_Wick_Ratio) return false;
   }

   if(Ignore_Doji_Candles && range > 0)
   {
      if(body / range < 0.1) return false; // Very small body = doji
   }

   return true;
}

//+------------------------------------------------------------------+
//| Gap filter                                                        |
//+------------------------------------------------------------------+
bool CSignalEngine::PassesGapFilter()
{
   if(m_utils.HasGap(1, m_tf))
   {
      if(Skip_After_Gap) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Spike filter                                                      |
//+------------------------------------------------------------------+
bool CSignalEngine::PassesSpikeFilter()
{
   return !m_utils.IsPriceSpike();
}

//+------------------------------------------------------------------+
//| Calculate Supertrend                                              |
//+------------------------------------------------------------------+
void CSignalEngine::CalculateSupertrend()
{
   int atrHandle = iATR(m_symbol, m_tf, ST_ATR_Period);
   if(atrHandle == INVALID_HANDLE) { m_supertrendDir = 0; return; }

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 3, atr) < 3)
   {
      IndicatorRelease(atrHandle);
      m_supertrendDir = 0;
      return;
   }
   IndicatorRelease(atrHandle);

   double close1 = iClose(m_symbol, m_tf, 1);
   double high1  = iHigh(m_symbol, m_tf, 1);
   double low1   = iLow(m_symbol, m_tf, 1);
   double hl2    = (high1 + low1) / 2.0;

   double upperBand = hl2 + (ST_Multiplier * atr[1]);
   double lowerBand = hl2 - (ST_Multiplier * atr[1]);

   if(close1 > upperBand)
      m_supertrendDir = 1;  // Bullish
   else if(close1 < lowerBand)
      m_supertrendDir = -1; // Bearish
   // else keep previous direction
}

//+------------------------------------------------------------------+
//| Calculate VWAP                                                    |
//+------------------------------------------------------------------+
double CSignalEngine::CalculateVWAP()
{
   int bars = iBars(m_symbol, m_tf);
   if(bars < 2) return 0;

   // Find start of VWAP period (day start by default)
   datetime dayStart = m_utils.GetDayStart();
   int startBar = iBarShift(m_symbol, m_tf, dayStart);
   if(startBar <= 0) startBar = 50; // Fallback

   double sumPV = 0, sumV = 0;
   for(int i = startBar; i >= 1; i--)
   {
      double typical = (iHigh(m_symbol, m_tf, i) + iLow(m_symbol, m_tf, i) + iClose(m_symbol, m_tf, i)) / 3.0;
      long vol = iVolume(m_symbol, m_tf, i);
      sumPV += typical * (double)vol;
      sumV += (double)vol;
   }

   if(sumV == 0) return 0;
   return sumPV / sumV;
}

//+------------------------------------------------------------------+
//| VWAP Signal                                                       |
//+------------------------------------------------------------------+
int CSignalEngine::GetVWAPSignal()
{
   double vwap = CalculateVWAP();
   if(vwap == 0) return 0;

   double close1 = iClose(m_symbol, m_tf, 1);
   double zone = VWAP_Zone_Points * m_utils.Point();

   if(VWAP_Bounce_Entry)
   {
      if(MathAbs(close1 - vwap) <= zone)
      {
         if(close1 > vwap) return 1;
         if(close1 < vwap) return -1;
      }
   }
   else
   {
      if(Trade_Above_VWAP && close1 > vwap) return 1;
      if(Trade_Below_VWAP && close1 < vwap) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Calculate Pivot Points                                            |
//+------------------------------------------------------------------+
void CSignalEngine::CalculatePivots(double &pp, double &r1, double &s1, double &r2, double &s2)
{
   double high  = iHigh(m_symbol, Pivot_TF, 1);
   double low   = iLow(m_symbol, Pivot_TF, 1);
   double close = iClose(m_symbol, Pivot_TF, 1);

   switch(Pivot_Type)
   {
      case PP_CLASSIC:
         pp = (high + low + close) / 3.0;
         r1 = 2.0 * pp - low;
         s1 = 2.0 * pp - high;
         r2 = pp + (high - low);
         s2 = pp - (high - low);
         break;

      case PP_WOODIE:
         pp = (high + low + 2.0 * close) / 4.0;
         r1 = 2.0 * pp - low;
         s1 = 2.0 * pp - high;
         r2 = pp + (high - low);
         s2 = pp - (high - low);
         break;

      case PP_CAMARILLA:
         pp = (high + low + close) / 3.0;
         r1 = close + (high - low) * 1.1 / 12.0;
         s1 = close - (high - low) * 1.1 / 12.0;
         r2 = close + (high - low) * 1.1 / 6.0;
         s2 = close - (high - low) * 1.1 / 6.0;
         break;

      case PP_FIBONACCI:
         pp = (high + low + close) / 3.0;
         r1 = pp + 0.382 * (high - low);
         s1 = pp - 0.382 * (high - low);
         r2 = pp + 0.618 * (high - low);
         s2 = pp - 0.618 * (high - low);
         break;
   }
}

//+------------------------------------------------------------------+
//| Pivot Points Signal                                               |
//+------------------------------------------------------------------+
int CSignalEngine::GetPivotSignal()
{
   double pp, r1, s1, r2, s2;
   CalculatePivots(pp, r1, s1, r2, s2);

   double close1 = iClose(m_symbol, m_tf, 1);
   double zone = PP_Zone_Points * m_utils.Point();

   if(Trade_PP_Bounce)
   {
      if(MathAbs(close1 - s1) <= zone || MathAbs(close1 - s2) <= zone) return 1;
      if(MathAbs(close1 - r1) <= zone || MathAbs(close1 - r2) <= zone) return -1;
   }

   if(Trade_PP_Breakout)
   {
      if(close1 > r1) return 1;
      if(close1 < s1) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Fibonacci Signal                                                  |
//+------------------------------------------------------------------+
int CSignalEngine::GetFibonacciSignal()
{
   // Find swing high and low
   double swingHigh = 0, swingLow = DBL_MAX;
   for(int i = 1; i <= Fib_Swing_Lookback; i++)
   {
      double h = iHigh(m_symbol, m_tf, i);
      double l = iLow(m_symbol, m_tf, i);
      if(h > swingHigh) swingHigh = h;
      if(l < swingLow) swingLow = l;
   }

   double range = swingHigh - swingLow;
   if(range == 0) return 0;

   double fib38 = swingHigh - range * 0.382;
   double fib50 = swingHigh - range * 0.500;
   double fib61 = swingHigh - range * 0.618;

   double close1 = iClose(m_symbol, m_tf, 1);
   double zone38 = Fib_38_Zone * m_utils.Point();
   double zone50 = Fib_50_Zone * m_utils.Point();
   double zone61 = Fib_61_Zone * m_utils.Point();

   if(Fib_Retracement_Entry)
   {
      // Buy at fib support levels
      if(MathAbs(close1 - fib61) <= zone61) return 1;
      if(MathAbs(close1 - fib50) <= zone50) return 1;
      if(MathAbs(close1 - fib38) <= zone38) return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| DOM (Depth of Market) Signal                                      |
//+------------------------------------------------------------------+
int CSignalEngine::GetDOMSignal()
{
   MqlBookInfo book[];
   if(!MarketBookGet(m_symbol, book)) return 0;

   int total = ArraySize(book);
   if(total == 0) return 0;

   double bidVolume = 0, askVolume = 0;
   int levels = 0;

   for(int i = 0; i < total && levels < DOM_Depth_Levels; i++)
   {
      if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
      {
         bidVolume += (double)book[i].volume;
         levels++;
      }
   }

   levels = 0;
   for(int i = 0; i < total && levels < DOM_Depth_Levels; i++)
   {
      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
      {
         askVolume += (double)book[i].volume;
         levels++;
      }
   }

   if(askVolume == 0 || bidVolume == 0) return 0;
   if(bidVolume < DOM_Min_Volume && askVolume < DOM_Min_Volume) return 0;

   double ratio = bidVolume / askVolume;

   if(DOM_Buy_On_Bid_Pressure)
   {
      if(ratio >= DOM_Bid_Ask_Ratio_Min) return 1;
      if((1.0 / ratio) >= DOM_Bid_Ask_Ratio_Min) return -1;
   }

   return 0;
}


// ==================================================================
// SOURCE: RiskManager.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                                RiskManager.mqh   |
//|                     HFT Scalper Pro - Risk Management Module      |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| CRiskManager - Handles all risk management logic                  |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   CUtils*           m_utils;
   CPositionInfo     m_posInfo;
   string            m_symbol;

   // Daily tracking
   double            m_dailyPnL;
   int               m_dailyTradeCount;
   int               m_consecutiveLosses;
   int               m_consecutiveWins;
   datetime          m_lastDayChecked;
   datetime          m_lastTradeTime;
   datetime          m_lastLossTime;

   // Drawdown tracking
   double            m_peakEquity;
   double            m_currentDrawdown;
   double            m_currentDrawdownPct;
   bool              m_isHardStopped;
   bool              m_isSoftPaused;
   datetime          m_softPauseStart;

   // Equity curve tracking
   double            m_equityHistory[];
   int               m_equityHistorySize;

   // Martingale tracking
   int               m_martingaleStep;
   int               m_antiMartingaleStep;
   double            m_lastTradeProfit;

   // Recovery mode
   bool              m_inRecovery;
   double            m_recoveryStartEquity;

   // Profit lock
   double            m_dailyPeakProfit;

   // Internal methods
   void              CalculateDailyPnL();
   void              UpdateDrawdown();
   void              UpdateEquityCurve();
   void              UpdateStreaks(double lastProfit);

public:
                     CRiskManager();
                    ~CRiskManager();

   bool              Init(CUtils *utils);
   void              OnTrade();

   // Pre-trade risk checks
   bool              CanOpenTrade();
   bool              CheckDailyLimits();
   bool              CheckDrawdownLimits();
   bool              CheckPositionLimits(int direction); // 1=buy, -1=sell
   bool              CheckMarginRequirements(double lots);
   bool              CheckMinTimeBetweenTrades();
   bool              CheckConsecutiveLossLimit();
   bool              CheckAccountProtection();
   bool              CheckEquityCurveTrading();
   bool              CheckProfitLock();
   bool              CheckSpreadRR(double slPoints, double tpPoints);

   // Lot size modifiers
   double            GetMartingaleLot(double baseLot);
   double            GetRecoveryLot(double baseLot);
   double            GetEquityCurveLot(double baseLot);
   double            GetWinStreakLot(double baseLot);

   // Position counting
   int               CountOpenPositions();
   int               CountBuyPositions();
   int               CountSellPositions();
   int               CountPositionsBySymbol(string symbol);
   double            GetTotalUnrealizedPnL();
   double            GetBasketPnL();

   // Daily stats
   double            GetDailyPnL()          { return m_dailyPnL; }
   int               GetDailyTradeCount()   { return m_dailyTradeCount; }
   int               GetConsecutiveLosses() { return m_consecutiveLosses; }
   int               GetConsecutiveWins()   { return m_consecutiveWins; }
   double            GetCurrentDrawdown()   { return m_currentDrawdown; }
   double            GetCurrentDrawdownPct(){ return m_currentDrawdownPct; }
   double            GetPeakEquity()        { return m_peakEquity; }
   bool              IsHardStopped()        { return m_isHardStopped; }
   bool              IsInRecovery()         { return m_inRecovery; }
   int               GetMartingaleStep()    { return m_martingaleStep; }

   // Reset
   void              ResetDaily();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_dailyPnL = 0;
   m_dailyTradeCount = 0;
   m_consecutiveLosses = 0;
   m_consecutiveWins = 0;
   m_lastDayChecked = 0;
   m_lastTradeTime = 0;
   m_lastLossTime = 0;
   m_peakEquity = 0;
   m_currentDrawdown = 0;
   m_currentDrawdownPct = 0;
   m_isHardStopped = false;
   m_isSoftPaused = false;
   m_softPauseStart = 0;
   m_equityHistorySize = 0;
   m_martingaleStep = 0;
   m_antiMartingaleStep = 0;
   m_lastTradeProfit = 0;
   m_inRecovery = false;
   m_recoveryStartEquity = 0;
   m_dailyPeakProfit = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CRiskManager::Init(CUtils *utils)
{
   m_utils = utils;
   m_symbol = utils.GetTradeSymbol();
   m_peakEquity = utils.Equity();
   m_lastDayChecked = 0;

   // Force initial daily PnL calculation
   ResetDaily();
   CalculateDailyPnL();

   m_utils.Log("RiskManager initialized. Equity=" + DoubleToString(m_peakEquity, 2), LOG_BASIC);
   return true;
}

//+------------------------------------------------------------------+
//| Called on every trade event                                        |
//+------------------------------------------------------------------+
void CRiskManager::OnTrade()
{
   CalculateDailyPnL();
   UpdateDrawdown();

   if(Use_Equity_Curve)
      UpdateEquityCurve();
}

//+------------------------------------------------------------------+
//| Master pre-trade risk check                                       |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenTrade()
{
   // Hard stop check
   if(m_isHardStopped)
   {
      m_utils.Log("BLOCKED: Hard stop active (max drawdown reached)", LOG_BASIC);
      return false;
   }

   // Soft pause check
   if(m_isSoftPaused)
   {
      if((TimeCurrent() - m_softPauseStart) < DD_Pause_Hours * 3600)
      {
         m_utils.Log("BLOCKED: Soft pause active", LOG_BASIC);
         return false;
      }
      m_isSoftPaused = false;
   }

   // Check new day reset
   datetime today = m_utils.GetDayStart();
   if(today != m_lastDayChecked)
   {
      ResetDaily();
      m_lastDayChecked = today;
   }

   if(!CheckDailyLimits()) return false;
   if(!CheckDrawdownLimits()) return false;
   if(!CheckConsecutiveLossLimit()) return false;
   if(!CheckMinTimeBetweenTrades()) return false;
   if(!CheckAccountProtection()) return false;

   if(Use_Equity_Curve && !CheckEquityCurveTrading()) return false;
   if(Use_Profit_Lock && !CheckProfitLock()) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check daily loss/profit limits                                    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyLimits()
{
   CalculateDailyPnL();

   double balance = m_utils.Balance();

   // Max daily loss (USD)
   if(Max_Daily_Loss_USD > 0 && m_dailyPnL <= -Max_Daily_Loss_USD)
   {
      m_utils.Log("BLOCKED: Daily loss limit reached (USD): " + DoubleToString(m_dailyPnL, 2), LOG_BASIC);
      if(Alert_On_Daily_Limit) m_utils.SendAlert("Daily loss limit reached: " + DoubleToString(m_dailyPnL, 2));
      return false;
   }

   // Max daily loss (%)
   if(Max_Daily_Loss_Percent > 0 && balance > 0)
   {
      if(m_dailyPnL <= -(balance * Max_Daily_Loss_Percent / 100.0))
      {
         m_utils.Log("BLOCKED: Daily loss limit reached (%): " + DoubleToString(Max_Daily_Loss_Percent, 1) + "%", LOG_BASIC);
         return false;
      }
   }

   // Daily profit target (USD)
   if(Max_Daily_Profit_USD > 0 && m_dailyPnL >= Max_Daily_Profit_USD)
   {
      m_utils.Log("BLOCKED: Daily profit target reached (USD): " + DoubleToString(m_dailyPnL, 2), LOG_BASIC);
      return false;
   }

   // Daily profit target (%)
   if(Max_Daily_Profit_Pct > 0 && balance > 0)
   {
      if(m_dailyPnL >= (balance * Max_Daily_Profit_Pct / 100.0))
      {
         m_utils.Log("BLOCKED: Daily profit target reached (%)", LOG_BASIC);
         return false;
      }
   }

   // Max daily trades
   if(Max_Daily_Trades > 0 && m_dailyTradeCount >= Max_Daily_Trades)
   {
      m_utils.Log("BLOCKED: Max daily trades reached: " + IntegerToString(m_dailyTradeCount), LOG_BASIC);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check drawdown limits                                             |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDrawdownLimits()
{
   UpdateDrawdown();

   // Max drawdown USD
   if(Max_Drawdown_USD > 0 && m_currentDrawdown >= Max_Drawdown_USD)
   {
      if(Hard_Stop_On_DD)
      {
         m_isHardStopped = true;
         m_utils.Log("HARD STOP: Max drawdown USD reached: " + DoubleToString(m_currentDrawdown, 2), LOG_BASIC);
         if(Alert_On_DD_Limit) m_utils.SendAlert("HARD STOP: Drawdown limit reached");
      }
      if(Soft_Pause_On_DD && !m_isSoftPaused)
      {
         m_isSoftPaused = true;
         m_softPauseStart = TimeCurrent();
         m_utils.Log("SOFT PAUSE: Max drawdown USD reached", LOG_BASIC);
      }
      return false;
   }

   // Max drawdown %
   if(Max_Drawdown_Percent > 0 && m_currentDrawdownPct >= Max_Drawdown_Percent)
   {
      if(Hard_Stop_On_DD)
      {
         m_isHardStopped = true;
         m_utils.Log("HARD STOP: Max drawdown % reached: " + DoubleToString(m_currentDrawdownPct, 2) + "%", LOG_BASIC);
      }
      if(Soft_Pause_On_DD && !m_isSoftPaused)
      {
         m_isSoftPaused = true;
         m_softPauseStart = TimeCurrent();
      }
      return false;
   }

   // Recovery mode check
   if(Use_Recovery_Mode)
   {
      if(!m_inRecovery && m_currentDrawdownPct >= Recovery_Trigger_DD)
      {
         m_inRecovery = true;
         m_recoveryStartEquity = m_utils.Equity();
         m_utils.Log("RECOVERY MODE ACTIVATED at DD=" + DoubleToString(m_currentDrawdownPct, 2) + "%", LOG_BASIC);
      }
      if(m_inRecovery)
      {
         double gain = ((m_utils.Equity() - m_recoveryStartEquity) / m_recoveryStartEquity) * 100.0;
         if(gain >= Recovery_End_Profit_Pct)
         {
            m_inRecovery = false;
            m_utils.Log("RECOVERY MODE ENDED with " + DoubleToString(gain, 2) + "% gain", LOG_BASIC);
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check position limits                                             |
//+------------------------------------------------------------------+
bool CRiskManager::CheckPositionLimits(int direction)
{
   int totalPos = CountOpenPositions();
   int buyPos = CountBuyPositions();
   int sellPos = CountSellPositions();
   int symbolPos = CountPositionsBySymbol(m_symbol);

   if(totalPos >= Max_Open_Positions) return false;
   if(Max_Total_Positions > 0 && totalPos >= Max_Total_Positions) return false;

   if(direction > 0 && buyPos >= Max_Buy_Positions) return false;
   if(direction < 0 && sellPos >= Max_Sell_Positions) return false;
   if(symbolPos >= Max_Positions_Per_Symbol) return false;

   // No hedging check
   if(!Allow_Hedge)
   {
      if(direction > 0 && sellPos > 0) return false;
      if(direction < 0 && buyPos > 0) return false;
   }

   // One direction only
   if(Only_One_Direction)
   {
      if(direction > 0 && sellPos > 0) return false;
      if(direction < 0 && buyPos > 0) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check margin requirements                                         |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMarginRequirements(double lots)
{
   if(!Check_Margin_Before_Order) return true;

   double freeMargin = m_utils.FreeMargin();

   // Minimum free margin
   if(freeMargin < Min_Free_Margin_USD) return false;

   // Check margin level
   double marginLevel = m_utils.MarginLevel();
   if(marginLevel > 0 && marginLevel < Max_Margin_Level_Pct) return false;

   // Check if enough margin for this trade
   double requiredMargin = 0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, lots, m_utils.GetAsk(), requiredMargin))
   {
      if(requiredMargin * Required_Margin_Buffer > freeMargin) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check minimum time between trades                                 |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMinTimeBetweenTrades()
{
   if(Min_Seconds_Between_Trades <= 0) return true;
   if(m_lastTradeTime == 0) return true;

   return ((TimeCurrent() - m_lastTradeTime) >= Min_Seconds_Between_Trades);
}

//+------------------------------------------------------------------+
//| Check consecutive loss limit                                      |
//+------------------------------------------------------------------+
bool CRiskManager::CheckConsecutiveLossLimit()
{
   if(Max_Consecutive_Losses <= 0) return true;
   if(m_consecutiveLosses < Max_Consecutive_Losses) return true;

   // Check pause duration
   if(Pause_After_Loss_Min > 0 && m_lastLossTime > 0)
   {
      if((TimeCurrent() - m_lastLossTime) >= Pause_After_Loss_Min * 60)
      {
         m_consecutiveLosses = 0; // Reset after pause
         return true;
      }
   }

   m_utils.Log("BLOCKED: Max consecutive losses reached: " + IntegerToString(m_consecutiveLosses), LOG_BASIC);
   return false;
}

//+------------------------------------------------------------------+
//| Check account protection (absolute floor)                         |
//+------------------------------------------------------------------+
bool CRiskManager::CheckAccountProtection()
{
   double equity = m_utils.Equity();

   if(Absolute_Min_Equity > 0 && equity < Absolute_Min_Equity)
   {
      m_utils.Log("BLOCKED: Equity below absolute minimum: " + DoubleToString(equity, 2), LOG_BASIC);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check equity curve trading                                        |
//+------------------------------------------------------------------+
bool CRiskManager::CheckEquityCurveTrading()
{
   if(!Use_Equity_Curve) return true;
   if(m_equityHistorySize < EC_MA_Period) return true;

   // Calculate equity curve MA
   double sum = 0;
   for(int i = m_equityHistorySize - EC_MA_Period; i < m_equityHistorySize; i++)
      sum += m_equityHistory[i];
   double ecMA = sum / EC_MA_Period;

   double currentEquity = m_utils.Equity();

   if(Pause_Below_EC_MA && currentEquity < ecMA)
   {
      m_utils.Log("BLOCKED: Equity below equity curve MA", LOG_DETAIL);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check profit lock                                                 |
//+------------------------------------------------------------------+
bool CRiskManager::CheckProfitLock()
{
   if(!Use_Profit_Lock) return true;

   if(m_dailyPnL > m_dailyPeakProfit)
      m_dailyPeakProfit = m_dailyPnL;

   if(m_dailyPeakProfit >= Profit_Lock_Start_USD)
   {
      double lockedAmount = m_dailyPeakProfit * Profit_Lock_Percent / 100.0;
      if(m_dailyPnL < lockedAmount)
      {
         m_utils.Log("BLOCKED: Profit lock triggered. Locked=" + DoubleToString(lockedAmount, 2), LOG_BASIC);
         return false;
      }
   }

   if(Stop_After_Daily_Target && Max_Daily_Profit_USD > 0 && m_dailyPnL >= Max_Daily_Profit_USD)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check if spread kills the risk-reward ratio                       |
//+------------------------------------------------------------------+
bool CRiskManager::CheckSpreadRR(double slPoints, double tpPoints)
{
   if(!Include_Spread_In_RR) return true;

   double spreadPts = m_utils.GetSpreadPoints();
   double commissionPts = 0;

   if(Factor_Commission && Commission_Per_Lot_RT > 0)
   {
      // Convert commission to points (approximate)
      double tickVal = m_utils.TickValue();
      if(tickVal > 0)
         commissionPts = (Commission_Per_Lot_RT / tickVal) * m_utils.TickSize() / m_utils.Point();
   }

   double effectiveTP = tpPoints - spreadPts - commissionPts;
   double effectiveSL = slPoints + spreadPts;

   if(effectiveSL <= 0) return false;

   double netRR = effectiveTP / effectiveSL;

   if(Skip_If_Spread_Kills_RR && netRR < Min_Net_RR_After_Spread)
   {
      m_utils.Log("BLOCKED: Net R:R after spread too low: " + DoubleToString(netRR, 2), LOG_DETAIL);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get martingale-adjusted lot size                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetMartingaleLot(double baseLot)
{
   if(!Use_Martingale) return baseLot;

   if(m_lastTradeProfit < 0) // Last trade was a loss
   {
      m_martingaleStep++;
      if(m_martingaleStep > Max_Martingale_Steps)
         m_martingaleStep = Max_Martingale_Steps;

      if(Reset_After_Win) {} // Will reset on next win

      return baseLot * MathPow(Martingale_Multiplier, m_martingaleStep);
   }
   else if(m_lastTradeProfit > 0) // Last trade was a win
   {
      if(Reset_After_Win)
         m_martingaleStep = 0;
      return baseLot;
   }

   return baseLot;
}

//+------------------------------------------------------------------+
//| Get recovery mode lot size                                        |
//+------------------------------------------------------------------+
double CRiskManager::GetRecoveryLot(double baseLot)
{
   if(!Use_Recovery_Mode || !m_inRecovery) return baseLot;

   return baseLot * Recovery_Lot_Multiplier;
}

//+------------------------------------------------------------------+
//| Get equity curve adjusted lot                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetEquityCurveLot(double baseLot)
{
   if(!Use_Equity_Curve || !Reduce_Lot_Below_EC) return baseLot;
   if(m_equityHistorySize < EC_MA_Period) return baseLot;

   double sum = 0;
   for(int i = m_equityHistorySize - EC_MA_Period; i < m_equityHistorySize; i++)
      sum += m_equityHistory[i];
   double ecMA = sum / EC_MA_Period;

   if(m_utils.Equity() < ecMA)
      return baseLot * EC_Reduced_Lot_Pct / 100.0;

   return baseLot;
}

//+------------------------------------------------------------------+
//| Get win-streak adjusted lot                                       |
//+------------------------------------------------------------------+
double CRiskManager::GetWinStreakLot(double baseLot)
{
   if(!Reduce_After_Win_Streak) return baseLot;
   if(m_consecutiveWins >= Max_Consecutive_Wins)
      return baseLot * Win_Streak_Lot_Pct / 100.0;
   return baseLot;
}

//+------------------------------------------------------------------+
//| Count all open positions for this EA                              |
//+------------------------------------------------------------------+
int CRiskManager::CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count buy positions                                               |
//+------------------------------------------------------------------+
int CRiskManager::CountBuyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number && m_posInfo.PositionType() == POSITION_TYPE_BUY)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count sell positions                                              |
//+------------------------------------------------------------------+
int CRiskManager::CountSellPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number && m_posInfo.PositionType() == POSITION_TYPE_SELL)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count positions by symbol                                         |
//+------------------------------------------------------------------+
int CRiskManager::CountPositionsBySymbol(string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number && m_posInfo.Symbol() == symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get total unrealized PnL                                          |
//+------------------------------------------------------------------+
double CRiskManager::GetTotalUnrealizedPnL()
{
   double pnl = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number)
            pnl += m_posInfo.Profit() + m_posInfo.Swap() + m_posInfo.Commission();
      }
   }
   return pnl;
}

//+------------------------------------------------------------------+
//| Get basket PnL (all symbols)                                      |
//+------------------------------------------------------------------+
double CRiskManager::GetBasketPnL()
{
   return GetTotalUnrealizedPnL() + m_dailyPnL;
}

//+------------------------------------------------------------------+
//| Calculate daily PnL from history                                  |
//+------------------------------------------------------------------+
void CRiskManager::CalculateDailyPnL()
{
   datetime today = m_utils.GetDayStart();
   datetime tomorrow = today + 86400;

   m_dailyPnL = 0;
   m_dailyTradeCount = 0;

   if(!HistorySelect(today, tomorrow))
      return;

   int totalDeals = HistoryDealsTotal();
   double lastProfit = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == Magic_Number)
      {
         long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                         HistoryDealGetDouble(ticket, DEAL_SWAP) +
                         HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         m_dailyPnL += profit;

         if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            m_dailyTradeCount++;
            lastProfit = profit;
         }
      }
   }

   // Add unrealized
   m_dailyPnL += GetTotalUnrealizedPnL();

   // Update streaks with last closed trade
   if(lastProfit != 0)
      UpdateStreaks(lastProfit);
}

//+------------------------------------------------------------------+
//| Update drawdown tracking                                          |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDrawdown()
{
   double equity = m_utils.Equity();

   if(equity > m_peakEquity)
      m_peakEquity = equity;

   m_currentDrawdown = m_peakEquity - equity;
   m_currentDrawdownPct = (m_peakEquity > 0) ? (m_currentDrawdown / m_peakEquity * 100.0) : 0;
}

//+------------------------------------------------------------------+
//| Update equity curve history                                       |
//+------------------------------------------------------------------+
void CRiskManager::UpdateEquityCurve()
{
   m_equityHistorySize++;
   ArrayResize(m_equityHistory, m_equityHistorySize);
   m_equityHistory[m_equityHistorySize - 1] = m_utils.Equity();

   // Cap array size
   if(m_equityHistorySize > 10000)
   {
      int remove = m_equityHistorySize - 5000;
      for(int i = 0; i < 5000; i++)
         m_equityHistory[i] = m_equityHistory[i + remove];
      m_equityHistorySize = 5000;
      ArrayResize(m_equityHistory, 5000);
   }
}

//+------------------------------------------------------------------+
//| Update win/loss streaks                                           |
//+------------------------------------------------------------------+
void CRiskManager::UpdateStreaks(double lastProfit)
{
   m_lastTradeProfit = lastProfit;
   m_lastTradeTime = TimeCurrent();

   if(lastProfit > 0)
   {
      m_consecutiveWins++;
      m_consecutiveLosses = 0;

      if(Use_Anti_Martingale)
      {
         m_antiMartingaleStep++;
         if(m_antiMartingaleStep > Max_Anti_Martin_Steps)
            m_antiMartingaleStep = Max_Anti_Martin_Steps;
      }
      if(Use_Martingale && Reset_After_Win)
         m_martingaleStep = 0;
   }
   else if(lastProfit < 0)
   {
      m_consecutiveLosses++;
      m_consecutiveWins = 0;
      m_lastLossTime = TimeCurrent();

      if(Use_Martingale)
      {
         m_martingaleStep++;
         if(m_martingaleStep > Max_Martingale_Steps)
            m_martingaleStep = Max_Martingale_Steps;
      }
      if(Use_Anti_Martingale && Reset_After_Loss)
         m_antiMartingaleStep = 0;
   }
}

//+------------------------------------------------------------------+
//| Reset daily counters                                              |
//+------------------------------------------------------------------+
void CRiskManager::ResetDaily()
{
   m_dailyPnL = 0;
   m_dailyTradeCount = 0;
   m_dailyPeakProfit = 0;

   if(Reset_Streak_Daily)
   {
      m_consecutiveLosses = 0;
      m_consecutiveWins = 0;
   }

   m_utils.Log("Daily stats reset", LOG_DETAIL);
}


// ==================================================================
// SOURCE: TradeManager.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                              TradeManager.mqh    |
//|                  HFT Scalper Pro - Trade Execution & Management   |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Position tracking structure                                       |
//+------------------------------------------------------------------+
struct SPositionTrack
{
   ulong    ticket;
   double   openPrice;
   double   initialSL;
   double   initialTP;
   double   initialLots;
   datetime openTime;
   bool     beApplied;        // Break-even applied
   bool     tp1Hit;           // TP1 partial close done
   bool     tp2Hit;           // TP2 partial close done
   bool     tp3Hit;           // TP3 partial close done
   int      pyramidLevel;     // Current pyramid level
   int      averageLevel;     // Average-down level
   int      gridLevel;        // Grid level
};

//+------------------------------------------------------------------+
//| CTradeManager - Handles all trade execution and management        |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CUtils*           m_utils;
   CRiskManager*     m_riskMgr;
   CTrade            m_trade;
   CPositionInfo     m_posInfo;
   string            m_symbol;

   // Position tracking
   SPositionTrack    m_trackedPositions[];
   int               m_trackedCount;

   // Spread tracking for average
   double            m_spreadHistory[];
   int               m_spreadHistorySize;
   double            m_avgSpread;

   // Internal methods
   void              AddTrackedPosition(ulong ticket, double openPrice, double sl, double tp, double lots);
   void              RemoveTrackedPosition(ulong ticket);
   int               FindTrackedIndex(ulong ticket);

   bool              ExecuteMarketBuy(double lots, double sl, double tp);
   bool              ExecuteMarketSell(double lots, double sl, double tp);
   bool              ExecutePendingBuy(double lots, double sl, double tp);
   bool              ExecutePendingSell(double lots, double sl, double tp);

   bool              RetryOrder(bool isBuy, double lots, double price, double sl, double tp, int retries);
   void              SetFillPolicy();

   // SL/TP calculations
   double            CalculateSL(bool isBuy, double entryPrice);
   double            CalculateTP(bool isBuy, double entryPrice);
   double            CalculateTP1(bool isBuy, double entryPrice);
   double            CalculateTP2(bool isBuy, double entryPrice);
   double            CalculateTP3(bool isBuy, double entryPrice);
   double            GetDynamicATR();

   // Position management
   void              ManageTrailingStop(ulong ticket, double openPrice, double currentSL, double currentTP, bool isBuy);
   void              ManageBreakEven(ulong ticket, double openPrice, double currentSL, double currentTP, bool isBuy);
   void              ManagePartialClose(ulong ticket, int trackIdx, bool isBuy);
   void              ManageTimeExpiry(ulong ticket, datetime openTime);
   void              ManageHiddenSLTP(ulong ticket, double openPrice, bool isBuy);

public:
                     CTradeManager();
                    ~CTradeManager();

   bool              Init(CUtils *utils, CRiskManager *riskMgr);

   // Order execution
   bool              OpenBuy(double lots = 0);
   bool              OpenSell(double lots = 0);

   // Position management (called every tick)
   void              ManageOpenPositions();

   // Close operations
   bool              ClosePosition(ulong ticket);
   void              CloseAllPositions();
   void              CloseAllBuyPositions();
   void              CloseAllSellPositions();
   void              CloseAllProfitPositions();
   void              CloseProfitablePositionsEOD();

   // Partial close
   bool              PartialClose(ulong ticket, double percent);

   // Grid operations
   bool              OpenGridOrder(int direction, int gridLevel);

   // Pyramid operations
   bool              OpenPyramidOrder(int direction, ulong parentTicket);

   // Average down
   bool              OpenAverageOrder(int direction, ulong parentTicket);

   // Spread monitoring
   void              UpdateSpreadHistory();
   double            GetAverageSpread() { return m_avgSpread; }
   bool              IsSpreadOK();
   bool              IsSpreadOKForClose();

   // Opposite signal handling
   void              HandleOppositeSignal(int newSignal);

   // Chart objects for trade visualization
   void              DrawTradeArrow(bool isBuy, double price, datetime time);
   void              DrawSLTPLines(ulong ticket, double sl, double tp, double entry);
   void              RemoveTradeObjects(ulong ticket);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_trackedCount = 0;
   m_spreadHistorySize = 0;
   m_avgSpread = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager() {}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CTradeManager::Init(CUtils *utils, CRiskManager *riskMgr)
{
   m_utils = utils;
   m_riskMgr = riskMgr;
   m_symbol = utils.GetTradeSymbol();

   // Configure trade object
   m_trade.SetExpertMagicNumber(Magic_Number);
   m_trade.SetDeviationInPoints(Slippage_Points);
   m_trade.SetAsyncMode(Async_Order_Send);

   SetFillPolicy();

   ArrayResize(m_trackedPositions, 0);
   ArrayResize(m_spreadHistory, 0);

   m_utils.Log("TradeManager initialized", LOG_BASIC);
   return true;
}

//+------------------------------------------------------------------+
//| Set fill policy based on settings                                 |
//+------------------------------------------------------------------+
void CTradeManager::SetFillPolicy()
{
   switch(Order_Fill_Policy)
   {
      case FILL_FOK:
         m_trade.SetTypeFilling(ORDER_FILLING_FOK);
         break;
      case FILL_IOC:
         m_trade.SetTypeFilling(ORDER_FILLING_IOC);
         break;
      case FILL_RETURN:
         m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
         break;
   }
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                 |
//+------------------------------------------------------------------+
bool CTradeManager::OpenBuy(double lots = 0)
{
   double ask = m_utils.GetAsk();
   double sl = CalculateSL(true, ask);
   double tp = (Use_Hidden_TP) ? 0 : CalculateTP(true, ask);
   double slForLot = (Use_Hidden_SL) ? 0 : sl;

   // Calculate lot size if not provided
   double slDistance = MathAbs(ask - CalculateSL(true, ask));
   if(lots <= 0)
      lots = m_utils.CalculateLotSize(m_utils.PriceToPoints(slDistance));

   // Apply lot modifiers
   if(Use_Martingale)
      lots = m_riskMgr.GetMartingaleLot(lots);
   if(Use_Recovery_Mode && m_riskMgr.IsInRecovery())
      lots = m_riskMgr.GetRecoveryLot(lots);
   if(Use_Equity_Curve)
      lots = m_riskMgr.GetEquityCurveLot(lots);
   if(Reduce_After_Win_Streak)
      lots = m_riskMgr.GetWinStreakLot(lots);

   lots = m_utils.NormalizeLots(lots);

   // Pre-trade checks
   if(!m_riskMgr.CheckPositionLimits(1)) return false;
   if(!m_riskMgr.CheckMarginRequirements(lots)) return false;
   if(!m_riskMgr.CheckSpreadRR(m_utils.PriceToPoints(slDistance), m_utils.PriceToPoints(MathAbs(CalculateTP(true, ask) - ask)))) return false;

   // Validate SL/TP against stop levels
   if(sl != 0) sl = m_utils.ValidateSL(ask, sl, true);
   if(tp != 0) tp = m_utils.ValidateTP(ask, tp, true);

   // Execute
   bool success;
   if(Use_Pending_Orders)
      success = ExecutePendingBuy(lots, (Use_Hidden_SL ? 0 : sl), tp);
   else
      success = ExecuteMarketBuy(lots, (Use_Hidden_SL ? 0 : sl), tp);

   if(success)
   {
      ulong ticket = m_trade.ResultOrder();
      AddTrackedPosition(ticket, ask, CalculateSL(true, ask), CalculateTP(true, ask), lots);

      if(Show_Signal_Arrows) DrawTradeArrow(true, ask, TimeCurrent());
      if(Show_SL_TP_Lines) DrawSLTPLines(ticket, sl, CalculateTP(true, ask), ask);

      if(Alert_On_Open)
         m_utils.SendAlert("BUY opened: " + DoubleToString(lots, 2) + " lots @ " + DoubleToString(ask, m_utils.Digits()));

      m_utils.Log("BUY opened: Lots=" + DoubleToString(lots, 2) +
                  " Ask=" + DoubleToString(ask, m_utils.Digits()) +
                  " SL=" + DoubleToString(sl, m_utils.Digits()) +
                  " TP=" + DoubleToString(tp, m_utils.Digits()), LOG_BASIC);
   }
   else
   {
      m_utils.Log("BUY FAILED: Error=" + IntegerToString(GetLastError()) +
                  " RetCode=" + IntegerToString(m_trade.ResultRetcode()), LOG_BASIC);
   }

   return success;
}

//+------------------------------------------------------------------+
//| Open Sell Position                                                |
//+------------------------------------------------------------------+
bool CTradeManager::OpenSell(double lots = 0)
{
   double bid = m_utils.GetBid();
   double sl = CalculateSL(false, bid);
   double tp = (Use_Hidden_TP) ? 0 : CalculateTP(false, bid);
   double slForLot = (Use_Hidden_SL) ? 0 : sl;

   double slDistance = MathAbs(bid - CalculateSL(false, bid));
   if(lots <= 0)
      lots = m_utils.CalculateLotSize(m_utils.PriceToPoints(slDistance));

   // Apply lot modifiers
   if(Use_Martingale)
      lots = m_riskMgr.GetMartingaleLot(lots);
   if(Use_Recovery_Mode && m_riskMgr.IsInRecovery())
      lots = m_riskMgr.GetRecoveryLot(lots);
   if(Use_Equity_Curve)
      lots = m_riskMgr.GetEquityCurveLot(lots);
   if(Reduce_After_Win_Streak)
      lots = m_riskMgr.GetWinStreakLot(lots);

   lots = m_utils.NormalizeLots(lots);

   if(!m_riskMgr.CheckPositionLimits(-1)) return false;
   if(!m_riskMgr.CheckMarginRequirements(lots)) return false;
   if(!m_riskMgr.CheckSpreadRR(m_utils.PriceToPoints(slDistance), m_utils.PriceToPoints(MathAbs(bid - CalculateTP(false, bid))))) return false;

   if(sl != 0) sl = m_utils.ValidateSL(bid, sl, false);
   if(tp != 0) tp = m_utils.ValidateTP(bid, tp, false);

   bool success;
   if(Use_Pending_Orders)
      success = ExecutePendingSell(lots, (Use_Hidden_SL ? 0 : sl), tp);
   else
      success = ExecuteMarketSell(lots, (Use_Hidden_SL ? 0 : sl), tp);

   if(success)
   {
      ulong ticket = m_trade.ResultOrder();
      AddTrackedPosition(ticket, bid, CalculateSL(false, bid), CalculateTP(false, bid), lots);

      if(Show_Signal_Arrows) DrawTradeArrow(false, bid, TimeCurrent());
      if(Show_SL_TP_Lines) DrawSLTPLines(ticket, sl, CalculateTP(false, bid), bid);

      if(Alert_On_Open)
         m_utils.SendAlert("SELL opened: " + DoubleToString(lots, 2) + " lots @ " + DoubleToString(bid, m_utils.Digits()));

      m_utils.Log("SELL opened: Lots=" + DoubleToString(lots, 2) +
                  " Bid=" + DoubleToString(bid, m_utils.Digits()) +
                  " SL=" + DoubleToString(sl, m_utils.Digits()) +
                  " TP=" + DoubleToString(tp, m_utils.Digits()), LOG_BASIC);
   }
   else
   {
      m_utils.Log("SELL FAILED: Error=" + IntegerToString(GetLastError()) +
                  " RetCode=" + IntegerToString(m_trade.ResultRetcode()), LOG_BASIC);
   }

   return success;
}

//+------------------------------------------------------------------+
//| Execute market buy with retry logic                               |
//+------------------------------------------------------------------+
bool CTradeManager::ExecuteMarketBuy(double lots, double sl, double tp)
{
   return RetryOrder(true, lots, m_utils.GetAsk(), sl, tp, Max_Retry_Attempts);
}

//+------------------------------------------------------------------+
//| Execute market sell with retry logic                              |
//+------------------------------------------------------------------+
bool CTradeManager::ExecuteMarketSell(double lots, double sl, double tp)
{
   return RetryOrder(false, lots, m_utils.GetBid(), sl, tp, Max_Retry_Attempts);
}

//+------------------------------------------------------------------+
//| Execute pending buy                                               |
//+------------------------------------------------------------------+
bool CTradeManager::ExecutePendingBuy(double lots, double sl, double tp)
{
   double ask = m_utils.GetAsk();
   double entryPrice = m_utils.NormalizePrice(ask - Pending_Offset_Points * m_utils.Point());
   datetime expiry = TimeCurrent() + PeriodSeconds(Signal_TF) * Pending_Expiry_Bars;

   return m_trade.BuyLimit(lots, entryPrice, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiry, Order_Comment);
}

//+------------------------------------------------------------------+
//| Execute pending sell                                              |
//+------------------------------------------------------------------+
bool CTradeManager::ExecutePendingSell(double lots, double sl, double tp)
{
   double bid = m_utils.GetBid();
   double entryPrice = m_utils.NormalizePrice(bid + Pending_Offset_Points * m_utils.Point());
   datetime expiry = TimeCurrent() + PeriodSeconds(Signal_TF) * Pending_Expiry_Bars;

   return m_trade.SellLimit(lots, entryPrice, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiry, Order_Comment);
}

//+------------------------------------------------------------------+
//| Retry order execution                                             |
//+------------------------------------------------------------------+
bool CTradeManager::RetryOrder(bool isBuy, double lots, double price, double sl, double tp, int retries)
{
   for(int attempt = 0; attempt <= retries; attempt++)
   {
      bool result;
      if(isBuy)
         result = m_trade.Buy(lots, m_symbol, 0, sl, tp, Order_Comment);
      else
         result = m_trade.Sell(lots, m_symbol, 0, sl, tp, Order_Comment);

      if(result)
      {
         uint retCode = m_trade.ResultRetcode();
         if(retCode == TRADE_RETCODE_DONE || retCode == TRADE_RETCODE_PLACED)
            return true;
      }

      if(attempt < retries)
      {
         m_utils.Log("Order retry " + IntegerToString(attempt + 1) + "/" + IntegerToString(retries) +
                     " Error=" + IntegerToString(GetLastError()), LOG_DETAIL);
         Sleep(Retry_Delay_MS);
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                               |
//+------------------------------------------------------------------+
double CTradeManager::CalculateSL(bool isBuy, double entryPrice)
{
   double slDistance;

   if(Use_Dynamic_SL)
   {
      double atr = GetDynamicATR();
      slDistance = atr * ATR_SL_Multiplier;
   }
   else
   {
      slDistance = Stop_Loss_Points * m_utils.Point();
   }

   // Clamp SL to min/max
   double minSL = Min_SL_Points * m_utils.Point();
   double maxSL = Max_SL_Points * m_utils.Point();
   slDistance = MathMax(slDistance, minSL);
   slDistance = MathMin(slDistance, maxSL);

   if(isBuy)
      return m_utils.NormalizePrice(entryPrice - slDistance);
   else
      return m_utils.NormalizePrice(entryPrice + slDistance);
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                             |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTP(bool isBuy, double entryPrice)
{
   double tpDistance;

   if(Use_Dynamic_TP)
   {
      double atr = GetDynamicATR();
      tpDistance = atr * ATR_TP_Multiplier;
   }
   else
   {
      tpDistance = Take_Profit_Points * m_utils.Point();
   }

   if(isBuy)
      return m_utils.NormalizePrice(entryPrice + tpDistance);
   else
      return m_utils.NormalizePrice(entryPrice - tpDistance);
}

//+------------------------------------------------------------------+
//| Calculate TP1 (partial close target)                              |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTP1(bool isBuy, double entryPrice)
{
   double dist = TP1_Points * m_utils.Point();
   return isBuy ? m_utils.NormalizePrice(entryPrice + dist) : m_utils.NormalizePrice(entryPrice - dist);
}

//+------------------------------------------------------------------+
//| Calculate TP2                                                     |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTP2(bool isBuy, double entryPrice)
{
   double dist = TP2_Points * m_utils.Point();
   return isBuy ? m_utils.NormalizePrice(entryPrice + dist) : m_utils.NormalizePrice(entryPrice - dist);
}

//+------------------------------------------------------------------+
//| Calculate TP3                                                     |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTP3(bool isBuy, double entryPrice)
{
   double dist = TP3_Points * m_utils.Point();
   return isBuy ? m_utils.NormalizePrice(entryPrice + dist) : m_utils.NormalizePrice(entryPrice - dist);
}

//+------------------------------------------------------------------+
//| Get ATR value for dynamic SL/TP                                   |
//+------------------------------------------------------------------+
double CTradeManager::GetDynamicATR()
{
   int handle = iATR(m_symbol, ATR_Timeframe, ATR_Period);
   if(handle == INVALID_HANDLE) return Stop_Loss_Points * m_utils.Point();

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handle, 0, 0, 1, atr) < 1)
   {
      IndicatorRelease(handle);
      return Stop_Loss_Points * m_utils.Point();
   }
   IndicatorRelease(handle);

   return atr[0];
}

//+------------------------------------------------------------------+
//| Manage all open positions                                         |
//+------------------------------------------------------------------+
void CTradeManager::ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_posInfo.SelectByIndex(i)) continue;
      if(m_posInfo.Magic() != Magic_Number) continue;

      // Optionally manage manual trades
      if(!Allow_Manual_Trades && m_posInfo.Magic() == 0) continue;
      if(Manage_Manual_Trades && m_posInfo.Magic() == Manual_Magic_Number) {} // Allow
      else if(m_posInfo.Magic() != Magic_Number) continue;

      ulong ticket = m_posInfo.Ticket();
      double openPrice = m_posInfo.PriceOpen();
      double currentSL = m_posInfo.StopLoss();
      double currentTP = m_posInfo.TakeProfit();
      datetime openTime = m_posInfo.Time();
      bool isBuy = (m_posInfo.PositionType() == POSITION_TYPE_BUY);

      // Find tracked position index
      int trackIdx = FindTrackedIndex(ticket);

      // Hidden SL/TP management
      if(Use_Hidden_SL || Use_Hidden_TP)
         ManageHiddenSLTP(ticket, openPrice, isBuy);

      // Break-even
      if(Use_BreakEven)
         ManageBreakEven(ticket, openPrice, currentSL, currentTP, isBuy);

      // Trailing stop
      if(Use_Trailing_Stop)
         ManageTrailingStop(ticket, openPrice, currentSL, currentTP, isBuy);

      // Partial close (multi-TP)
      if(trackIdx >= 0 && (TP1_Points > 0 || TP2_Points > 0 || TP3_Points > 0))
         ManagePartialClose(ticket, trackIdx, isBuy);

      // Time expiry
      if(Close_On_Time_Expiry)
         ManageTimeExpiry(ticket, openTime);

      // Min trade duration check for close operations
      if(Min_Trade_Duration_Sec > 0)
      {
         if((TimeCurrent() - openTime) < Min_Trade_Duration_Sec)
            continue; // Don't close yet
      }

      // Spread spike close
      if(Close_On_Spread_Spike)
      {
         if(m_utils.GetSpreadPoints() > Spread_Spike_Close_Pts)
         {
            m_utils.Log("Closing #" + IntegerToString(ticket) + " due to spread spike", LOG_DETAIL);
            ClosePosition(ticket);
         }
      }
   }

   // Basket management
   if(Multi_Symbol_Mode)
   {
      double basketPnL = m_riskMgr.GetBasketPnL();
      if(Basket_TP_USD > 0 && basketPnL >= Basket_TP_USD)
      {
         m_utils.Log("Basket TP hit: " + DoubleToString(basketPnL, 2), LOG_BASIC);
         CloseAllPositions();
      }
      if(Basket_SL_USD > 0 && basketPnL <= -Basket_SL_USD)
      {
         m_utils.Log("Basket SL hit: " + DoubleToString(basketPnL, 2), LOG_BASIC);
         CloseAllPositions();
      }
   }
}

//+------------------------------------------------------------------+
//| Manage trailing stop                                              |
//+------------------------------------------------------------------+
void CTradeManager::ManageTrailingStop(ulong ticket, double openPrice, double currentSL, double currentTP, bool isBuy)
{
   double trailDist;
   if(Use_ATR_Trail)
   {
      double atr = GetDynamicATR();
      trailDist = atr * ATR_Trail_Multiplier;
   }
   else
   {
      trailDist = Trail_Distance_Points * m_utils.Point();
   }

   double trailStart = Trail_Start_Points * m_utils.Point();
   double trailStep = Trail_Step_Points * m_utils.Point();

   if(isBuy)
   {
      double bid = m_utils.GetBid();
      double profit = bid - openPrice;

      if(profit < trailStart) return; // Not enough profit to start trailing

      double newSL = m_utils.NormalizePrice(bid - trailDist);

      // Only move SL if it's better and meets step requirement
      if(newSL > currentSL + trailStep && newSL > openPrice)
      {
         newSL = m_utils.ValidateSL(bid, newSL, true);
         if(m_trade.PositionModify(ticket, newSL, currentTP))
            m_utils.Log("BUY #" + IntegerToString(ticket) + " trail SL -> " + DoubleToString(newSL, m_utils.Digits()), LOG_DETAIL);
      }
   }
   else
   {
      double ask = m_utils.GetAsk();
      double profit = openPrice - ask;

      if(profit < trailStart) return;

      double newSL = m_utils.NormalizePrice(ask + trailDist);

      if((newSL < currentSL - trailStep || currentSL == 0) && newSL < openPrice)
      {
         newSL = m_utils.ValidateSL(ask, newSL, false);
         if(m_trade.PositionModify(ticket, newSL, currentTP))
            m_utils.Log("SELL #" + IntegerToString(ticket) + " trail SL -> " + DoubleToString(newSL, m_utils.Digits()), LOG_DETAIL);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage break-even                                                 |
//+------------------------------------------------------------------+
void CTradeManager::ManageBreakEven(ulong ticket, double openPrice, double currentSL, double currentTP, bool isBuy)
{
   int trackIdx = FindTrackedIndex(ticket);
   if(trackIdx >= 0 && m_trackedPositions[trackIdx].beApplied) return; // Already applied

   double beActivation = BE_Activation_Points * m_utils.Point();
   double beOffset = BE_Offset_Points * m_utils.Point();

   if(isBuy)
   {
      double bid = m_utils.GetBid();
      if(bid >= openPrice + beActivation && currentSL < openPrice)
      {
         double newSL = m_utils.NormalizePrice(openPrice + beOffset);
         newSL = m_utils.ValidateSL(bid, newSL, true);
         if(m_trade.PositionModify(ticket, newSL, currentTP))
         {
            if(trackIdx >= 0) m_trackedPositions[trackIdx].beApplied = true;
            m_utils.Log("BUY #" + IntegerToString(ticket) + " moved to break-even", LOG_DETAIL);
         }
      }
   }
   else
   {
      double ask = m_utils.GetAsk();
      if(ask <= openPrice - beActivation && (currentSL > openPrice || currentSL == 0))
      {
         double newSL = m_utils.NormalizePrice(openPrice - beOffset);
         newSL = m_utils.ValidateSL(ask, newSL, false);
         if(m_trade.PositionModify(ticket, newSL, currentTP))
         {
            if(trackIdx >= 0) m_trackedPositions[trackIdx].beApplied = true;
            m_utils.Log("SELL #" + IntegerToString(ticket) + " moved to break-even", LOG_DETAIL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage partial close at TP levels                                 |
//+------------------------------------------------------------------+
void CTradeManager::ManagePartialClose(ulong ticket, int trackIdx, bool isBuy)
{
   if(trackIdx < 0 || trackIdx >= m_trackedCount) return;

   double currentPrice = isBuy ? m_utils.GetBid() : m_utils.GetAsk();
   double openPrice = m_trackedPositions[trackIdx].openPrice;

   // TP1
   if(!m_trackedPositions[trackIdx].tp1Hit && TP1_Points > 0 && TP1_Close_Percent > 0)
   {
      double tp1Price = CalculateTP1(isBuy, openPrice);
      bool tp1Reached = isBuy ? (currentPrice >= tp1Price) : (currentPrice <= tp1Price);

      if(tp1Reached)
      {
         if(PartialClose(ticket, TP1_Close_Percent))
         {
            m_trackedPositions[trackIdx].tp1Hit = true;
            m_utils.Log("#" + IntegerToString(ticket) + " TP1 hit, closed " + DoubleToString(TP1_Close_Percent, 0) + "%", LOG_BASIC);

            // Move to BE after TP1 if configured
            if(BE_After_TP1 && !m_trackedPositions[trackIdx].beApplied)
            {
               m_posInfo.SelectByTicket(ticket);
               double newSL = m_utils.NormalizePrice(openPrice + BE_Offset_Points * m_utils.Point() * (isBuy ? 1 : -1));
               m_trade.PositionModify(ticket, newSL, m_posInfo.TakeProfit());
               m_trackedPositions[trackIdx].beApplied = true;
            }
         }
      }
   }

   // TP2
   if(m_trackedPositions[trackIdx].tp1Hit && !m_trackedPositions[trackIdx].tp2Hit && TP2_Points > 0 && TP2_Close_Percent > 0)
   {
      double tp2Price = CalculateTP2(isBuy, openPrice);
      bool tp2Reached = isBuy ? (currentPrice >= tp2Price) : (currentPrice <= tp2Price);

      if(tp2Reached)
      {
         if(PartialClose(ticket, TP2_Close_Percent))
         {
            m_trackedPositions[trackIdx].tp2Hit = true;
            m_utils.Log("#" + IntegerToString(ticket) + " TP2 hit, closed " + DoubleToString(TP2_Close_Percent, 0) + "%", LOG_BASIC);
         }
      }
   }

   // TP3
   if(m_trackedPositions[trackIdx].tp2Hit && !m_trackedPositions[trackIdx].tp3Hit && TP3_Points > 0 && TP3_Close_Percent > 0)
   {
      double tp3Price = CalculateTP3(isBuy, openPrice);
      bool tp3Reached = isBuy ? (currentPrice >= tp3Price) : (currentPrice <= tp3Price);

      if(tp3Reached)
      {
         ClosePosition(ticket); // Close remaining
         m_trackedPositions[trackIdx].tp3Hit = true;
         m_utils.Log("#" + IntegerToString(ticket) + " TP3 hit, fully closed", LOG_BASIC);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage time-based exit                                            |
//+------------------------------------------------------------------+
void CTradeManager::ManageTimeExpiry(ulong ticket, datetime openTime)
{
   int maxSeconds = Max_Trade_Duration_Min * 60 + Max_Trade_Duration_Sec;
   if(maxSeconds <= 0) return;

   if((TimeCurrent() - openTime) >= maxSeconds)
   {
      m_utils.Log("#" + IntegerToString(ticket) + " closed due to time expiry", LOG_DETAIL);
      ClosePosition(ticket);
   }
}

//+------------------------------------------------------------------+
//| Manage hidden SL/TP (EA-managed, not on broker)                   |
//+------------------------------------------------------------------+
void CTradeManager::ManageHiddenSLTP(ulong ticket, double openPrice, bool isBuy)
{
   int trackIdx = FindTrackedIndex(ticket);
   if(trackIdx < 0) return;

   double currentPrice = isBuy ? m_utils.GetBid() : m_utils.GetAsk();

   // Hidden SL
   if(Use_Hidden_SL)
   {
      if(isBuy && currentPrice <= m_trackedPositions[trackIdx].initialSL)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden SL hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
      if(!isBuy && currentPrice >= m_trackedPositions[trackIdx].initialSL)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden SL hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
   }

   // Hidden TP
   if(Use_Hidden_TP)
   {
      if(isBuy && currentPrice >= m_trackedPositions[trackIdx].initialTP)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden TP hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
      if(!isBuy && currentPrice <= m_trackedPositions[trackIdx].initialTP)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden TP hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Close a single position                                           |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(ulong ticket)
{
   if(m_trade.PositionClose(ticket, Slippage_Points))
   {
      RemoveTrackedPosition(ticket);
      if(!Stealth_Mode) RemoveTradeObjects(ticket);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CTradeManager::CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number)
            ClosePosition(m_posInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Close all buy positions                                           |
//+------------------------------------------------------------------+
void CTradeManager::CloseAllBuyPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number && m_posInfo.PositionType() == POSITION_TYPE_BUY)
            ClosePosition(m_posInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Close all sell positions                                          |
//+------------------------------------------------------------------+
void CTradeManager::CloseAllSellPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number && m_posInfo.PositionType() == POSITION_TYPE_SELL)
            ClosePosition(m_posInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Close all profitable positions                                    |
//+------------------------------------------------------------------+
void CTradeManager::CloseAllProfitPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == Magic_Number && m_posInfo.Profit() > 0)
            ClosePosition(m_posInfo.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Close profitable positions at end of day                          |
//+------------------------------------------------------------------+
void CTradeManager::CloseProfitablePositionsEOD()
{
   if(!Close_Profit_EOD) return;
   if(!m_utils.IsTimeBetween(EOD_Close_Time, EOD_Close_Time)) return;

   CloseAllProfitPositions();
}

//+------------------------------------------------------------------+
//| Partial close a position                                          |
//+------------------------------------------------------------------+
bool CTradeManager::PartialClose(ulong ticket, double percent)
{
   if(!m_posInfo.SelectByTicket(ticket)) return false;

   double currentLots = m_posInfo.Volume();
   double closeLots = m_utils.NormalizeLots(currentLots * percent / 100.0);

   if(closeLots < m_utils.LotsMin()) closeLots = m_utils.LotsMin();
   if(closeLots >= currentLots) return ClosePosition(ticket);

   return m_trade.PositionClosePartial(ticket, closeLots, Slippage_Points);
}

//+------------------------------------------------------------------+
//| Handle opposite signal (close existing trades)                    |
//+------------------------------------------------------------------+
void CTradeManager::HandleOppositeSignal(int newSignal)
{
   if(!Close_On_Opposite_Signal) return;

   if(newSignal > 0)
      CloseAllSellPositions();
   else if(newSignal < 0)
      CloseAllBuyPositions();
}

//+------------------------------------------------------------------+
//| Open grid order                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::OpenGridOrder(int direction, int gridLevel)
{
   if(!Use_Grid || gridLevel >= Max_Grid_Orders) return false;

   double lots = m_utils.NormalizeLots(Fixed_Lot * MathPow(Grid_Lot_Multiplier, gridLevel));

   if(direction > 0)
      return OpenBuy(lots);
   else
      return OpenSell(lots);
}

//+------------------------------------------------------------------+
//| Open pyramid order                                                |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPyramidOrder(int direction, ulong parentTicket)
{
   if(!Use_Pyramid) return false;

   int parentIdx = FindTrackedIndex(parentTicket);
   if(parentIdx < 0) return false;
   if(m_trackedPositions[parentIdx].pyramidLevel >= Max_Pyramid_Levels) return false;

   double lots = m_utils.NormalizeLots(m_trackedPositions[parentIdx].initialLots * MathPow(Pyramid_Lot_Ratio, m_trackedPositions[parentIdx].pyramidLevel + 1));

   bool success;
   if(direction > 0)
      success = OpenBuy(lots);
   else
      success = OpenSell(lots);

   if(success)
      m_trackedPositions[parentIdx].pyramidLevel++;

   return success;
}

//+------------------------------------------------------------------+
//| Open averaging order                                              |
//+------------------------------------------------------------------+
bool CTradeManager::OpenAverageOrder(int direction, ulong parentTicket)
{
   if(!Use_Average_Down) return false;

   int parentIdx = FindTrackedIndex(parentTicket);
   if(parentIdx < 0) return false;
   if(m_trackedPositions[parentIdx].averageLevel >= Max_Average_Levels) return false;

   double lots = m_utils.NormalizeLots(m_trackedPositions[parentIdx].initialLots * MathPow(Average_Lot_Multiplier, m_trackedPositions[parentIdx].averageLevel + 1));

   bool success;
   if(direction > 0)
      success = OpenBuy(lots);
   else
      success = OpenSell(lots);

   if(success)
      m_trackedPositions[parentIdx].averageLevel++;

   return success;
}

//+------------------------------------------------------------------+
//| Update spread history                                             |
//+------------------------------------------------------------------+
void CTradeManager::UpdateSpreadHistory()
{
   double spread = m_utils.GetSpreadPoints();

   m_spreadHistorySize++;
   ArrayResize(m_spreadHistory, m_spreadHistorySize);
   m_spreadHistory[m_spreadHistorySize - 1] = spread;

   // Keep only last N entries
   int maxSize = Spread_Average_Bars > 0 ? Spread_Average_Bars : 20;
   if(m_spreadHistorySize > maxSize)
   {
      int remove = m_spreadHistorySize - maxSize;
      for(int i = 0; i < maxSize; i++)
         m_spreadHistory[i] = m_spreadHistory[i + remove];
      m_spreadHistorySize = maxSize;
      ArrayResize(m_spreadHistory, maxSize);
   }

   // Calculate average
   m_avgSpread = 0;
   for(int i = 0; i < m_spreadHistorySize; i++)
      m_avgSpread += m_spreadHistory[i];
   if(m_spreadHistorySize > 0)
      m_avgSpread /= m_spreadHistorySize;
}

//+------------------------------------------------------------------+
//| Check if spread is OK to open                                     |
//+------------------------------------------------------------------+
bool CTradeManager::IsSpreadOK()
{
   double spread = m_utils.GetSpreadPoints();

   if(spread > Max_Spread_Points)
   {
      if(Pause_On_High_Spread) return false;
   }

   if(Use_Spread_Average && m_avgSpread > 0)
   {
      if(spread > m_avgSpread * Spread_Avg_Multiplier) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if spread is OK to close                                    |
//+------------------------------------------------------------------+
bool CTradeManager::IsSpreadOKForClose()
{
   return (m_utils.GetSpreadPoints() <= Max_Spread_Close);
}

//+------------------------------------------------------------------+
//| Track position internally                                         |
//+------------------------------------------------------------------+
void CTradeManager::AddTrackedPosition(ulong ticket, double openPrice, double sl, double tp, double lots)
{
   m_trackedCount++;
   ArrayResize(m_trackedPositions, m_trackedCount);

   int idx = m_trackedCount - 1;
   m_trackedPositions[idx].ticket = ticket;
   m_trackedPositions[idx].openPrice = openPrice;
   m_trackedPositions[idx].initialSL = sl;
   m_trackedPositions[idx].initialTP = tp;
   m_trackedPositions[idx].initialLots = lots;
   m_trackedPositions[idx].openTime = TimeCurrent();
   m_trackedPositions[idx].beApplied = false;
   m_trackedPositions[idx].tp1Hit = false;
   m_trackedPositions[idx].tp2Hit = false;
   m_trackedPositions[idx].tp3Hit = false;
   m_trackedPositions[idx].pyramidLevel = 0;
   m_trackedPositions[idx].averageLevel = 0;
   m_trackedPositions[idx].gridLevel = 0;
}

//+------------------------------------------------------------------+
//| Remove tracked position                                           |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTrackedPosition(ulong ticket)
{
   int idx = FindTrackedIndex(ticket);
   if(idx < 0) return;

   for(int i = idx; i < m_trackedCount - 1; i++)
      m_trackedPositions[i] = m_trackedPositions[i + 1];

   m_trackedCount--;
   ArrayResize(m_trackedPositions, m_trackedCount);
}

//+------------------------------------------------------------------+
//| Find tracked position index                                       |
//+------------------------------------------------------------------+
int CTradeManager::FindTrackedIndex(ulong ticket)
{
   for(int i = 0; i < m_trackedCount; i++)
   {
      if(m_trackedPositions[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Draw trade arrow on chart                                         |
//+------------------------------------------------------------------+
void CTradeManager::DrawTradeArrow(bool isBuy, double price, datetime time)
{
   if(Stealth_Mode) return;

   string name = "HFT_Arrow_" + IntegerToString(time) + "_" + (isBuy ? "B" : "S");
   int arrowCode = isBuy ? 233 : 234;
   color arrowColor = isBuy ? Buy_Arrow_Color : Sell_Arrow_Color;

   ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, Arrow_Size);
}

//+------------------------------------------------------------------+
//| Draw SL/TP lines                                                  |
//+------------------------------------------------------------------+
void CTradeManager::DrawSLTPLines(ulong ticket, double sl, double tp, double entry)
{
   if(Stealth_Mode) return;

   string prefix = "HFT_" + IntegerToString(ticket) + "_";

   if(Show_Entry_Line && entry > 0)
   {
      ObjectCreate(0, prefix + "Entry", OBJ_HLINE, 0, 0, entry);
      ObjectSetInteger(0, prefix + "Entry", OBJPROP_COLOR, Entry_Line_Color);
      ObjectSetInteger(0, prefix + "Entry", OBJPROP_WIDTH, Line_Width);
      ObjectSetInteger(0, prefix + "Entry", OBJPROP_STYLE, Line_Style);
   }

   if(sl > 0)
   {
      ObjectCreate(0, prefix + "SL", OBJ_HLINE, 0, 0, sl);
      ObjectSetInteger(0, prefix + "SL", OBJPROP_COLOR, SL_Line_Color);
      ObjectSetInteger(0, prefix + "SL", OBJPROP_WIDTH, Line_Width);
      ObjectSetInteger(0, prefix + "SL", OBJPROP_STYLE, Line_Style);
   }

   if(tp > 0)
   {
      ObjectCreate(0, prefix + "TP", OBJ_HLINE, 0, 0, tp);
      ObjectSetInteger(0, prefix + "TP", OBJPROP_COLOR, TP_Line_Color);
      ObjectSetInteger(0, prefix + "TP", OBJPROP_WIDTH, Line_Width);
      ObjectSetInteger(0, prefix + "TP", OBJPROP_STYLE, Line_Style);
   }
}

//+------------------------------------------------------------------+
//| Remove trade objects from chart                                   |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTradeObjects(ulong ticket)
{
   if(!Delete_Objects_On_Remove) return;

   string prefix = "HFT_" + IntegerToString(ticket) + "_";
   ObjectDelete(0, prefix + "Entry");
   ObjectDelete(0, prefix + "SL");
   ObjectDelete(0, prefix + "TP");
}


// ==================================================================
// SOURCE: SessionFilter.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                             SessionFilter.mqh    |
//|              HFT Scalper Pro - Session, Time & News Filters       |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| News event structure                                              |
//+------------------------------------------------------------------+
struct SNewsEvent
{
   datetime time;
   string   currency;
   string   impact;     // "High", "Medium", "Low"
   string   title;
};

//+------------------------------------------------------------------+
//| CSessionFilter - Time, session, day, and news filters             |
//+------------------------------------------------------------------+
class CSessionFilter
{
private:
   CUtils*           m_utils;
   SNewsEvent        m_newsEvents[];
   int               m_newsCount;
   datetime          m_lastNewsUpdate;
   bool              m_newsLoaded;

   // Gap tracking
   int               m_barsAfterGap;

   // Spike tracking
   int               m_barsAfterSpike;

public:
                     CSessionFilter();
                    ~CSessionFilter();

   bool              Init(CUtils *utils);

   // Master filter check
   bool              CanTrade();

   // Individual checks
   bool              IsSessionActive();
   bool              IsDayAllowed();
   bool              IsNotInNoTradeZone();
   bool              IsNotNearNews();
   bool              IsNotSwapTime();
   bool              IsNotEODBlock();
   bool              IsNotWeekendClose();
   bool              IsNotFridayCloseTime();

   // Session detection
   bool              IsTokyoSession();
   bool              IsLondonSession();
   bool              IsNYSession();
   bool              IsOverlapSession();
   string            GetCurrentSession();

   // News management
   void              LoadNewsEvents();
   bool              IsNewsTime();
   int               GetMinutesToNextNews();

   // Gap/spike cooldown
   void              OnGapDetected()   { m_barsAfterGap = 0; }
   void              OnSpikeDetected() { m_barsAfterSpike = 0; }
   void              OnNewBar();
   bool              IsGapCooldown();
   bool              IsSpikeCooldown();

   // EOD operations
   bool              ShouldCloseAllEOD();
   bool              ShouldCloseProfitEOD();
   bool              ShouldCloseForWeekend();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSessionFilter::CSessionFilter()
{
   m_newsCount = 0;
   m_lastNewsUpdate = 0;
   m_newsLoaded = false;
   m_barsAfterGap = 999;
   m_barsAfterSpike = 999;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSessionFilter::~CSessionFilter() {}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CSessionFilter::Init(CUtils *utils)
{
   m_utils = utils;

   if(Use_News_Filter)
      LoadNewsEvents();

   m_utils.Log("SessionFilter initialized", LOG_BASIC);
   return true;
}

//+------------------------------------------------------------------+
//| Master filter: check all session/time conditions                  |
//+------------------------------------------------------------------+
bool CSessionFilter::CanTrade()
{
   if(!IsDayAllowed())
   {
      m_utils.Log("BLOCKED: Day not allowed", LOG_VERBOSE);
      return false;
   }

   if(Use_Time_Filter && !IsSessionActive())
   {
      m_utils.Log("BLOCKED: Outside trading session", LOG_VERBOSE);
      return false;
   }

   if(!IsNotInNoTradeZone())
   {
      m_utils.Log("BLOCKED: In no-trade zone", LOG_VERBOSE);
      return false;
   }

   if(Use_News_Filter && !IsNotNearNews())
   {
      m_utils.Log("BLOCKED: Near news event", LOG_DETAIL);
      return false;
   }

   if(Avoid_Swap_Time && !IsNotSwapTime())
   {
      m_utils.Log("BLOCKED: Swap time avoidance", LOG_VERBOSE);
      return false;
   }

   if(No_New_Trades_EOD && !IsNotEODBlock())
   {
      m_utils.Log("BLOCKED: EOD no-trade zone", LOG_VERBOSE);
      return false;
   }

   if(Close_Before_Weekend && !IsNotWeekendClose())
   {
      m_utils.Log("BLOCKED: Weekend close period", LOG_VERBOSE);
      return false;
   }

   if(IsGapCooldown())
   {
      m_utils.Log("BLOCKED: Gap cooldown active", LOG_DETAIL);
      return false;
   }

   if(IsSpikeCooldown())
   {
      m_utils.Log("BLOCKED: Spike cooldown active", LOG_DETAIL);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if any active session is currently open                     |
//+------------------------------------------------------------------+
bool CSessionFilter::IsSessionActive()
{
   if(!Use_Time_Filter) return true;

   bool anyActive = false;

   if(Session1_Active && m_utils.IsTimeBetween(Session1_Start, Session1_End))
      anyActive = true;

   if(Session2_Active && m_utils.IsTimeBetween(Session2_Start, Session2_End))
      anyActive = true;

   if(Session3_Active && m_utils.IsTimeBetween(Session3_Start, Session3_End))
      anyActive = true;

   return anyActive;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed on current day                        |
//+------------------------------------------------------------------+
bool CSessionFilter::IsDayAllowed()
{
   int dow = m_utils.GetDayOfWeek();

   switch(dow)
   {
      case 0: return Trade_Sunday;
      case 1: return Trade_Monday;
      case 2: return Trade_Tuesday;
      case 3: return Trade_Wednesday;
      case 4: return Trade_Thursday;
      case 5: return Trade_Friday;
      case 6: return Trade_Saturday;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if NOT in no-trade zone                                     |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNotInNoTradeZone()
{
   if(No_Trade_Start == "" || No_Trade_End == "") return true;
   return !m_utils.IsTimeBetween(No_Trade_Start, No_Trade_End);
}

//+------------------------------------------------------------------+
//| Check if NOT near high-impact news                                |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNotNearNews()
{
   if(!Use_News_Filter) return true;

   // Reload news periodically (every 4 hours)
   if(TimeCurrent() - m_lastNewsUpdate > 14400)
      LoadNewsEvents();

   datetime now = TimeCurrent();

   for(int i = 0; i < m_newsCount; i++)
   {
      // Check impact filter
      if(m_newsEvents[i].impact == "High" && !Filter_High_Impact) continue;
      if(m_newsEvents[i].impact == "Medium" && !Filter_Medium_Impact) continue;
      if(m_newsEvents[i].impact == "Low" && !Filter_Low_Impact) continue;

      // Check currency filter
      if(News_Currencies != "")
      {
         if(StringFind(News_Currencies, m_newsEvents[i].currency) < 0)
            continue;
      }

      // Check time proximity
      int minutesBefore = (int)((m_newsEvents[i].time - now) / 60);
      int minutesAfter  = (int)((now - m_newsEvents[i].time) / 60);

      if(minutesBefore >= 0 && minutesBefore <= News_Before_Minutes)
         return false; // Too close before news

      if(minutesAfter >= 0 && minutesAfter <= News_After_Minutes)
         return false; // Too close after news
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if NOT in swap time                                         |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNotSwapTime()
{
   if(!Avoid_Swap_Time) return true;

   int swapH, swapM;
   if(!m_utils.ParseTimeString(Swap_Time, swapH, swapM)) return true;

   int currentMin = m_utils.GetAdjustedHour() * 60 + m_utils.GetServerMinute();
   int swapMin = swapH * 60 + swapM;

   int diff = MathAbs(currentMin - swapMin);
   if(diff > 720) diff = 1440 - diff; // Handle midnight wrap

   return (diff > Swap_Avoid_Minutes);
}

//+------------------------------------------------------------------+
//| Check if NOT in EOD no-trade block                                |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNotEODBlock()
{
   if(!No_New_Trades_EOD || No_New_Trades_Min_EOD <= 0) return true;

   int eodH, eodM;
   if(!m_utils.ParseTimeString(EOD_Close_Time, eodH, eodM)) return true;

   int currentMin = m_utils.GetAdjustedHour() * 60 + m_utils.GetServerMinute();
   int eodMin = eodH * 60 + eodM;

   int minutesToEOD = eodMin - currentMin;
   if(minutesToEOD < 0) minutesToEOD += 1440;

   return (minutesToEOD > No_New_Trades_Min_EOD);
}

//+------------------------------------------------------------------+
//| Check if NOT in weekend close period                              |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNotWeekendClose()
{
   if(!Close_Before_Weekend) return true;

   int dow = m_utils.GetDayOfWeek();
   if(dow != 5) return true; // Only Friday

   return !m_utils.IsTimeBetween(Weekend_Close_Time, "23:59");
}

//+------------------------------------------------------------------+
//| Check if it's Friday close time                                   |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNotFridayCloseTime()
{
   if(!Close_All_Friday) return true;

   int dow = m_utils.GetDayOfWeek();
   if(dow != 5) return true;

   return !m_utils.IsTimeBetween(Friday_Close_Time, "23:59");
}

//+------------------------------------------------------------------+
//| Session detection helpers                                         |
//+------------------------------------------------------------------+
bool CSessionFilter::IsTokyoSession()
{
   int h = m_utils.GetAdjustedHour();
   return (h >= 0 && h < 6);
}

bool CSessionFilter::IsLondonSession()
{
   int h = m_utils.GetAdjustedHour();
   return (h >= 7 && h < 16);
}

bool CSessionFilter::IsNYSession()
{
   int h = m_utils.GetAdjustedHour();
   return (h >= 12 && h < 21);
}

bool CSessionFilter::IsOverlapSession()
{
   return (IsLondonSession() && IsNYSession());
}

string CSessionFilter::GetCurrentSession()
{
   if(IsOverlapSession()) return "London/NY Overlap";
   if(IsLondonSession()) return "London";
   if(IsNYSession()) return "New York";
   if(IsTokyoSession()) return "Tokyo";
   return "Off-Hours";
}

//+------------------------------------------------------------------+
//| Load news events (from calendar or XML)                           |
//+------------------------------------------------------------------+
void CSessionFilter::LoadNewsEvents()
{
   m_newsCount = 0;
   ArrayResize(m_newsEvents, 0);
   m_lastNewsUpdate = TimeCurrent();

   // Try MQL5 economic calendar first
   MqlCalendarValue values[];
   datetime from = TimeCurrent() - 86400;  // 1 day before
   datetime to   = TimeCurrent() + 86400;  // 1 day ahead

   int total = CalendarValueHistory(values, from, to);

   if(total > 0)
   {
      for(int i = 0; i < total; i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event)) continue;

         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country)) continue;

         // Filter by impact
         string impact = "";
         if(event.importance == CALENDAR_IMPORTANCE_HIGH) impact = "High";
         else if(event.importance == CALENDAR_IMPORTANCE_MODERATE) impact = "Medium";
         else if(event.importance == CALENDAR_IMPORTANCE_LOW) impact = "Low";
         else continue;

         m_newsCount++;
         ArrayResize(m_newsEvents, m_newsCount);
         m_newsEvents[m_newsCount - 1].time = values[i].time;
         m_newsEvents[m_newsCount - 1].currency = country.currency;
         m_newsEvents[m_newsCount - 1].impact = impact;
         m_newsEvents[m_newsCount - 1].title = event.name;
      }

      m_newsLoaded = true;
      m_utils.Log("Loaded " + IntegerToString(m_newsCount) + " news events from calendar", LOG_DETAIL);
   }
   else
   {
      m_utils.Log("No news events loaded (calendar API returned 0 events)", LOG_DETAIL);
   }
}

//+------------------------------------------------------------------+
//| Check if any news event is happening now                          |
//+------------------------------------------------------------------+
bool CSessionFilter::IsNewsTime()
{
   return !IsNotNearNews();
}

//+------------------------------------------------------------------+
//| Get minutes to next news event                                    |
//+------------------------------------------------------------------+
int CSessionFilter::GetMinutesToNextNews()
{
   datetime now = TimeCurrent();
   int minMinutes = 9999;

   for(int i = 0; i < m_newsCount; i++)
   {
      if(m_newsEvents[i].time > now)
      {
         int minutes = (int)((m_newsEvents[i].time - now) / 60);
         if(minutes < minMinutes)
            minMinutes = minutes;
      }
   }

   return minMinutes;
}

//+------------------------------------------------------------------+
//| Called on new bar                                                  |
//+------------------------------------------------------------------+
void CSessionFilter::OnNewBar()
{
   m_barsAfterGap++;
   m_barsAfterSpike++;
}

//+------------------------------------------------------------------+
//| Check gap cooldown                                                |
//+------------------------------------------------------------------+
bool CSessionFilter::IsGapCooldown()
{
   if(!Use_Gap_Filter || !Skip_After_Gap) return false;
   return (m_barsAfterGap < Skip_Bars_After_Gap);
}

//+------------------------------------------------------------------+
//| Check spike cooldown                                              |
//+------------------------------------------------------------------+
bool CSessionFilter::IsSpikeCooldown()
{
   if(!Use_Spike_Filter) return false;
   return (m_barsAfterSpike < Spike_Cooldown_Bars);
}

//+------------------------------------------------------------------+
//| Should close all positions at EOD?                                |
//+------------------------------------------------------------------+
bool CSessionFilter::ShouldCloseAllEOD()
{
   if(!Close_All_EOD) return false;
   return m_utils.IsTimeBetween(EOD_Close_Time, EOD_Close_Time);
}

//+------------------------------------------------------------------+
//| Should close profitable positions at EOD?                         |
//+------------------------------------------------------------------+
bool CSessionFilter::ShouldCloseProfitEOD()
{
   if(!Close_Profit_EOD) return false;
   return m_utils.IsTimeBetween(EOD_Close_Time, EOD_Close_Time);
}

//+------------------------------------------------------------------+
//| Should close for weekend?                                         |
//+------------------------------------------------------------------+
bool CSessionFilter::ShouldCloseForWeekend()
{
   if(!Close_Before_Weekend) return false;
   if(m_utils.GetDayOfWeek() != 5) return false;
   return m_utils.IsTimeBetween(Weekend_Close_Time, "23:59");
}


// ==================================================================
// SOURCE: Dashboard.mqh
// ==================================================================
//+------------------------------------------------------------------+
//|                                                  Dashboard.mqh   |
//|                HFT Scalper Pro - On-Chart Dashboard & HUD         |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| CDashboard - On-chart HUD, stats, and control panel               |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   CUtils*           m_utils;
   CRiskManager*     m_riskMgr;
   CSessionFilter*   m_sessionFilter;
   string            m_prefix;
   int               m_lineY;
   bool              m_isPaused;

   // Performance tracking
   int               m_totalTrades;
   int               m_winTrades;
   int               m_lossTrades;
   double            m_totalProfit;
   double            m_totalLoss;
   double            m_grossProfit;
   double            m_grossLoss;
   double            m_maxDD;
   double            m_totalCommission;
   double            m_totalSwap;

   // Internal drawing methods
   void              CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 0);
   void              UpdateLabel(string name, string text, color clr = 0);
   void              CreateRectangle(string name, int x, int y, int w, int h, color bgColor);
   void              CreateButton(string name, int x, int y, int w, int h, string text, color bgColor, color textColor);
   void              DrawLine(string label, string value, color valueColor = 0);
   void              ResetLineY() { m_lineY = Dashboard_Y + 5; }

   // Stats calculation
   void              CalculatePerformanceStats();

public:
                     CDashboard();
                    ~CDashboard();

   bool              Init(CUtils *utils, CRiskManager *riskMgr, CSessionFilter *sessionFilter);
   void              Update();
   void              Remove();

   // Control panel
   bool              IsPaused() { return m_isPaused; }
   void              SetPaused(bool paused) { m_isPaused = paused; }

   // Chart event handler
   void              OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDashboard::CDashboard()
{
   m_prefix = "HFT_DB_";
   m_lineY = 30;
   m_isPaused = false;
   m_totalTrades = 0;
   m_winTrades = 0;
   m_lossTrades = 0;
   m_totalProfit = 0;
   m_totalLoss = 0;
   m_grossProfit = 0;
   m_grossLoss = 0;
   m_maxDD = 0;
   m_totalCommission = 0;
   m_totalSwap = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDashboard::~CDashboard()
{
   Remove();
}

//+------------------------------------------------------------------+
//| Initialize dashboard                                              |
//+------------------------------------------------------------------+
bool CDashboard::Init(CUtils *utils, CRiskManager *riskMgr, CSessionFilter *sessionFilter)
{
   m_utils = utils;
   m_riskMgr = riskMgr;
   m_sessionFilter = sessionFilter;

   if(Stealth_Mode) return true;

   CalculatePerformanceStats();

   m_utils.Log("Dashboard initialized", LOG_DETAIL);
   return true;
}

//+------------------------------------------------------------------+
//| Update dashboard display                                          |
//+------------------------------------------------------------------+
void CDashboard::Update()
{
   if(!Show_Dashboard || Stealth_Mode) return;

   // Recalculate stats periodically
   CalculatePerformanceStats();

   // Clear and redraw
   ResetLineY();

   // Background
   CreateRectangle(m_prefix + "BG", Dashboard_X, Dashboard_Y, 280, 400, Dashboard_BG_Color);

   // Title
   DrawLine("HFT SCALPER PRO", EA_Version, Dashboard_Text_Color);
   DrawLine("", "", Dashboard_Text_Color); // Spacer

   // Spread
   if(Show_Spread_Live)
   {
      double spread = m_utils.GetSpreadPoints();
      color spreadClr = (spread > Spread_Alert_Level) ? Loss_Color : Profit_Color;
      DrawLine("Spread", DoubleToString(spread, 1) + " pts", spreadClr);
   }

   // Session
   if(Show_Session_Box)
   {
      string session = m_sessionFilter.GetCurrentSession();
      DrawLine("Session", session, Dashboard_Text_Color);
   }

   // Daily P&L
   double dailyPnL = m_riskMgr.GetDailyPnL();
   color pnlColor = (dailyPnL >= 0) ? Profit_Color : Loss_Color;
   DrawLine("Daily P&L", DoubleToString(dailyPnL, 2) + " USD", pnlColor);

   // Open Positions
   int openPos = m_riskMgr.CountOpenPositions();
   DrawLine("Open Trades", IntegerToString(openPos) + " / " + IntegerToString(Max_Open_Positions), Dashboard_Text_Color);

   // Daily Trades
   DrawLine("Daily Trades", IntegerToString(m_riskMgr.GetDailyTradeCount()) + " / " + IntegerToString(Max_Daily_Trades), Dashboard_Text_Color);

   // Unrealized P&L
   double unrealized = m_riskMgr.GetTotalUnrealizedPnL();
   color unrealClr = (unrealized >= 0) ? Profit_Color : Loss_Color;
   DrawLine("Unrealized", DoubleToString(unrealized, 2) + " USD", unrealClr);

   DrawLine("", "", Dashboard_Text_Color); // Spacer

   // Performance stats
   if(Show_Total_Trades)
      DrawLine("Total Trades", IntegerToString(m_totalTrades), Dashboard_Text_Color);

   if(Show_Win_Rate && m_totalTrades > 0)
   {
      double winRate = (double)m_winTrades / m_totalTrades * 100.0;
      DrawLine("Win Rate", DoubleToString(winRate, 1) + "%", (winRate >= 50) ? Profit_Color : Loss_Color);
   }

   if(Show_Profit_Factor && m_grossLoss != 0)
   {
      double pf = MathAbs(m_grossProfit / m_grossLoss);
      DrawLine("Profit Factor", DoubleToString(pf, 2), (pf >= 1.0) ? Profit_Color : Loss_Color);
   }

   if(Show_Avg_Win_Loss && m_winTrades > 0 && m_lossTrades > 0)
   {
      double avgWin = m_grossProfit / m_winTrades;
      double avgLoss = MathAbs(m_grossLoss / m_lossTrades);
      DrawLine("Avg Win", DoubleToString(avgWin, 2), Profit_Color);
      DrawLine("Avg Loss", DoubleToString(avgLoss, 2), Loss_Color);
   }

   if(Show_RR_Ratio && m_lossTrades > 0 && m_winTrades > 0)
   {
      double avgWin = m_grossProfit / m_winTrades;
      double avgLoss = MathAbs(m_grossLoss / m_lossTrades);
      double rr = (avgLoss > 0) ? (avgWin / avgLoss) : 0;
      DrawLine("R:R Ratio", DoubleToString(rr, 2), Dashboard_Text_Color);
   }

   if(Show_Max_DD_Live)
   {
      DrawLine("Max DD", DoubleToString(m_riskMgr.GetCurrentDrawdownPct(), 2) + "% / " +
               DoubleToString(m_riskMgr.GetCurrentDrawdown(), 2) + " USD", Loss_Color);
   }

   if(Show_Commission_Paid)
      DrawLine("Commission", DoubleToString(m_totalCommission, 2) + " USD", Dashboard_Text_Color);

   if(Show_Swap_Paid)
      DrawLine("Swap", DoubleToString(m_totalSwap, 2) + " USD", Dashboard_Text_Color);

   if(Show_Effective_RR)
   {
      double spread = m_utils.GetSpreadPoints();
      double netTP = Take_Profit_Points - spread;
      double netSL = Stop_Loss_Points + spread;
      double effectiveRR = (netSL > 0) ? (netTP / netSL) : 0;
      DrawLine("Net R:R", DoubleToString(effectiveRR, 2) + " (after spread)", Dashboard_Text_Color);
   }

   DrawLine("", "", Dashboard_Text_Color); // Spacer

   // Status indicators
   string status = EA_Active ? "ACTIVE" : "DISABLED";
   color statusClr = EA_Active ? Profit_Color : Loss_Color;
   if(m_isPaused) { status = "PAUSED"; statusClr = clrYellow; }
   if(m_riskMgr.IsHardStopped()) { status = "HARD STOPPED"; statusClr = Loss_Color; }
   if(m_riskMgr.IsInRecovery()) { status = "RECOVERY MODE"; statusClr = clrOrange; }
   DrawLine("Status", status, statusClr);

   // Streaks
   int consLoss = m_riskMgr.GetConsecutiveLosses();
   int consWin = m_riskMgr.GetConsecutiveWins();
   if(consLoss > 0)
      DrawLine("Streak", IntegerToString(consLoss) + " losses", Loss_Color);
   else if(consWin > 0)
      DrawLine("Streak", IntegerToString(consWin) + " wins", Profit_Color);

   // Equity
   DrawLine("Equity", DoubleToString(m_utils.Equity(), 2), Dashboard_Text_Color);
   DrawLine("Balance", DoubleToString(m_utils.Balance(), 2), Dashboard_Text_Color);

   // Control Panel Buttons
   if(Show_Control_Panel)
      DrawControlPanel();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw control panel buttons                                        |
//+------------------------------------------------------------------+
void DrawControlPanel()
{
   int btnX = Panel_X;
   int btnY = Panel_Y;
   int btnW = 80;
   int btnH = 25;
   int gap = 5;

   if(Show_Close_All_Button)
   {
      string name = "HFT_DB_BTN_CloseAll";
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btnX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, btnW);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, btnH);
      ObjectSetString(0, name, OBJPROP_TEXT, "Close All");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrFireBrick);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      btnY += btnH + gap;
   }

   if(Show_Pause_Button)
   {
      string name = "HFT_DB_BTN_Pause";
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btnX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, btnW);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, btnH);
      ObjectSetString(0, name, OBJPROP_TEXT, "Pause EA");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDarkOrange);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      btnY += btnH + gap;
   }

   if(Show_Flat_Button)
   {
      string name = "HFT_DB_BTN_Flat";
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btnX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, btnW);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, btnH);
      ObjectSetString(0, name, OBJPROP_TEXT, "Go Flat");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      btnY += btnH + gap;
   }

   if(Show_Buy_Button)
   {
      string name = "HFT_DB_BTN_Buy";
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btnX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, btnW);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, btnH);
      ObjectSetString(0, name, OBJPROP_TEXT, "Buy");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDodgerBlue);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      btnY += btnH + gap;
   }

   if(Show_Sell_Button)
   {
      string name = "HFT_DB_BTN_Sell";
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btnX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, btnW);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, btnH);
      ObjectSetString(0, name, OBJPROP_TEXT, "Sell");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrOrangeRed);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
//| Handle chart events (button clicks)                               |
//+------------------------------------------------------------------+
void CDashboard::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == "HFT_DB_BTN_CloseAll")
   {
      // Will be handled by main EA
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      m_utils.Log("Close All button clicked", LOG_BASIC);
   }
   else if(sparam == "HFT_DB_BTN_Pause")
   {
      m_isPaused = !m_isPaused;
      ObjectSetString(0, sparam, OBJPROP_TEXT, m_isPaused ? "Resume" : "Pause EA");
      ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, m_isPaused ? clrForestGreen : clrDarkOrange);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      m_utils.Log("EA " + (m_isPaused ? "PAUSED" : "RESUMED"), LOG_BASIC);
   }
   else if(sparam == "HFT_DB_BTN_Flat")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      m_utils.Log("Go Flat button clicked", LOG_BASIC);
   }
   else if(sparam == "HFT_DB_BTN_Buy")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      m_utils.Log("Manual Buy button clicked", LOG_BASIC);
   }
   else if(sparam == "HFT_DB_BTN_Sell")
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      m_utils.Log("Manual Sell button clicked", LOG_BASIC);
   }
}

//+------------------------------------------------------------------+
//| Create label object                                               |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 0)
{
   if(fontSize == 0) fontSize = Dashboard_Font_Size;

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, Dashboard_Font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Update label text                                                 |
//+------------------------------------------------------------------+
void CDashboard::UpdateLabel(string name, string text, color clr = 0)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   if(clr != 0) ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Create background rectangle                                       |
//+------------------------------------------------------------------+
void CDashboard::CreateRectangle(string name, int x, int y, int w, int h, color bgColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
}

//+------------------------------------------------------------------+
//| Draw a label + value line on the dashboard                        |
//+------------------------------------------------------------------+
void CDashboard::DrawLine(string label, string value, color valueColor = 0)
{
   if(valueColor == 0) valueColor = Dashboard_Text_Color;

   int lineHeight = Dashboard_Font_Size + 4;
   string nameLbl = m_prefix + "L_" + IntegerToString(m_lineY);
   string nameVal = m_prefix + "V_" + IntegerToString(m_lineY);

   if(label == "" && value == "")
   {
      m_lineY += lineHeight / 2; // Half-height spacer
      return;
   }

   CreateLabel(nameLbl, Dashboard_X + 5, m_lineY, label, Dashboard_Text_Color);
   CreateLabel(nameVal, Dashboard_X + 140, m_lineY, value, valueColor);

   m_lineY += lineHeight;
}

//+------------------------------------------------------------------+
//| Calculate performance statistics from history                     |
//+------------------------------------------------------------------+
void CDashboard::CalculatePerformanceStats()
{
   m_totalTrades = 0;
   m_winTrades = 0;
   m_lossTrades = 0;
   m_grossProfit = 0;
   m_grossLoss = 0;
   m_totalCommission = 0;
   m_totalSwap = 0;

   datetime from = 0;
   datetime to = TimeCurrent();
   if(!HistorySelect(from, to)) return;

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != Magic_Number) continue;

      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_INOUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);

      m_totalTrades++;
      m_totalCommission += commission;
      m_totalSwap += swap;

      double net = profit + commission + swap;
      if(net >= 0)
      {
         m_winTrades++;
         m_grossProfit += net;
      }
      else
      {
         m_lossTrades++;
         m_grossLoss += net;
      }
   }
}

//+------------------------------------------------------------------+
//| Remove all dashboard objects                                      |
//+------------------------------------------------------------------+
void CDashboard::Remove()
{
   if(!Delete_Objects_On_Remove) return;

   int total = ObjectsTotal(0, 0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0);
      if(StringFind(name, m_prefix) == 0 || StringFind(name, "HFT_DB_BTN_") == 0)
         ObjectDelete(0, name);
   }
}


// ==================================================================
// SOURCE: HFT_Scalper_Pro.mq5
// ==================================================================
//+------------------------------------------------------------------+
//|                                            HFT_Scalper_Pro.mq5   |
//|                  HFT Scalper Pro - Hybrid Scalping Expert Advisor  |
//|                                                                   |
//|  A comprehensive, modular HFT scalping EA for MetaTrader 5 with   |
//|  ~630 configurable input parameters across 84 categories.         |
//|                                                                   |
//|  Modules:                                                         |
//|    - SignalEngine: 25+ indicator signals with scoring system       |
//|    - RiskManager: Daily limits, drawdown, martingale, recovery     |
//|    - TradeManager: Execution, trailing, BE, partial close, grid    |
//|    - SessionFilter: Time, day, session, news, swap filters         |
//|    - Dashboard: On-chart HUD with stats and control panel          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Include modules                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Global module instances                                           |
//+------------------------------------------------------------------+
CUtils          g_utils;
CSignalEngine   g_signals;
CRiskManager    g_riskMgr;
CTradeManager   g_tradeMgr;
CSessionFilter  g_sessionFilter;
CDashboard      g_dashboard;

// New bar tracking
datetime        g_lastBarTime = 0;
int             g_barsSinceLastTrade = 0;

//+------------------------------------------------------------------+
//| Custom tester criterion for optimization                          |
//+------------------------------------------------------------------+
double OnTester()
{
   if(!Optimization_Mode) return 0;

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double totalTrades = (double)TesterStatistics(STAT_TRADES);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double maxDD       = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double winRate     = (totalTrades > 0) ? TesterStatistics(STAT_PROFIT_TRADES) / totalTrades * 100.0 : 0;

   // Optimization filters
   if(Opt_Skip_Low_Trades && totalTrades < Opt_Min_Trades) return -9999;
   if(Opt_Min_PF && profitFactor < Opt_Min_Profit_Factor) return -9999;
   if(Opt_Max_DD_Filter && maxDD > Opt_Max_DD_Pct) return -9999;
   if(Opt_Min_Win_Rate && winRate < Opt_Min_Win_Rate_Pct) return -9999;

   switch(Opt_Custom_Criterion)
   {
      case OPT_BALANCE:
         return balance;
      case OPT_PROFIT_FACTOR:
         return profitFactor;
      case OPT_CUSTOM:
         // Custom: Balance * PF / sqrt(DD)
         return (maxDD > 0) ? (balance * profitFactor / MathSqrt(maxDD)) : balance;
   }

   return balance;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- Master kill switch ---
   if(!EA_Active)
   {
      Print("EA is DISABLED (EA_Active = false)");
      return INIT_SUCCEEDED;
   }

   // --- Initialize utility module ---
   if(!g_utils.Init())
   {
      Print("FATAL: Utils initialization failed");
      return INIT_FAILED;
   }

   // --- License / Protection checks ---
   if(!g_utils.CheckLicense())
   {
      Print("FATAL: License check failed");
      return INIT_FAILED;
   }

   // --- Initialize signal engine ---
   if(!g_signals.Init(&g_utils))
   {
      Print("FATAL: SignalEngine initialization failed");
      return INIT_FAILED;
   }

   // --- Initialize risk manager ---
   if(!g_riskMgr.Init(&g_utils))
   {
      Print("FATAL: RiskManager initialization failed");
      return INIT_FAILED;
   }

   // --- Initialize trade manager ---
   if(!g_tradeMgr.Init(&g_utils, &g_riskMgr))
   {
      Print("FATAL: TradeManager initialization failed");
      return INIT_FAILED;
   }

   // --- Initialize session filter ---
   if(!g_sessionFilter.Init(&g_utils))
   {
      Print("FATAL: SessionFilter initialization failed");
      return INIT_FAILED;
   }

   // --- Initialize dashboard ---
   if(!g_dashboard.Init(&g_utils, &g_riskMgr, &g_sessionFilter))
   {
      Print("WARNING: Dashboard initialization failed (non-fatal)");
   }

   // --- Subscribe to DOM if needed ---
   if(Use_DOM_Filter)
      MarketBookAdd(g_utils.GetTradeSymbol());

   // --- Demo account warning ---
   if(g_utils.IsDemo() && Warn_If_Demo)
      g_utils.Log("WARNING: Running on DEMO account", LOG_BASIC);

   g_utils.Log("=== HFT Scalper Pro " + EA_Version + " initialized ===", LOG_BASIC);
   g_utils.Log("Symbol: " + g_utils.GetTradeSymbol() +
               " | Timeframe: " + EnumToString(Signal_TF) +
               " | Magic: " + IntegerToString(Magic_Number), LOG_BASIC);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release DOM subscription
   if(Use_DOM_Filter)
      MarketBookRelease(g_utils.GetTradeSymbol());

   // Close all on disable if configured
   if(Close_All_On_Disable && (reason == REASON_REMOVE || reason == REASON_PROGRAM))
      g_tradeMgr.CloseAllPositions();

   // Cleanup modules
   g_signals.Deinit();
   g_dashboard.Remove();
   g_utils.CloseFileLog();

   g_utils.Log("=== HFT Scalper Pro deinitialized. Reason: " + IntegerToString(reason) + " ===", LOG_BASIC);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Master kill switch ---
   if(!EA_Active) return;

   // --- Dashboard pause ---
   if(g_dashboard.IsPaused()) return;

   // --- Update tick time for timeout monitoring ---
   g_utils.UpdateTickTime();

   // --- Update spread tracking ---
   g_tradeMgr.UpdateSpreadHistory();

   // --- Track ticks for HFT burst detection ---
   g_signals.OnTick();

   // --- Manage existing positions (every tick for responsiveness) ---
   g_tradeMgr.ManageOpenPositions();

   // --- Risk manager trade event update ---
   g_riskMgr.OnTrade();

   // --- EOD/Weekend close checks ---
   if(g_sessionFilter.ShouldCloseAllEOD())
   {
      g_tradeMgr.CloseAllPositions();
      return;
   }
   if(g_sessionFilter.ShouldCloseForWeekend())
   {
      g_tradeMgr.CloseAllPositions();
      return;
   }
   if(g_sessionFilter.ShouldCloseProfitEOD())
   {
      g_tradeMgr.CloseAllProfitPositions();
   }

   // --- Friday close ---
   if(Close_All_Friday && !g_sessionFilter.IsNotFridayCloseTime())
   {
      g_tradeMgr.CloseAllPositions();
      return;
   }

   // --- News close ---
   if(Use_News_Filter && Close_On_News && g_sessionFilter.IsNewsTime())
   {
      g_tradeMgr.CloseAllPositions();
      return;
   }

   // --- Connection monitoring ---
   if(Monitor_Connection && g_utils.IsTickTimeout())
   {
      if(Alert_On_Disconnect)
         g_utils.SendAlert("No tick received for " + IntegerToString(Max_No_Tick_Seconds) + " seconds");
      if(Pause_On_Disconnect) return;
      if(Close_On_Disconnect) { g_tradeMgr.CloseAllPositions(); return; }
   }

   // --- Dashboard update (throttled) ---
   static datetime lastDashUpdate = 0;
   if(TimeCurrent() - lastDashUpdate >= 1) // Update every second max
   {
      g_dashboard.Update();
      lastDashUpdate = TimeCurrent();
   }

   // --- New bar detection for signal generation ---
   bool isNewBar = g_utils.IsNewBar(Signal_TF);
   if(isNewBar)
   {
      g_barsSinceLastTrade++;
      g_sessionFilter.OnNewBar();

      // Gap detection
      if(Use_Gap_Filter && g_utils.HasGap(1, Signal_TF))
         g_sessionFilter.OnGapDetected();

      // Spike detection
      if(Use_Spike_Filter && g_utils.IsPriceSpike())
         g_sessionFilter.OnSpikeDetected();
   }

   // --- Wait for bar close if configured ---
   if(Wait_For_Bar_Close && !isNewBar) return;

   // --- One trade per bar ---
   if(One_Trade_Per_Bar && isNewBar)
   {
      // Allow trading on this new bar
   }
   else if(One_Trade_Per_Bar && !isNewBar && g_barsSinceLastTrade == 0)
   {
      return; // Already traded on this bar
   }

   // --- Min bars between trades ---
   if(Min_Bars_Between_Trades > 0 && g_barsSinceLastTrade < Min_Bars_Between_Trades)
      return;

   // --- Pre-trade platform checks ---
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return;

   // --- Spread check ---
   if(!g_tradeMgr.IsSpreadOK()) return;

   // --- Session/Time filter ---
   if(!g_sessionFilter.CanTrade()) return;

   // --- Risk management pre-trade checks ---
   if(!g_riskMgr.CanOpenTrade()) return;

   // --- Generate trade signal ---
   int signal = g_signals.GetSignal();

   if(signal == 0) return;

   // --- Handle opposite signal (close existing) ---
   if(Close_On_Opposite_Signal)
      g_tradeMgr.HandleOppositeSignal(signal);

   // --- Alert on signal ---
   if(Alert_On_Signal)
      g_utils.SendAlert("Signal: " + (signal > 0 ? "BUY" : "SELL") +
                        " | Score: " + IntegerToString(signal > 0 ? g_signals.GetBuyScore() : g_signals.GetSellScore()));

   // --- Execute trade ---
   bool success = false;
   if(signal > 0)
      success = g_tradeMgr.OpenBuy();
   else if(signal < 0)
      success = g_tradeMgr.OpenSell();

   if(success)
   {
      g_barsSinceLastTrade = 0;

      if(Log_Signals)
      {
         g_utils.Log("Trade executed: " + (signal > 0 ? "BUY" : "SELL") +
                     " | BuyScore=" + IntegerToString(g_signals.GetBuyScore()) +
                     " | SellScore=" + IntegerToString(g_signals.GetSellScore()) +
                     " | Spread=" + DoubleToString(g_utils.GetSpreadPoints(), 1) +
                     " | Session=" + g_sessionFilter.GetCurrentSession(), LOG_BASIC);
      }
   }

   // --- CPU load reduction ---
   if(Reduce_CPU_Load && Sleep_Between_Ticks_MS > 0)
      Sleep(Sleep_Between_Ticks_MS);
}

//+------------------------------------------------------------------+
//| Trade event handler                                               |
//+------------------------------------------------------------------+
void OnTrade()
{
   g_riskMgr.OnTrade();
}

//+------------------------------------------------------------------+
//| Book event handler (DOM updates)                                  |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
   // DOM events handled by SignalEngine during signal generation
}

//+------------------------------------------------------------------+
//| Chart event handler (button clicks, etc.)                         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Dashboard button handling
   g_dashboard.OnChartEvent(id, lparam, dparam, sparam);

   // Handle specific button actions
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "HFT_DB_BTN_CloseAll")
         g_tradeMgr.CloseAllPositions();
      else if(sparam == "HFT_DB_BTN_Flat")
         g_tradeMgr.CloseAllPositions();
      else if(sparam == "HFT_DB_BTN_Buy")
         g_tradeMgr.OpenBuy();
      else if(sparam == "HFT_DB_BTN_Sell")
         g_tradeMgr.OpenSell();
   }
}

//+------------------------------------------------------------------+
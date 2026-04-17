//+------------------------------------------------------------------+
//|                                                     Inputs.mqh   |
//|                   HFT Scalper Pro - All Input Parameters          |
//|                   ~630 parameters across 84 categories            |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_INPUTS_MQH__
#define __HFT_INPUTS_MQH__

#include "Enums.mqh"

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
input bool     MA_Cross_Only          = true;                 // Enter Only on Cross
input double   MA_Gap_Min_Points      = 5;                    // Min MA Gap (points)

//+------------------------------------------------------------------+
//| 7. ENTRY SIGNAL - RSI                                             |
//+------------------------------------------------------------------+
input group "=== 7. RSI Filter ==="
input bool     Use_RSI_Filter         = false;                // Enable RSI Filter
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
input bool     Use_ATR_Filter         = false;                // Enable ATR Filter
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
input bool     Use_Tick_Volume        = false;                // Enable Volume Filter
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
input bool     Use_Higher_TF_Filter   = false;                // Enable Higher TF Filter
input bool     Wait_For_Bar_Close     = false;                // Wait for Bar Close
input int      Bars_To_Analyze        = 500;                  // Bars to Analyze
input int      Signal_Confirmation_Ticks = 3;                 // Confirmation Ticks

//+------------------------------------------------------------------+
//| 20. SESSION TIME FILTERS                                          |
//+------------------------------------------------------------------+
input group "=== 20. Session Time Filters ==="
input bool     Use_Time_Filter        = false;                // Enable Time Filter
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
input bool     Close_All_Friday       = false;                // Close All on Friday

//+------------------------------------------------------------------+
//| 22. NEWS FILTER                                                   |
//+------------------------------------------------------------------+
input group "=== 22. News Filter ==="
input bool     Use_News_Filter        = false;                // Enable News Filter
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
input double   Max_Spread_Points      = 50;                   // Max Spread to Open
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
input bool     Use_ADX_Filter         = false;                // Enable ADX Filter
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
input bool     Use_Candle_Filter     = false;                 // Enable Candle Filter
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
input bool     Use_Gap_Filter        = false;                 // Enable Gap Filter
input double   Max_Gap_Points        = 50;                    // Max Gap (points)
input bool     Skip_After_Gap        = true;                  // Skip After Gap
input int      Skip_Bars_After_Gap   = 3;                     // Skip Bars After Gap
input bool     Close_Into_Gap        = false;                 // Close Into Gap

//+------------------------------------------------------------------+
//| 52. PRICE SPIKE FILTER                                            |
//+------------------------------------------------------------------+
input group "=== 52. Price Spike Filter ==="
input bool     Use_Spike_Filter      = false;                 // Enable Spike Filter
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
input bool     Require_MTF_Confirm   = false;                 // Require MTF Confirm
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
input bool     Close_Before_Weekend  = false;                 // Close Before Weekend
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
input bool     Skip_If_Spread_Kills_RR = false;               // Skip if Spread Kills R:R
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
input double   Absolute_Min_Equity   = 0;                     // Absolute Min Equity (USD)
input double   Max_Margin_Level_Pct  = 500.0;                 // Max Margin Level (%)
input double   Min_Free_Margin_USD   = 200.0;                 // Min Free Margin (USD)
input bool     Check_Margin_Before_Order = true;              // Check Margin Before Order
input double   Required_Margin_Buffer= 1.5;                   // Margin Buffer Multiplier

#endif // __HFT_INPUTS_MQH__

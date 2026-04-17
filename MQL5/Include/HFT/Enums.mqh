//+------------------------------------------------------------------+
//|                                                      Enums.mqh   |
//|                        HFT Scalper Pro - Custom Enumerations      |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_ENUMS_MQH__
#define __HFT_ENUMS_MQH__

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

#endif // __HFT_ENUMS_MQH__

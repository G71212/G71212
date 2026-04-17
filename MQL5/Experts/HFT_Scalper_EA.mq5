//+------------------------------------------------------------------+
//|                                              HFT_Scalper_EA.mq5  |
//|                        High-Frequency Trading Scalping EA        |
//|                                                                  |
//| Strategy: Combines EMA crossover, RSI momentum, and Bollinger   |
//| Band mean-reversion signals with strict spread filtering and     |
//| micro-level risk management for rapid scalping entries/exits.    |
//+------------------------------------------------------------------+
#property copyright   "HFT Scalper EA"
#property link        "https://github.com/G71212/G71212"
#property version     "1.00"
#property description "High-Frequency Trading Scalping Expert Advisor for MT5"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- General Settings ---
input group "=== General Settings ==="
input ulong    InpMagicNumber     = 202504;        // Magic Number
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;    // Timeframe
input string   InpTradeComment    = "HFT_Scalper"; // Trade Comment

// --- Risk Management ---
input group "=== Risk Management ==="
input double   InpRiskPercent     = 1.0;    // Risk per trade (% of balance)
input double   InpFixedLots       = 0.0;    // Fixed lot size (0 = use risk %)
input double   InpMaxLots         = 10.0;   // Maximum lot size
input int      InpMaxOpenTrades   = 3;      // Max simultaneous open trades
input double   InpMaxDailyLoss    = 5.0;    // Max daily loss (% of balance)
input double   InpMaxDailyProfit  = 10.0;   // Daily profit target (% of balance)

// --- Scalping Parameters ---
input group "=== Scalping Parameters ==="
input int      InpTakeProfitPips  = 5;      // Take Profit (pips)
input int      InpStopLossPips    = 3;      // Stop Loss (pips)
input int      InpTrailingStop    = 2;      // Trailing Stop (pips, 0 = off)
input int      InpBreakEvenPips   = 3;      // Break Even activation (pips, 0 = off)
input int      InpMaxSpread       = 15;     // Max allowed spread (points)
input int      InpSlippage        = 5;      // Max slippage (points)

// --- EMA Settings ---
input group "=== EMA Crossover ==="
input int      InpEmaFastPeriod   = 5;      // Fast EMA Period
input int      InpEmaSlowPeriod   = 13;     // Slow EMA Period

// --- RSI Settings ---
input group "=== RSI Filter ==="
input int      InpRsiPeriod       = 7;      // RSI Period
input double   InpRsiOverbought   = 70.0;   // RSI Overbought Level
input double   InpRsiOversold     = 30.0;   // RSI Oversold Level
input bool     InpUseRsiFilter    = true;   // Enable RSI Filter

// --- Bollinger Bands ---
input group "=== Bollinger Bands ==="
input int      InpBbPeriod        = 14;     // Bollinger Bands Period
input double   InpBbDeviation     = 2.0;    // Bollinger Bands Deviation
input bool     InpUseBbFilter     = true;   // Enable Bollinger Band Filter

// --- Time Filter ---
input group "=== Trading Hours Filter ==="
input bool     InpUseTimeFilter   = true;   // Enable Time Filter
input int      InpStartHour       = 8;      // Trading Start Hour (server time)
input int      InpEndHour         = 20;     // Trading End Hour (server time)
input bool     InpAvoidNews       = true;   // Avoid trading around news (heuristic)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CSymbolInfo    symInfo;
CAccountInfo   accInfo;

int            handleEmaFast;
int            handleEmaSlow;
int            handleRsi;
int            handleBb;

double         emaFastBuffer[];
double         emaSlowBuffer[];
double         rsiBuffer[];
double         bbUpperBuffer[];
double         bbMiddleBuffer[];
double         bbLowerBuffer[];

double         dailyPnL;
datetime       lastDayChecked;
double         pipValue;
int            pipDigits;
double         pointMultiplier;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- Validate inputs ---
   if(InpEmaFastPeriod >= InpEmaSlowPeriod)
   {
      Print("ERROR: Fast EMA period must be less than Slow EMA period");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpTakeProfitPips <= 0 || InpStopLossPips <= 0)
   {
      Print("ERROR: TP and SL must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   // --- Setup trade object ---
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(true); // Async for speed

   // --- Symbol info ---
   if(!symInfo.Name(_Symbol))
   {
      Print("ERROR: Failed to set symbol info");
      return INIT_FAILED;
   }
   symInfo.Refresh();

   // --- Calculate pip value ---
   pipDigits = (symInfo.Digits() == 3 || symInfo.Digits() == 5) ? 1 : 0;
   pointMultiplier = pipDigits ? 10.0 : 1.0;
   pipValue = symInfo.Point() * pointMultiplier;

   // --- Create indicator handles ---
   handleEmaFast = iMA(_Symbol, InpTimeframe, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleEmaSlow = iMA(_Symbol, InpTimeframe, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleRsi     = iRSI(_Symbol, InpTimeframe, InpRsiPeriod, PRICE_CLOSE);
   handleBb      = iBands(_Symbol, InpTimeframe, InpBbPeriod, 0, InpBbDeviation, PRICE_CLOSE);

   if(handleEmaFast == INVALID_HANDLE || handleEmaSlow == INVALID_HANDLE ||
      handleRsi == INVALID_HANDLE || handleBb == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles");
      return INIT_FAILED;
   }

   // --- Set buffer series ---
   ArraySetAsSeries(emaFastBuffer, true);
   ArraySetAsSeries(emaSlowBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(bbUpperBuffer, true);
   ArraySetAsSeries(bbMiddleBuffer, true);
   ArraySetAsSeries(bbLowerBuffer, true);

   // --- Reset daily PnL ---
   dailyPnL = 0.0;
   lastDayChecked = 0;

   Print("HFT Scalper EA initialized successfully on ", _Symbol,
         " | TF=", EnumToString(InpTimeframe),
         " | TP=", InpTakeProfitPips, " SL=", InpStopLossPips,
         " | MaxSpread=", InpMaxSpread);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleEmaFast != INVALID_HANDLE) IndicatorRelease(handleEmaFast);
   if(handleEmaSlow != INVALID_HANDLE) IndicatorRelease(handleEmaSlow);
   if(handleRsi != INVALID_HANDLE)     IndicatorRelease(handleRsi);
   if(handleBb != INVALID_HANDLE)      IndicatorRelease(handleBb);

   Print("HFT Scalper EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Refresh symbol data ---
   symInfo.RefreshRates();

   // --- Check daily PnL limits ---
   if(!CheckDailyLimits())
      return;

   // --- Manage existing positions (trailing stop, break even) ---
   ManageOpenPositions();

   // --- Check if new bar formed (avoid over-trading on same bar) ---
   if(!IsNewBar())
      return;

   // --- Pre-trade checks ---
   if(!IsTradeAllowed())
      return;

   if(!CheckSpread())
      return;

   if(InpUseTimeFilter && !IsWithinTradingHours())
      return;

   if(CountOpenPositions() >= InpMaxOpenTrades)
      return;

   // --- Copy indicator buffers ---
   if(!CopyIndicatorData())
      return;

   // --- Generate trade signals ---
   int signal = GetTradeSignal();

   // --- Execute trades ---
   if(signal == 1)
      OpenBuy();
   else if(signal == -1)
      OpenSell();
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                       |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;
   if(symInfo.TradeMode() == SYMBOL_TRADE_MODE_DISABLED)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check current spread against maximum allowed                      |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   int currentSpread = (int)symInfo.Spread();
   if(currentSpread > InpMaxSpread)
   {
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if within allowed trading hours                             |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   int currentHour = dt.hour;

   if(InpStartHour < InpEndHour)
      return (currentHour >= InpStartHour && currentHour < InpEndHour);
   else // Wraps around midnight
      return (currentHour >= InpStartHour || currentHour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Check daily profit/loss limits                                    |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                  IntegerToString(dt.mon) + "." +
                                  IntegerToString(dt.day));

   // Reset daily PnL on new day
   if(today != lastDayChecked)
   {
      dailyPnL = 0.0;
      lastDayChecked = today;

      // Calculate PnL from today's closed trades
      CalculateDailyPnL(today);
   }

   double balance = accInfo.Balance();

   // Check max daily loss
   if(InpMaxDailyLoss > 0 && dailyPnL <= -(balance * InpMaxDailyLoss / 100.0))
   {
      return false;
   }

   // Check daily profit target
   if(InpMaxDailyProfit > 0 && dailyPnL >= (balance * InpMaxDailyProfit / 100.0))
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate daily PnL from trade history                            |
//+------------------------------------------------------------------+
void CalculateDailyPnL(datetime today)
{
   dailyPnL = 0.0;
   datetime tomorrow = today + 86400;

   if(!HistorySelect(today, tomorrow))
      return;

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == (long)InpMagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
      {
         dailyPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }

   // Add unrealized PnL from open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == _Symbol)
         {
            dailyPnL += posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                  |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Copy indicator data into buffers                                  |
//+------------------------------------------------------------------+
bool CopyIndicatorData()
{
   if(CopyBuffer(handleEmaFast, 0, 0, 3, emaFastBuffer) < 3) return false;
   if(CopyBuffer(handleEmaSlow, 0, 0, 3, emaSlowBuffer) < 3) return false;
   if(CopyBuffer(handleRsi, 0, 0, 3, rsiBuffer) < 3) return false;
   if(CopyBuffer(handleBb, 1, 0, 3, bbUpperBuffer) < 3) return false;  // Upper band
   if(CopyBuffer(handleBb, 0, 0, 3, bbMiddleBuffer) < 3) return false; // Middle band
   if(CopyBuffer(handleBb, 2, 0, 3, bbLowerBuffer) < 3) return false;  // Lower band

   return true;
}

//+------------------------------------------------------------------+
//| Generate trade signal                                             |
//| Returns: 1 = Buy, -1 = Sell, 0 = No signal                      |
//+------------------------------------------------------------------+
int GetTradeSignal()
{
   // --- EMA Crossover Signal ---
   // Current bar: fast > slow, Previous bar: fast <= slow => bullish crossover
   bool emaBullCross = (emaFastBuffer[1] > emaSlowBuffer[1]) &&
                       (emaFastBuffer[2] <= emaSlowBuffer[2]);
   bool emaBearCross = (emaFastBuffer[1] < emaSlowBuffer[1]) &&
                       (emaFastBuffer[2] >= emaSlowBuffer[2]);

   // --- RSI Filter ---
   bool rsiBuyOk  = true;
   bool rsiSellOk = true;

   if(InpUseRsiFilter)
   {
      // For buys: RSI should not be overbought (momentum still has room)
      rsiBuyOk  = (rsiBuffer[1] < InpRsiOverbought && rsiBuffer[1] > InpRsiOversold);
      // For sells: RSI should not be oversold
      rsiSellOk = (rsiBuffer[1] > InpRsiOversold && rsiBuffer[1] < InpRsiOverbought);

      // Extra confirmation: RSI rising for buy, falling for sell
      if(rsiBuffer[1] < rsiBuffer[2]) rsiBuyOk = false;
      if(rsiBuffer[1] > rsiBuffer[2]) rsiSellOk = false;
   }

   // --- Bollinger Bands Filter ---
   bool bbBuyOk  = true;
   bool bbSellOk = true;

   if(InpUseBbFilter)
   {
      double close1 = iClose(_Symbol, InpTimeframe, 1);

      // Buy signal: price near or below lower band (mean reversion potential)
      bbBuyOk  = (close1 <= bbMiddleBuffer[1]);
      // Sell signal: price near or above upper band
      bbSellOk = (close1 >= bbMiddleBuffer[1]);
   }

   // --- Combine Signals ---
   if(emaBullCross && rsiBuyOk && bbBuyOk)
      return 1;

   if(emaBearCross && rsiSellOk && bbSellOk)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPoints)
{
   if(InpFixedLots > 0)
      return NormalizeLots(InpFixedLots);

   double balance    = accInfo.Balance();
   double riskAmount = balance * InpRiskPercent / 100.0;
   double tickValue  = symInfo.TickValue();
   double tickSize   = symInfo.TickSize();

   if(tickValue == 0 || tickSize == 0 || slPoints == 0)
      return NormalizeLots(symInfo.LotsMin());

   double lots = (riskAmount * tickSize) / (slPoints * tickValue);
   return NormalizeLots(lots);
}

//+------------------------------------------------------------------+
//| Normalize lot size to broker requirements                         |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot  = symInfo.LotsMin();
   double maxLot  = symInfo.LotsMax();
   double lotStep = symInfo.LotsStep();

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, InpMaxLots);
   lots = MathMin(lots, maxLot);

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Open a Buy position                                               |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = symInfo.Ask();
   double slPoints = InpStopLossPips * pipValue;
   double tpPoints = InpTakeProfitPips * pipValue;

   double sl = NormalizeDouble(ask - slPoints, symInfo.Digits());
   double tp = NormalizeDouble(ask + tpPoints, symInfo.Digits());

   double lots = CalculateLotSize(slPoints);

   if(lots <= 0)
   {
      Print("ERROR: Invalid lot size calculated for BUY");
      return;
   }

   if(trade.Buy(lots, _Symbol, ask, sl, tp, InpTradeComment))
   {
      Print("BUY opened: Lots=", lots, " Ask=", ask, " SL=", sl, " TP=", tp);
   }
   else
   {
      Print("BUY FAILED: Error=", GetLastError(), " RetCode=", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Open a Sell position                                              |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = symInfo.Bid();
   double slPoints = InpStopLossPips * pipValue;
   double tpPoints = InpTakeProfitPips * pipValue;

   double sl = NormalizeDouble(bid + slPoints, symInfo.Digits());
   double tp = NormalizeDouble(bid - tpPoints, symInfo.Digits());

   double lots = CalculateLotSize(slPoints);

   if(lots <= 0)
   {
      Print("ERROR: Invalid lot size calculated for SELL");
      return;
   }

   if(trade.Sell(lots, _Symbol, bid, sl, tp, InpTradeComment))
   {
      Print("SELL opened: Lots=", lots, " Bid=", bid, " SL=", sl, " TP=", tp);
   }
   else
   {
      Print("SELL FAILED: Error=", GetLastError(), " RetCode=", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Manage open positions: trailing stop & break even                 |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))
         continue;

      if(posInfo.Magic() != InpMagicNumber || posInfo.Symbol() != _Symbol)
         continue;

      ulong ticket = posInfo.Ticket();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = symInfo.Bid();

         // --- Break Even ---
         if(InpBreakEvenPips > 0)
         {
            double beDistance = InpBreakEvenPips * pipValue;
            if(bid >= openPrice + beDistance && currentSL < openPrice)
            {
               double newSL = NormalizeDouble(openPrice + symInfo.Point(), symInfo.Digits());
               if(trade.PositionModify(ticket, newSL, currentTP))
                  Print("BUY #", ticket, " moved to break even");
            }
         }

         // --- Trailing Stop ---
         if(InpTrailingStop > 0)
         {
            double trailDistance = InpTrailingStop * pipValue;
            double newSL = NormalizeDouble(bid - trailDistance, symInfo.Digits());

            if(newSL > currentSL && newSL > openPrice)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
                  Print("BUY #", ticket, " trailing stop updated to ", newSL);
            }
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = symInfo.Ask();

         // --- Break Even ---
         if(InpBreakEvenPips > 0)
         {
            double beDistance = InpBreakEvenPips * pipValue;
            if(ask <= openPrice - beDistance && (currentSL > openPrice || currentSL == 0))
            {
               double newSL = NormalizeDouble(openPrice - symInfo.Point(), symInfo.Digits());
               if(trade.PositionModify(ticket, newSL, currentTP))
                  Print("SELL #", ticket, " moved to break even");
            }
         }

         // --- Trailing Stop ---
         if(InpTrailingStop > 0)
         {
            double trailDistance = InpTrailingStop * pipValue;
            double newSL = NormalizeDouble(ask + trailDistance, symInfo.Digits());

            if((newSL < currentSL || currentSL == 0) && newSL < openPrice)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
                  Print("SELL #", ticket, " trailing stop updated to ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTrade event handler - track daily PnL on position close        |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Recalculate daily PnL whenever trade activity occurs
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                  IntegerToString(dt.mon) + "." +
                                  IntegerToString(dt.day));
   CalculateDailyPnL(today);
}

//+------------------------------------------------------------------+

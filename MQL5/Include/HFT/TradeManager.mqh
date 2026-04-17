//+------------------------------------------------------------------+
//|                                              TradeManager.mqh    |
//|                  HFT Scalper Pro - Trade Execution & Management   |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_TRADE_MANAGER_MQH__
#define __HFT_TRADE_MANAGER_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"
#include "RiskManager.mqh"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

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
   SPositionTrack*   FindTrackedPosition(ulong ticket);
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
   void              ManagePartialClose(ulong ticket, SPositionTrack &track, bool isBuy);
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

      // Find tracked position
      SPositionTrack *track = FindTrackedPosition(ticket);

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
      if(track != NULL && (TP1_Points > 0 || TP2_Points > 0 || TP3_Points > 0))
         ManagePartialClose(ticket, track, isBuy);

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
   SPositionTrack *track = FindTrackedPosition(ticket);
   if(track != NULL && track.beApplied) return; // Already applied

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
            if(track != NULL) track.beApplied = true;
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
            if(track != NULL) track.beApplied = true;
            m_utils.Log("SELL #" + IntegerToString(ticket) + " moved to break-even", LOG_DETAIL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage partial close at TP levels                                 |
//+------------------------------------------------------------------+
void CTradeManager::ManagePartialClose(ulong ticket, SPositionTrack &track, bool isBuy)
{
   double currentPrice = isBuy ? m_utils.GetBid() : m_utils.GetAsk();
   double openPrice = track.openPrice;

   // TP1
   if(!track.tp1Hit && TP1_Points > 0 && TP1_Close_Percent > 0)
   {
      double tp1Price = CalculateTP1(isBuy, openPrice);
      bool tp1Reached = isBuy ? (currentPrice >= tp1Price) : (currentPrice <= tp1Price);

      if(tp1Reached)
      {
         if(PartialClose(ticket, TP1_Close_Percent))
         {
            track.tp1Hit = true;
            m_utils.Log("#" + IntegerToString(ticket) + " TP1 hit, closed " + DoubleToString(TP1_Close_Percent, 0) + "%", LOG_BASIC);

            // Move to BE after TP1 if configured
            if(BE_After_TP1 && !track.beApplied)
            {
               m_posInfo.SelectByTicket(ticket);
               double newSL = m_utils.NormalizePrice(openPrice + BE_Offset_Points * m_utils.Point() * (isBuy ? 1 : -1));
               m_trade.PositionModify(ticket, newSL, m_posInfo.TakeProfit());
               track.beApplied = true;
            }
         }
      }
   }

   // TP2
   if(track.tp1Hit && !track.tp2Hit && TP2_Points > 0 && TP2_Close_Percent > 0)
   {
      double tp2Price = CalculateTP2(isBuy, openPrice);
      bool tp2Reached = isBuy ? (currentPrice >= tp2Price) : (currentPrice <= tp2Price);

      if(tp2Reached)
      {
         if(PartialClose(ticket, TP2_Close_Percent))
         {
            track.tp2Hit = true;
            m_utils.Log("#" + IntegerToString(ticket) + " TP2 hit, closed " + DoubleToString(TP2_Close_Percent, 0) + "%", LOG_BASIC);
         }
      }
   }

   // TP3
   if(track.tp2Hit && !track.tp3Hit && TP3_Points > 0 && TP3_Close_Percent > 0)
   {
      double tp3Price = CalculateTP3(isBuy, openPrice);
      bool tp3Reached = isBuy ? (currentPrice >= tp3Price) : (currentPrice <= tp3Price);

      if(tp3Reached)
      {
         ClosePosition(ticket); // Close remaining
         track.tp3Hit = true;
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
   SPositionTrack *track = FindTrackedPosition(ticket);
   if(track == NULL) return;

   double currentPrice = isBuy ? m_utils.GetBid() : m_utils.GetAsk();

   // Hidden SL
   if(Use_Hidden_SL)
   {
      if(isBuy && currentPrice <= track.initialSL)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden SL hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
      if(!isBuy && currentPrice >= track.initialSL)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden SL hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
   }

   // Hidden TP
   if(Use_Hidden_TP)
   {
      if(isBuy && currentPrice >= track.initialTP)
      {
         m_utils.Log("#" + IntegerToString(ticket) + " hidden TP hit", LOG_BASIC);
         ClosePosition(ticket);
         return;
      }
      if(!isBuy && currentPrice <= track.initialTP)
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

   SPositionTrack *parent = FindTrackedPosition(parentTicket);
   if(parent == NULL) return false;
   if(parent.pyramidLevel >= Max_Pyramid_Levels) return false;

   double lots = m_utils.NormalizeLots(parent.initialLots * MathPow(Pyramid_Lot_Ratio, parent.pyramidLevel + 1));

   bool success;
   if(direction > 0)
      success = OpenBuy(lots);
   else
      success = OpenSell(lots);

   if(success)
      parent.pyramidLevel++;

   return success;
}

//+------------------------------------------------------------------+
//| Open averaging order                                              |
//+------------------------------------------------------------------+
bool CTradeManager::OpenAverageOrder(int direction, ulong parentTicket)
{
   if(!Use_Average_Down) return false;

   SPositionTrack *parent = FindTrackedPosition(parentTicket);
   if(parent == NULL) return false;
   if(parent.averageLevel >= Max_Average_Levels) return false;

   double lots = m_utils.NormalizeLots(parent.initialLots * MathPow(Average_Lot_Multiplier, parent.averageLevel + 1));

   bool success;
   if(direction > 0)
      success = OpenBuy(lots);
   else
      success = OpenSell(lots);

   if(success)
      parent.averageLevel++;

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

   SPositionTrack &t = m_trackedPositions[m_trackedCount - 1];
   t.ticket = ticket;
   t.openPrice = openPrice;
   t.initialSL = sl;
   t.initialTP = tp;
   t.initialLots = lots;
   t.openTime = TimeCurrent();
   t.beApplied = false;
   t.tp1Hit = false;
   t.tp2Hit = false;
   t.tp3Hit = false;
   t.pyramidLevel = 0;
   t.averageLevel = 0;
   t.gridLevel = 0;
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
//| Find tracked position pointer                                     |
//+------------------------------------------------------------------+
SPositionTrack* CTradeManager::FindTrackedPosition(ulong ticket)
{
   for(int i = 0; i < m_trackedCount; i++)
   {
      if(m_trackedPositions[i].ticket == ticket)
         return GetPointer(m_trackedPositions[i]);
   }
   return NULL;
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

#endif // __HFT_TRADE_MANAGER_MQH__

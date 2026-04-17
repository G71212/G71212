//+------------------------------------------------------------------+
//|                                                RiskManager.mqh   |
//|                     HFT Scalper Pro - Risk Management Module      |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_RISK_MANAGER_MQH__
#define __HFT_RISK_MANAGER_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"
#include <Trade\PositionInfo.mqh>

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

#endif // __HFT_RISK_MANAGER_MQH__

//+------------------------------------------------------------------+
//|                                                  Dashboard.mqh   |
//|                HFT Scalper Pro - On-Chart Dashboard & HUD         |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_DASHBOARD_MQH__
#define __HFT_DASHBOARD_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"
#include "RiskManager.mqh"
#include "SessionFilter.mqh"

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

#endif // __HFT_DASHBOARD_MQH__

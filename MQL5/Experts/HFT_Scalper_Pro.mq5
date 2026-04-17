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
#property copyright   "HFT Scalper Pro"
#property link        "https://github.com/G71212/G71212"
#property version     "1.00"
#property description "Hybrid HFT Scalping EA with ~630 parameters"
#property description "Multi-indicator confluence, risk management,"
#property description "session filters, dashboard, and modular design."
#property strict

//+------------------------------------------------------------------+
//| Include modules                                                   |
//+------------------------------------------------------------------+
#include <HFT\Inputs.mqh>
#include <HFT\Utils.mqh>
#include <HFT\SignalEngine.mqh>
#include <HFT\RiskManager.mqh>
#include <HFT\TradeManager.mqh>
#include <HFT\SessionFilter.mqh>
#include <HFT\Dashboard.mqh>

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
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { Print("[HFT] BLOCKED: Terminal trade not allowed"); return; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) { Print("[HFT] BLOCKED: MQL trade not allowed"); return; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) { Print("[HFT] BLOCKED: Account trade not allowed"); return; }

   // --- Spread check ---
   if(!g_tradeMgr.IsSpreadOK()) { Print("[HFT] BLOCKED: Spread too high: ", DoubleToString(g_utils.GetSpreadPoints(),1)); return; }

   // --- Session/Time filter ---
   if(!g_sessionFilter.CanTrade()) return; // Already logs inside

   // --- Risk management pre-trade checks ---
   if(!g_riskMgr.CanOpenTrade()) return; // Already logs inside

   // --- Generate trade signal ---
   int signal = g_signals.GetSignal();

   if(signal == 0)
   {
      static datetime lastNoSignalLog = 0;
      if(TimeCurrent() - lastNoSignalLog >= 60) // Log once per minute
      {
         Print("[HFT] No signal. BuyScore=", g_signals.GetBuyScore(),
               " SellScore=", g_signals.GetSellScore(),
               " Spread=", DoubleToString(g_utils.GetSpreadPoints(), 1),
               " Bars=", g_barsSinceLastTrade);
         lastNoSignalLog = TimeCurrent();
      }
      return;
   }

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

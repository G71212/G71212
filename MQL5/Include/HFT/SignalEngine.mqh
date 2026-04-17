//+------------------------------------------------------------------+
//|                                                SignalEngine.mqh   |
//|                    HFT Scalper Pro - Signal Generation Engine      |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_SIGNAL_ENGINE_MQH__
#define __HFT_SIGNAL_ENGINE_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"

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

#endif // __HFT_SIGNAL_ENGINE_MQH__

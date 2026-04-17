//+------------------------------------------------------------------+
//|                                                      Utils.mqh   |
//|                      HFT Scalper Pro - Utility Functions           |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_UTILS_MQH__
#define __HFT_UTILS_MQH__

#include "Inputs.mqh"
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

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

#endif // __HFT_UTILS_MQH__

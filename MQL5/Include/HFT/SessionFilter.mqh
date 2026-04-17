//+------------------------------------------------------------------+
//|                                             SessionFilter.mqh    |
//|              HFT Scalper Pro - Session, Time & News Filters       |
//+------------------------------------------------------------------+
#property copyright "HFT Scalper Pro"
#property strict

#ifndef __HFT_SESSION_FILTER_MQH__
#define __HFT_SESSION_FILTER_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"

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

#endif // __HFT_SESSION_FILTER_MQH__

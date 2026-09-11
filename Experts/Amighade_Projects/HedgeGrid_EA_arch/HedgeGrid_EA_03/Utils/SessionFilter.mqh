//+------------------------------------------------------------------+
//| SessionFilter.mqh                                                 |
//| Trading session filter with DST-aware London and New York        |
//| Source: tested functions from CandleMultiOrder EA Rev 8.6        |
//| Sessions: London, New York, Tokyo + 2 custom time windows        |
//| All times are UTC (GMT)                                          |
//+------------------------------------------------------------------+
#ifndef SESSION_FILTER_MQH
#define SESSION_FILTER_MQH

#include "../Inputs.mqh"
#include "DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Get current UTC time                                             |
//+------------------------------------------------------------------+
datetime GetUTCTime()
{
   return TimeGMT();
}

//+------------------------------------------------------------------+
//| Helper: extract hour from datetime                               |
//+------------------------------------------------------------------+
int GetHour(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.hour;
}

//+------------------------------------------------------------------+
//| Helper: extract minute from datetime                             |
//+------------------------------------------------------------------+
int GetMinute(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.min;
}

//+------------------------------------------------------------------+
//| Helper: build datetime from components                           |
//+------------------------------------------------------------------+
datetime MakeTime(int y, int m, int d, int h, int mi, int s)
{
   MqlDateTime dt;
   dt.year = y; dt.mon = m; dt.day = d;
   dt.hour = h; dt.min = mi; dt.sec = s;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| UK Daylight Saving Time check                                    |
//| DST: last Sunday March 01:00 UTC → last Sunday October 01:00 UTC |
//+------------------------------------------------------------------+
bool IsUKDST(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int year = dt.year;

   datetime marchLast = MakeTime(year, 3, 31, 1, 0, 0);
   TimeToStruct(marchLast, dt);
   int marchSunday = 31 - dt.day_of_week;

   datetime octLast = MakeTime(year, 10, 31, 1, 0, 0);
   TimeToStruct(octLast, dt);
   int octSunday = 31 - dt.day_of_week;

   datetime start = MakeTime(year, 3,  marchSunday, 1, 0, 0);
   datetime end   = MakeTime(year, 10, octSunday,   1, 0, 0);

   return (t >= start && t < end);
}

//+------------------------------------------------------------------+
//| US Daylight Saving Time check                                    |
//| DST: 2nd Sunday March 02:00 → 1st Sunday November 02:00         |
//+------------------------------------------------------------------+
bool IsUSDST(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int year = dt.year;

   datetime march1 = MakeTime(year, 3, 1, 2, 0, 0);
   TimeToStruct(march1, dt);
   int firstSunday  = (7 - dt.day_of_week) % 7 + 1;
   int secondSunday = firstSunday + 7;

   datetime nov1 = MakeTime(year, 11, 1, 2, 0, 0);
   TimeToStruct(nov1, dt);
   int novSunday = (7 - dt.day_of_week) % 7 + 1;

   datetime start = MakeTime(year, 3,  secondSunday, 2, 0, 0);
   datetime end   = MakeTime(year, 11, novSunday,    2, 0, 0);

   return (t >= start && t < end);
}

//+------------------------------------------------------------------+
//| London session check (DST-aware)                                 |
//| Winter: 08:00-17:00 UTC  Summer: 07:00-16:00 UTC                |
//+------------------------------------------------------------------+
bool IsLondonSessionOpen()
{
   datetime utc  = GetUTCTime();
   int      h    = GetHour(utc);
   int      m    = GetMinute(utc);
   int      now  = h * 60 + m;

   if(IsUKDST(utc))
      return (now >= 7*60  && now < 16*60);  // Summer
   else
      return (now >= 8*60  && now < 17*60);  // Winter
}

//+------------------------------------------------------------------+
//| New York session check (DST-aware)                               |
//| Winter: 13:00-22:00 UTC  Summer: 12:00-21:00 UTC                |
//+------------------------------------------------------------------+
bool IsNewYorkSessionOpen()
{
   datetime utc  = GetUTCTime();
   int      h    = GetHour(utc);
   int      m    = GetMinute(utc);
   int      now  = h * 60 + m;

   if(IsUSDST(utc))
      return (now >= 12*60 && now < 21*60);  // Summer
   else
      return (now >= 13*60 && now < 22*60);  // Winter
}

//+------------------------------------------------------------------+
//| Tokyo session check                                              |
//| 00:00-09:00 UTC (no DST adjustment needed)                      |
//+------------------------------------------------------------------+
bool IsTokyoSessionOpen()
{
   int h = GetHour(GetUTCTime());
   return (h >= 0 && h < 9);
}

//+------------------------------------------------------------------+
//| Check if current UTC time is inside a custom HH:MM-HH:MM window |
//| Supports overnight sessions (e.g. "22:00-02:00")                |
//+------------------------------------------------------------------+
bool IsInTimeWindow(string window)
{
   // Expect exactly "HH:MM-HH:MM" = 11 chars
   if(StringLen(window) != 11) return false;
   if(StringGetCharacter(window, 5) != '-') return false;

   int sh = (int)StringToInteger(StringSubstr(window, 0, 2));
   int sm = (int)StringToInteger(StringSubstr(window, 3, 2));
   int eh = (int)StringToInteger(StringSubstr(window, 6, 2));
   int em = (int)StringToInteger(StringSubstr(window, 9, 2));

   // Validate
   if(sh < 0 || sh > 23 || sm < 0 || sm > 59) return false;
   if(eh < 0 || eh > 23 || em < 0 || em > 59) return false;

   datetime utcNow = GetUTCTime();
   int now   = GetHour(utcNow) * 60 + GetMinute(utcNow);
   int start = sh * 60 + sm;
   int end   = eh * 60 + em;

   // Handle overnight window
   if(end < start)
      return (now >= start || now < end);

   return (now >= start && now < end);
}

//+------------------------------------------------------------------+
//| Master session check — returns true if trading allowed now       |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
   if(InpUseLondonSession  && IsLondonSessionOpen())   return true;
   if(InpUseNewYorkSession && IsNewYorkSessionOpen())  return true;
   if(InpUseTokyoSession   && IsTokyoSessionOpen())    return true;

   if(InpUseCustomWindow1 && IsInTimeWindow(InpCustomWindow1Start + "-" + InpCustomWindow1End)) return true;
   if(InpUseCustomWindow2 && IsInTimeWindow(InpCustomWindow2Start + "-" + InpCustomWindow2End)) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Get name of currently active session (for dashboard/logging)    |
//+------------------------------------------------------------------+
string GetActiveSessionName()
{
   if(InpUseLondonSession  && IsLondonSessionOpen())   return "London";
   if(InpUseNewYorkSession && IsNewYorkSessionOpen())  return "New York";
   if(InpUseTokyoSession   && IsTokyoSessionOpen())    return "Tokyo";
   if(InpUseCustomWindow1  && IsInTimeWindow(InpCustomWindow1Start + "-" + InpCustomWindow1End)) return "Custom 1";
   if(InpUseCustomWindow2  && IsInTimeWindow(InpCustomWindow2Start + "-" + InpCustomWindow2End)) return "Custom 2";
   return "None";
}

#endif

//+------------------------------------------------------------------+
//| SessionFilter.mqh                                                 |
//| Trading session filter: London, New York, Tokyo + 2 custom       |
//| All times are GMT                                                |
//+------------------------------------------------------------------+
#ifndef SESSION_FILTER_MQH
#define SESSION_FILTER_MQH

#include "../Inputs.mqh"
#include "DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Session time ranges in GMT (hour, minute)                        |
//+------------------------------------------------------------------+
struct SessionTime
  {
   int startHour;
   int startMin;
   int endHour;
   int endMin;
  };

// Fixed session definitions (GMT)
const SessionTime SESSION_LONDON   = {8,  0, 17, 0};
const SessionTime SESSION_NEWYORK  = {13, 0, 22, 0};
const SessionTime SESSION_TOKYO    = {0,  0,  9, 0};

//+------------------------------------------------------------------+
//| Parse time string "HH:MM" into hours and minutes                 |
//+------------------------------------------------------------------+
bool ParseTimeString(string timeStr, int &hour, int &minute)
  {
   string parts[];
   int count = StringSplit(timeStr, ':', parts);
   if(count != 2) return false;
   hour   = (int)StringToInteger(parts[0]);
   minute = (int)StringToInteger(parts[1]);
   return (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
  }

//+------------------------------------------------------------------+
//| Check if current GMT time is within a session range              |
//+------------------------------------------------------------------+
bool IsInSession(SessionTime &session)
  {
   datetime gmtNow = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmtNow, dt);

   int nowMinutes   = dt.hour * 60 + dt.min;
   int startMinutes = session.startHour * 60 + session.startMin;
   int endMinutes   = session.endHour   * 60 + session.endMin;

   // Handle sessions that cross midnight
   if(startMinutes <= endMinutes)
      return (nowMinutes >= startMinutes && nowMinutes < endMinutes);
   else
      return (nowMinutes >= startMinutes || nowMinutes < endMinutes);
  }

//+------------------------------------------------------------------+
//| Check if current time is within a custom window                  |
//+------------------------------------------------------------------+
bool IsInCustomWindow(string startStr, string endStr)
  {
   int startHour, startMin, endHour, endMin;
   if(!ParseTimeString(startStr, startHour, startMin)) return false;
   if(!ParseTimeString(endStr,   endHour,   endMin))   return false;

   SessionTime custom;
   custom.startHour = startHour;
   custom.startMin  = startMin;
   custom.endHour   = endHour;
   custom.endMin    = endMin;

   return IsInSession(custom);
  }

//+------------------------------------------------------------------+
//| Master session check — returns true if trading is allowed now    |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
  {
   // Check standard sessions
   if(InpUseLondonSession  && IsInSession((SessionTime)SESSION_LONDON))   return true;
   if(InpUseNewYorkSession && IsInSession((SessionTime)SESSION_NEWYORK))  return true;
   if(InpUseTokyoSession   && IsInSession((SessionTime)SESSION_TOKYO))    return true;

   // Check custom windows
   if(InpUseCustomWindow1 && IsInCustomWindow(InpCustomWindow1Start, InpCustomWindow1End)) return true;
   if(InpUseCustomWindow2 && IsInCustomWindow(InpCustomWindow2Start, InpCustomWindow2End)) return true;

   return false;
  }

//+------------------------------------------------------------------+
//| Get name of currently active session (for logging/dashboard)     |
//+------------------------------------------------------------------+
string GetActiveSessionName()
  {
   if(InpUseLondonSession  && IsInSession((SessionTime)SESSION_LONDON))   return "London";
   if(InpUseNewYorkSession && IsInSession((SessionTime)SESSION_NEWYORK))  return "New York";
   if(InpUseTokyoSession   && IsInSession((SessionTime)SESSION_TOKYO))    return "Tokyo";
   if(InpUseCustomWindow1  && IsInCustomWindow(InpCustomWindow1Start, InpCustomWindow1End)) return "Custom 1";
   if(InpUseCustomWindow2  && IsInCustomWindow(InpCustomWindow2Start, InpCustomWindow2End)) return "Custom 2";
   return "None";
  }


#endif
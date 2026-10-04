//+------------------------------------------------------------------+
//| BarUtils.mqh                                                      |
//| Shared new-candle detection.                                      |
//| Lives in Utils (not inside any engine) so multiple engines can    |
//| each track their own "did a new bar start" state independently   |
//| without duplicating the detection logic or crossing engines.     |
//+------------------------------------------------------------------+
#ifndef BAR_UTILS_MQH
#define BAR_UTILS_MQH

//+------------------------------------------------------------------+
//| Returns true exactly once per new bar, for the given tracker.    |
//| Caller owns the tracker variable (e.g. a field in GridState) so  |
//| independent consumers (grid-check, recenter, ...) don't collide. |
//+------------------------------------------------------------------+
bool IsNewBar(datetime &tracker)
  {
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == 0) return false; // no data yet
   if(currentBarTime != tracker)
     {
      tracker = currentBarTime;
      return true;
     }
   return false;
  }

#endif

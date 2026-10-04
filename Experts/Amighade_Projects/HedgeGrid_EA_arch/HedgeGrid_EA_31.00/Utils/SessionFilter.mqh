#ifndef SESSION_FILTER_MQH
#define SESSION_FILTER_MQH

#include "../Inputs.mqh"

int StrategyUTCMinute()
  {
   MqlDateTime t = {};
   TimeToStruct(TimeGMT(), t);
   return t.hour * 60 + t.min;
  }

bool StrategyUKDST(datetime utc)
  {
   MqlDateTime t = {};
   TimeToStruct(utc, t);
   MqlDateTime march = {}, october = {};
   TimeToStruct(StringToTime(StringFormat("%04d.03.31 01:00", t.year)), march);
   TimeToStruct(StringToTime(StringFormat("%04d.10.31 01:00", t.year)), october);
   datetime start = StringToTime(StringFormat("%04d.03.%02d 01:00", t.year, 31 - march.day_of_week));
   datetime end = StringToTime(StringFormat("%04d.10.%02d 01:00", t.year, 31 - october.day_of_week));
   return utc >= start && utc < end;
  }

bool StrategyUSDST(datetime utc)
  {
   MqlDateTime t = {};
   TimeToStruct(utc, t);
   MqlDateTime march = {}, november = {};
   TimeToStruct(StringToTime(StringFormat("%04d.03.01 02:00", t.year)), march);
   TimeToStruct(StringToTime(StringFormat("%04d.11.01 02:00", t.year)), november);
   int marchSunday = (7 - march.day_of_week) % 7 + 8;
   int novemberSunday = (7 - november.day_of_week) % 7 + 1;
   datetime start = StringToTime(StringFormat("%04d.03.%02d 02:00", t.year, marchSunday));
   datetime end = StringToTime(StringFormat("%04d.11.%02d 02:00", t.year, novemberSunday));
   return utc >= start && utc < end;
  }

bool StrategyInWindow(string window, int nowMinute)
  {
   if(StringLen(window) != 11 || StringGetCharacter(window, 5) != '-') return false;
   int sh = (int)StringToInteger(StringSubstr(window, 0, 2));
   int sm = (int)StringToInteger(StringSubstr(window, 3, 2));
   int eh = (int)StringToInteger(StringSubstr(window, 6, 2));
   int em = (int)StringToInteger(StringSubstr(window, 9, 2));
   if(sh > 23 || eh > 23 || sm > 59 || em > 59) return false;
   int start = sh * 60 + sm, end = eh * 60 + em;
   return (end < start) ? (nowMinute >= start || nowMinute < end)
                        : (nowMinute >= start && nowMinute < end);
  }

bool IsSessionAllowed()
  {
   if(!UseTimeFilter) return true;
   datetime utc = TimeGMT();
   int now = StrategyUTCMinute();
   bool london = StrategyUKDST(utc) ? (now >= 420 && now < 930) : (now >= 480 && now < 990);
   bool newYork = StrategyUSDST(utc) ? (now >= 810 && now < 1200) : (now >= 870 && now < 1260);
   MqlDateTime t = {};
   TimeToStruct(utc, t);
   bool asia = t.hour < 6;
   return (EnableLondon && london) || (EnableNewYork && newYork) || (EnableAsia && asia) ||
          (StringLen(ExtraWindow1) > 0 && StrategyInWindow(ExtraWindow1, now)) ||
          (StringLen(ExtraWindow2) > 0 && StrategyInWindow(ExtraWindow2, now));
  }

#endif

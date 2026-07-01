//+------------------------------------------------------------------+
//| SessionFilter.mqh                                                 |
//| Trading session filter — matches CandleMultiOrder EA pattern     |
//| UseTimeFilter gate + London/NewYork/Asia + 2 extra windows       |
//+------------------------------------------------------------------+
#ifndef SESSION_FILTER_MQH
#define SESSION_FILTER_MQH

#include "../Inputs.mqh"

datetime GetUTCTime() { return TimeGMT(); }
int GetHour(datetime t)   { MqlDateTime st; TimeToStruct(t,st); return st.hour; }
int GetMinute(datetime t) { MqlDateTime st; TimeToStruct(t,st); return st.min;  }

datetime MakeTime(int y,int m,int d,int h,int mi,int s)
{
   MqlDateTime dt;
   dt.year=y; dt.mon=m; dt.day=d; dt.hour=h; dt.min=mi; dt.sec=s;
   return StructToTime(dt);
}

bool IsUKDST(datetime t)
{
   MqlDateTime dt; TimeToStruct(t,dt);
   int year=dt.year;
   datetime mL=MakeTime(year,3,31,1,0,0); TimeToStruct(mL,dt);
   int mS=31-dt.day_of_week;
   datetime oL=MakeTime(year,10,31,1,0,0); TimeToStruct(oL,dt);
   int oS=31-dt.day_of_week;
   return (t>=MakeTime(year,3,mS,1,0,0) && t<MakeTime(year,10,oS,1,0,0));
}

bool IsUSDST(datetime t)
{
   MqlDateTime dt; TimeToStruct(t,dt);
   int year=dt.year;
   datetime m1=MakeTime(year,3,1,2,0,0); TimeToStruct(m1,dt);
   int fS=(7-dt.day_of_week)%7+1, sS=fS+7;
   datetime n1=MakeTime(year,11,1,2,0,0); TimeToStruct(n1,dt);
   int nS=(7-dt.day_of_week)%7+1;
   return (t>=MakeTime(year,3,sS,2,0,0) && t<MakeTime(year,11,nS,2,0,0));
}

// London — stock session hours (matches CandleMultiOrder reference)
bool IsLondonStockOpen()
{
   datetime utc=GetUTCTime();
   int now=GetHour(utc)*60+GetMinute(utc);
   return IsUKDST(utc) ? (now>=7*60 && now<15*60+30) : (now>=8*60 && now<16*60+30);
}

// New York — stock session hours
bool IsNewYorkStockOpen()
{
   datetime utc=GetUTCTime();
   int now=GetHour(utc)*60+GetMinute(utc);
   return IsUSDST(utc) ? (now>=13*60+30 && now<20*60) : (now>=14*60+30 && now<21*60);
}

// Asia / Tokyo
bool IsAsiaOpen()
{
   return (GetHour(GetUTCTime()) < 6);
}

// Custom HH:MM-HH:MM window, supports overnight (e.g. "22:00-02:00")
bool IsInTimeWindow(string window)
{
   if(StringLen(window) != 11) return false;
   if(StringGetCharacter(window,5) != '-') return false;

   int sh=(int)StringToInteger(StringSubstr(window,0,2));
   int sm=(int)StringToInteger(StringSubstr(window,3,2));
   int eh=(int)StringToInteger(StringSubstr(window,6,2));
   int em=(int)StringToInteger(StringSubstr(window,9,2));
   if(sh<0||sh>23||sm<0||sm>59||eh<0||eh>23||em<0||em>59) return false;

   int now=GetHour(GetUTCTime())*60+GetMinute(GetUTCTime());
   int start=sh*60+sm, end=eh*60+em;
   return (end<start) ? (now>=start||now<end) : (now>=start&&now<end);
}

//+------------------------------------------------------------------+
//| Master session check — returns true if trading allowed now       |
//| If UseTimeFilter is false, trading is always allowed             |
//+------------------------------------------------------------------+
bool IsSessionAllowed()
{
   if(!UseTimeFilter) return true;

   bool allow = false;
   if(EnableLondon)  allow |= IsLondonStockOpen();
   if(EnableNewYork) allow |= IsNewYorkStockOpen();
   if(EnableAsia)    allow |= IsAsiaOpen();
   if(StringLen(ExtraWindow1) > 0) allow |= IsInTimeWindow(ExtraWindow1);
   if(StringLen(ExtraWindow2) > 0) allow |= IsInTimeWindow(ExtraWindow2);
   return allow;
}

//+------------------------------------------------------------------+
//| Get name of currently active session (for dashboard/logging)    |
//+------------------------------------------------------------------+
string GetActiveSessionName()
{
   if(!UseTimeFilter) return "Always On";
   if(EnableLondon  && IsLondonStockOpen())   return "London";
   if(EnableNewYork && IsNewYorkStockOpen())  return "New York";
   if(EnableAsia    && IsAsiaOpen())          return "Asia";
   if(StringLen(ExtraWindow1)>0 && IsInTimeWindow(ExtraWindow1)) return "Extra 1";
   if(StringLen(ExtraWindow2)>0 && IsInTimeWindow(ExtraWindow2)) return "Extra 2";
   return "None";
}

#endif

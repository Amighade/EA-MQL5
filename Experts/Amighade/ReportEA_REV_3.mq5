#property strict

enum ReportSymbol
{
   REPORT_SYMBOL_ALL = 0,
   REPORT_SYMBOL_XAUUSD,
   REPORT_SYMBOL_BTCUSD,
   REPORT_SYMBOL_DJ30,
   REPORT_SYMBOL_UKOUSD
};

input ReportSymbol    InpReportSymbol  = REPORT_SYMBOL_ALL;
input ENUM_TIMEFRAMES InpReportTF      = PERIOD_CURRENT;
input bool            InpTodayOnly     = true;
input int             InpDaysBack      = 1;
input bool            InpSummaryOnly   = true;
input long InpReportMagicNumber = 0;

datetime GetTodayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

datetime GetFromTime_arch()
{
   if(InpTodayOnly)
      return GetTodayStart();

   return TimeCurrent() - InpDaysBack * 86400;
}



struct ReportPeriod
{
   datetime from;
   datetime to;
};

datetime GetDayStart(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);

   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;

   return StructToTime(dt);
}

ReportPeriod GetFromTime()
{
   ReportPeriod period;

   datetime todayStart = GetDayStart(TimeCurrent());

   if(InpTodayOnly)
   {
      // From today's midnight until now.
      period.from = todayStart;
      period.to   = TimeCurrent();
   }
   else
   {
      // From midnight N days ago until today's midnight.
      int daysBack = MathMax(1, InpDaysBack);

      period.from = todayStart - daysBack * 86400;
      period.to   = todayStart;
   }

   return period;
}



int GetTimeframeCode(ENUM_TIMEFRAMES tf)
{
   int tfCode = (int)tf;
   return (tfCode > 0 ? tfCode : 0);
}

int GetSymbolCode(const string sym)
{
   string s = sym;

   StringToUpper(s);

   if(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == '+')
      s = StringSubstr(s, 0, StringLen(s) - 1);

   int code = 0;

   for(int i = 0; i < StringLen(s); i++)
      code += StringGetCharacter(s, i);

   return 100 + (code % 900);
}

int BuildMagicNumber(const string sym, ENUM_TIMEFRAMES tf)
{
   return GetSymbolCode(sym) * 100000 + GetTimeframeCode(tf);
}

string GetSelectedSymbol()
{
   switch(InpReportSymbol)
   {
      case REPORT_SYMBOL_XAUUSD: return "XAUUSD";
      case REPORT_SYMBOL_BTCUSD: return "BTCUSD";
      case REPORT_SYMBOL_DJ30:   return "DJ30";
      case REPORT_SYMBOL_UKOUSD: return "UKOUSD";
      default:                   return "";
   }
}

string GetFilterLabel()
{
   if(InpReportMagicNumber != 0)
      return "MAGIC_" + IntegerToString((int)InpReportMagicNumber);

   string sym = GetSelectedSymbol();

   if(sym == "" && InpReportTF == PERIOD_CURRENT)
      return "ALL";

   if(sym == "")
      return "ALL_" + EnumToString(InpReportTF);

   if(InpReportTF == PERIOD_CURRENT)
      return sym + "_ALL_TF";

   return sym + "_" + EnumToString(InpReportTF);
}

long GetSelectedMagic()
{
   if(InpReportMagicNumber != 0)
      return InpReportMagicNumber;

   string sym = GetSelectedSymbol();

   if(sym == "")
      return 0;

   if(InpReportTF == PERIOD_CURRENT)
      return 0;

   return BuildMagicNumber(sym, InpReportTF);
}


bool PassMagicFilter(long magic, const string dealSym)
{
   if(InpReportMagicNumber != 0)
      return (magic == InpReportMagicNumber);

   string selectedSym = GetSelectedSymbol();

   if(selectedSym != "")
   {
      if(dealSym != selectedSym && dealSym != selectedSym + "+")
         return false;
   }

   if(InpReportTF == PERIOD_CURRENT)
      return true;

   long selectedMagic = GetSelectedMagic();
   if(selectedMagic == 0)
      return true;

   return (magic == selectedMagic);
}


void AddLotStat(double volume, double &lotValues[], int &lotCounts[])
{
   int size = ArraySize(lotValues);

   for(int i = 0; i < size; i++)
   {
      if(NormalizeDouble(lotValues[i], 2) == NormalizeDouble(volume, 2))
      {
         lotCounts[i]++;
         return;
      }
   }

   ArrayResize(lotValues, size + 1);
   ArrayResize(lotCounts, size + 1);

   lotValues[size] = volume;
   lotCounts[size] = 1;
}

void SortLotStats(double &lotValues[], int &lotCounts[])
{
   int size = ArraySize(lotValues);

   for(int i = 0; i < size - 1; i++)
   {
      for(int j = i + 1; j < size; j++)
      {
         if(lotValues[j] < lotValues[i])
         {
            double tmpLot = lotValues[i];
            lotValues[i] = lotValues[j];
            lotValues[j] = tmpLot;

            int tmpCount = lotCounts[i];
            lotCounts[i] = lotCounts[j];
            lotCounts[j] = tmpCount;
         }
      }
   }
}

void PrintLotStats(double &lotValues[], int &lotCounts[])
{
   int size = ArraySize(lotValues);

   if(size == 0)
   {
      Print("[REPORT] lot usage: none");
      return;
   }

   string line = "[REPORT] lot usage: ";
   int itemsInLine = 0;

   for(int i = 0; i < size; i++)
   {
      string item = DoubleToString(lotValues[i], 2) + " x " + IntegerToString(lotCounts[i]);

      if(itemsInLine > 0)
         item = ", " + item;

      line += item;
      itemsInLine++;

      if(itemsInLine >= 5 || i == size - 1)
      {
         Print(line);
         line = "[REPORT] lot usage: ";
         itemsInLine = 0;
      }
   }
}

void RunHistoryReport()
{
   datetime fromTime = GetFromTime().from;
   datetime toTime   = GetFromTime().to;

   if(!HistorySelect(fromTime, toTime))
   {
      Print("HistorySelect failed");
      return;
   }

   int totalDeals = HistoryDealsTotal();

   int    matchedDeals = 0;
   double totalVolume  = 0.0;
   double totalProfit  = 0.0;
   double totalComm    = 0.0;
   double totalSwap    = 0.0;

   double lotValues[];
   int    lotCounts[];

   PrintFormat("[REPORT] from=%s to=%s filter=%s",
               TimeToString(fromTime, TIME_DATE | TIME_SECONDS),
               TimeToString(toTime, TIME_DATE | TIME_SECONDS),
               GetFilterLabel());

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      long   magic  = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string sym    = HistoryDealGetString(dealTicket, DEAL_SYMBOL);

      if(!PassMagicFilter(magic, sym))
         continue;

      long     type   = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      double   volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double   profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double   comm   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      double   swap   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      datetime t      = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);

      matchedDeals++;
      totalVolume += volume;
      totalProfit += profit;
      totalComm   += comm;
      totalSwap   += swap;

      AddLotStat(volume, lotValues, lotCounts);

      if(!InpSummaryOnly)
      {
         PrintFormat("[REPORT] %s ticket=%I64u sym=%s magic=%I64d type=%d vol=%.2f profit=%.2f comm=%.2f swap=%.2f",
                     TimeToString(t, TIME_DATE | TIME_SECONDS),
                     dealTicket,
                     sym,
                     magic,
                     type,
                     volume,
                     profit,
                     comm,
                     swap);
      }
   }

   PrintFormat("[REPORT] matchedDeals=%d volume=%.2f profit=%.2f comm=%.2f swap=%.2f net=%.2f",
               matchedDeals,
               totalVolume,
               totalProfit,
               totalComm,
               totalSwap,
               totalProfit + totalComm + totalSwap);

   SortLotStats(lotValues, lotCounts);
   PrintLotStats(lotValues, lotCounts);
}

int OnInit()
{
   RunHistoryReport();
   return(INIT_SUCCEEDED);
}

void OnTick()
{
}

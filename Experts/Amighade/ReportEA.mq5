#property strict

enum ReportMagic
{
   MAGIC_ALL         = 0,
   MAGIC_XAUSD_M1    = 10100001,
   MAGIC_XAUSD_M15   = 10100015,
   MAGIC_BTCUSD_M1   = 10200001,
   MAGIC_BTCUSD_M15  = 10200015,
   MAGIC_DJ30_M1     = 10300001,
   MAGIC_DJ30_M15    = 10300015,
   MAGIC_UKOUSD_M1   = 10400001,
   MAGIC_UKOUSD_M15  = 10400015
};

input ReportMagic InpReportMagic = MAGIC_ALL;
input bool        InpTodayOnly   = true;
input int         InpDaysBack    = 1;
input bool        InpSummaryOnly = true;

datetime GetTodayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;

   return StructToTime(dt);
}

datetime GetFromTime()
{
   if(InpTodayOnly)
      return GetTodayStart();

   return TimeCurrent() - InpDaysBack * 86400;
}

bool PassMagicFilter_paused(long magic)
{
   if(InpReportMagic == MAGIC_ALL)
      return true;

   return (magic == (long)InpReportMagic);
}

bool PassMagicFilter(long magic)
{
   if(InpReportMagic == MAGIC_ALL)
      return true;

   if(InpReportMagic == MAGIC_DJ30_M1)
      return (magic == 10300001 || magic == 5551113);

   if(InpReportMagic == MAGIC_DJ30_M15)
      return (magic == 10300015 || magic == 55511132);

   return (magic == (long)InpReportMagic);
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
   datetime fromTime = GetFromTime();
   datetime toTime   = TimeCurrent();

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

   PrintFormat("[REPORT] from=%s to=%s magic=%I64d",
               TimeToString(fromTime, TIME_DATE|TIME_SECONDS),
               TimeToString(toTime, TIME_DATE|TIME_SECONDS),
               (long)InpReportMagic);

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(!PassMagicFilter(magic))
         continue;

      string   sym    = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
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
                     TimeToString(t, TIME_DATE|TIME_SECONDS),
                     dealTicket, sym, magic, type, volume, profit, comm, swap);
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

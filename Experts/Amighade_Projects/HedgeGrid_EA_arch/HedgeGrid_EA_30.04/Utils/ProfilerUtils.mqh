//+------------------------------------------------------------------+
//| ProfilerUtils.mqh                                                |
//| REV 30.04 diagnostic wall-clock profiler                         |
//|                                                                  |
//| Measures elapsed time with GetMicrosecondCount(). Parent timings |
//| intentionally include child timings. Broker calls are timed      |
//| separately so blocking latency can be identified directly.       |
//+------------------------------------------------------------------+
#ifndef PROFILER_UTILS_30_MQH
#define PROFILER_UTILS_30_MQH

#include "../Inputs.mqh"

enum HG30_PROFILE_ID
  {
   PROF30_PROCESS_TRANSACTION_QUEUE,
   PROF30_PROCESS_PENDING_ACTIONS,
   PROF30_ORDERSEND_ASYNC_PLACE,
   PROF30_ORDERSEND_ASYNC_DELETE,
   PROF30_ORDERSEND_ASYNC_CLOSE,
   PROF30_ORDERSEND_ASYNC_MODIFY_SL,

   PROF30_RECONCILE_TRADE_ITEMS,
   PROF30_START_CLEANUP,
   PROF30_COUNT_LIVE_POSITIONS,
   PROF30_COUNT_LIVE_ORDERS,
   PROF30_PROFILE_REPORT_PRINT,

   PROF30_COUNT
  };

ulong g_prof30LastUs[PROF30_COUNT];
ulong g_prof30MaxAllUs[PROF30_COUNT];
ulong g_prof30IntervalMaxUs[PROF30_COUNT];
ulong g_prof30IntervalTotalUs[PROF30_COUNT];
ulong g_prof30IntervalCalls[PROF30_COUNT];

string Profiler30Name(int id)
  {
   switch(id)
     {
      case PROF30_PROCESS_TRANSACTION_QUEUE: return "ProcessTransactionQueue";
      case PROF30_PROCESS_PENDING_ACTIONS: return "ProcessPendingActions";
      case PROF30_ORDERSEND_ASYNC_PLACE: return "OrderSendAsync.Place";
      case PROF30_ORDERSEND_ASYNC_DELETE: return "OrderSendAsync.Delete";
      case PROF30_ORDERSEND_ASYNC_CLOSE: return "OrderSendAsync.Close";
      case PROF30_ORDERSEND_ASYNC_MODIFY_SL: return "OrderSendAsync.ModifySL";
      case PROF30_RECONCILE_TRADE_ITEMS: return "ReconcileTradeItems";
      case PROF30_START_CLEANUP: return "StartCleanup";
      case PROF30_COUNT_LIVE_POSITIONS: return "CountLiveTerminalPositions";
      case PROF30_COUNT_LIVE_ORDERS: return "CountLiveTerminalOrders";
      case PROF30_PROFILE_REPORT_PRINT: return "Profiler.Print";
     }
   return "Unknown";
  }

void Profiler30ResetAll()
  {
   for(int i = 0; i < PROF30_COUNT; i++)
     {
      g_prof30LastUs[i]          = 0;
      g_prof30MaxAllUs[i]        = 0;
      g_prof30IntervalMaxUs[i]   = 0;
      g_prof30IntervalTotalUs[i] = 0;
      g_prof30IntervalCalls[i]   = 0;
     }
  }

void Profiler30Record(int id, ulong startUs)
  {
   if(!InpEnableCpuProfiler) return;
   if(id < 0 || id >= PROF30_COUNT)
      return;

   ulong used = GetMicrosecondCount() - startUs;
   g_prof30LastUs[id] = used;
   g_prof30IntervalTotalUs[id] += used;
   g_prof30IntervalCalls[id]++;

   if(used > g_prof30IntervalMaxUs[id])
      g_prof30IntervalMaxUs[id] = used;
   if(used > g_prof30MaxAllUs[id])
      g_prof30MaxAllUs[id] = used;
  }

void Profiler30PrintAndResetInterval()
  {
   string report = "[REV30.04 FUNCTION PROFILE] interval";
   bool any = false;

   for(int i = 0; i < PROF30_COUNT; i++)
     {
      ulong calls = g_prof30IntervalCalls[i];
      if(calls == 0)
         continue;

      any = true;
      double avgUs = (double)g_prof30IntervalTotalUs[i] / (double)calls;
      report += StringFormat(
         "\n  %s  Last=%I64u us  MaxInt=%I64u us  MaxAll=%I64u us  AvgInt=%.1f us  Calls=%I64u",
         Profiler30Name(i),
         g_prof30LastUs[i],
         g_prof30IntervalMaxUs[i],
         g_prof30MaxAllUs[i],
         avgUs,
         calls);
     }

   // Reset the completed interval first. The Print() below is then recorded
   // into the NEW interval so profiler/logging overhead remains visible.
   for(int i = 0; i < PROF30_COUNT; i++)
     {
      g_prof30IntervalMaxUs[i]   = 0;
      g_prof30IntervalTotalUs[i] = 0;
      g_prof30IntervalCalls[i]   = 0;
     }

   if(any)
     {
      ulong printStart = GetMicrosecondCount();
      Print(report);
      Profiler30Record(PROF30_PROFILE_REPORT_PRINT, printStart);
     }
  }

#endif

//+------------------------------------------------------------------+
//| ProfilerUtils.mqh                                                |
//| REV 22.5 diagnostic function profiler                            |
//|                                                                  |
//| Timing is WALL-CLOCK elapsed time from GetMicrosecondCount().    |
//| Nested timings intentionally overlap: a parent function includes |
//| time spent in its children. Blocking calls (OrderSend, WebRequest,|
//| Sleep) are therefore timed separately so broker/network waiting  |
//| can be distinguished from surrounding EA work.                   |
//+------------------------------------------------------------------+
#ifndef PROFILER_UTILS_MQH
#define PROFILER_UTILS_MQH

enum HG_PROFILE_ID
  {
   PROF_PROCESS_TRANSACTION_QUEUE = 0,
   PROF_HISTORY_DEAL_SELECT,
   PROF_UPDATE_SIDE_AGGREGATE,
   PROF_REBUILD_SIDE_AGGREGATE,

   PROF_PROCESS_FILL_WORK,
   PROF_FILL_PROCESS_ORDER_FILL,
   PROF_FILL_RESNAPSHOT,
   PROF_FILL_UPDATE_OPPOSITE_GRID,
   PROF_PENDING_GRID_REPLACEMENTS,
   PROF_FILL_INSIDE_STRATEGY,
   PROF_FILL_SL_MANAGER,
   PROF_FILL_LOG_HISTORY,

   PROF_EXECUTE_FAST_TASKS,
   PROF_SESSION_TASK,
   PROF_FAST_SL_MANAGER,
   PROF_EXECUTE_MEDIUM_TASKS,
   PROF_MEDIUM_CHECK_BUILD_GRID,
   PROF_BUILD_GRID,
   PROF_MEDIUM_VERIFY_FRESH_GRID,
   PROF_MEDIUM_REFILL_OUTSIDE,
   PROF_MEDIUM_INSIDE_MAINTENANCE,

   PROF_PROCESS_CLEANUP_WORK,
   PROF_CLEANUP_RECONCILE,
   PROF_CLEANUP_SUBMIT_CLOSE,
   PROF_CLEANUP_SUBMIT_DELETE,
   PROF_COUNT_POSITIONS,
   PROF_COUNT_ORDERS,

   PROF_PLACE_PENDING_SINGLE,
   PROF_PLACE_PENDING_ORDER,
   PROF_ORDERSEND_PENDING,
   PROF_DELETE_ORDER,
   PROF_ORDERSEND_DELETE,
   PROF_CLOSE_POSITION,
   PROF_ORDERSEND_CLOSE_SYNC,
   PROF_CLOSE_SLEEP,
   PROF_FAST_CLOSE_POSITION,
   PROF_ORDERSEND_FAST_CLOSE,
   PROF_MODIFY_POSITION_SL,
   PROF_ORDERSEND_MODIFY_SL,
   PROF_SEND_CLOSE_ASYNC,
   PROF_ORDERSEND_ASYNC_CLOSE,
   PROF_SEND_DELETE_ASYNC,
   PROF_ORDERSEND_ASYNC_DELETE,

   PROF_ARM_SL,
   PROF_TRAIL_WALL,
   PROF_APPLY_SL_WINNERS,
   PROF_SNAPSHOT_WINNERS,
   PROF_CALCULATE_SL_CANDIDATE,
   PROF_BASKET_FROM_AGGREGATES,

   PROF_DASHBOARD_UPDATE,
   PROF_BACKGROUND_TASKS,
   PROF_TELEGRAM_SEND,
   PROF_WEBREQUEST_TELEGRAM,

   PROF_COUNT
  };

ulong g_profLastUs[PROF_COUNT];
ulong g_profMaxAllUs[PROF_COUNT];
ulong g_profIntervalMaxUs[PROF_COUNT];
ulong g_profIntervalTotalUs[PROF_COUNT];
ulong g_profIntervalCalls[PROF_COUNT];

string ProfilerName(int id)
  {
   switch(id)
     {
      case PROF_PROCESS_TRANSACTION_QUEUE: return "ProcessTransactionQueue";
      case PROF_HISTORY_DEAL_SELECT: return "HistoryDealSelect";
      case PROF_UPDATE_SIDE_AGGREGATE: return "UpdateSideVolumeAggregate";
      case PROF_REBUILD_SIDE_AGGREGATE: return "RebuildSideVolumeAggregate";
      case PROF_PROCESS_FILL_WORK: return "ProcessFillWork";
      case PROF_FILL_PROCESS_ORDER_FILL: return "Fill.ProcessOrderFill";
      case PROF_FILL_RESNAPSHOT: return "Fill.ReSnapshotIfArmed";
      case PROF_FILL_UPDATE_OPPOSITE_GRID: return "Fill.UpdateOppositeGrid";
      case PROF_PENDING_GRID_REPLACEMENTS: return "ProcessPendingGridReplacements";
      case PROF_FILL_INSIDE_STRATEGY: return "Fill.ProcessInsideStrategy";
      case PROF_FILL_SL_MANAGER: return "Fill.ProcessSLManager";
      case PROF_FILL_LOG_HISTORY: return "Fill.LogHistory";
      case PROF_EXECUTE_FAST_TASKS: return "ExecuteFastTasks";
      case PROF_SESSION_TASK: return "ProcessSessionTask";
      case PROF_FAST_SL_MANAGER: return "Fast.ProcessSLManager";
      case PROF_EXECUTE_MEDIUM_TASKS: return "ExecuteMediumTasks";
      case PROF_MEDIUM_CHECK_BUILD_GRID: return "Medium.CheckAndBuildGrid";
      case PROF_BUILD_GRID: return "BuildGrid";
      case PROF_MEDIUM_VERIFY_FRESH_GRID: return "Medium.VerifyFreshGrid";
      case PROF_MEDIUM_REFILL_OUTSIDE: return "Medium.RefillOutside";
      case PROF_MEDIUM_INSIDE_MAINTENANCE: return "Medium.ProcessInsideMaintenance";
      case PROF_PROCESS_CLEANUP_WORK: return "ProcessCleanupWork";
      case PROF_CLEANUP_RECONCILE: return "Cleanup.ReconcileRequests";
      case PROF_CLEANUP_SUBMIT_CLOSE: return "Cleanup.SubmitClose";
      case PROF_CLEANUP_SUBMIT_DELETE: return "Cleanup.SubmitDelete";
      case PROF_COUNT_POSITIONS: return "CountPositions";
      case PROF_COUNT_ORDERS: return "CountOrders";
      case PROF_PLACE_PENDING_SINGLE: return "PlacePendingSingleAttempt";
      case PROF_PLACE_PENDING_ORDER: return "PlacePendingOrder";
      case PROF_ORDERSEND_PENDING: return "OrderSendAsync.Pending";
      case PROF_DELETE_ORDER: return "DeleteOrderAsync";
      case PROF_ORDERSEND_DELETE: return "OrderSendAsync.Delete";
      case PROF_CLOSE_POSITION: return "ClosePosition";
      case PROF_ORDERSEND_CLOSE_SYNC: return "OrderSend.CloseSync";
      case PROF_CLOSE_SLEEP: return "ClosePosition.Sleep";
      case PROF_FAST_CLOSE_POSITION: return "FastClosePosition";
      case PROF_ORDERSEND_FAST_CLOSE: return "OrderSend.FastClose";
      case PROF_MODIFY_POSITION_SL: return "ModifyPositionSLAsync";
      case PROF_ORDERSEND_MODIFY_SL: return "OrderSendAsync.ModifySL";
      case PROF_SEND_CLOSE_ASYNC: return "SendClosePositionAsync";
      case PROF_ORDERSEND_ASYNC_CLOSE: return "OrderSendAsync.Close";
      case PROF_SEND_DELETE_ASYNC: return "SendDeleteOrderAsync";
      case PROF_ORDERSEND_ASYNC_DELETE: return "OrderSendAsync.DeleteCleanup";
      case PROF_ARM_SL: return "ArmSL";
      case PROF_TRAIL_WALL: return "TrailWall";
      case PROF_APPLY_SL_WINNERS: return "ApplySLToWinners";
      case PROF_SNAPSHOT_WINNERS: return "SnapshotWinners";
      case PROF_CALCULATE_SL_CANDIDATE: return "CalculateSLCandidate";
      case PROF_BASKET_FROM_AGGREGATES: return "CalculateBasketProfitFromAggregates";
      case PROF_DASHBOARD_UPDATE: return "UpdateDashboard";
      case PROF_BACKGROUND_TASKS: return "ExecuteBackgroundTasks";
      case PROF_TELEGRAM_SEND: return "SendTelegramMessage";
      case PROF_WEBREQUEST_TELEGRAM: return "WebRequest.Telegram";
     }
   return "Unknown";
  }

void ProfilerResetAll()
  {
   for(int i = 0; i < PROF_COUNT; i++)
     {
      g_profLastUs[i]          = 0;
      g_profMaxAllUs[i]        = 0;
      g_profIntervalMaxUs[i]   = 0;
      g_profIntervalTotalUs[i] = 0;
      g_profIntervalCalls[i]   = 0;
     }
  }

void ProfilerRecord(int id, ulong startUs)
  {
   if(id < 0 || id >= PROF_COUNT)
      return;

   ulong used = GetMicrosecondCount() - startUs;
   g_profLastUs[id] = used;
   g_profIntervalTotalUs[id] += used;
   g_profIntervalCalls[id]++;

   if(used > g_profIntervalMaxUs[id])
      g_profIntervalMaxUs[id] = used;
   if(used > g_profMaxAllUs[id])
      g_profMaxAllUs[id] = used;
  }

void ProfilerPrintAndResetInterval()
  {
   string report = "[FUNCTION PROFILE] 10s interval";
   bool any = false;

   for(int i = 0; i < PROF_COUNT; i++)
     {
      ulong calls = g_profIntervalCalls[i];
      if(calls == 0)
         continue;

      any = true;
      double avgUs = (double)g_profIntervalTotalUs[i] / (double)calls;
      report += StringFormat(
         "\n  %s  Last=%I64u us  Max10s=%I64u us  MaxAll=%I64u us  Avg10s=%.1f us  Calls=%I64u",
         ProfilerName(i),
         g_profLastUs[i],
         g_profIntervalMaxUs[i],
         g_profMaxAllUs[i],
         avgUs,
         calls);
     }

   if(any)
      Print(report);

   for(int i = 0; i < PROF_COUNT; i++)
     {
      g_profIntervalMaxUs[i]   = 0;
      g_profIntervalTotalUs[i] = 0;
      g_profIntervalCalls[i]   = 0;
     }
  }

#endif

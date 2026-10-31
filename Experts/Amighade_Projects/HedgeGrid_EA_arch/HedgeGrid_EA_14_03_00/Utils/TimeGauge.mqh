// Elapsed wall time, including synchronous broker/network waits.
// Nested measurements overlap; do not add parent and child durations.
#ifndef TIME_GAUGE_MQH
#define TIME_GAUGE_MQH

#include "../Inputs.mqh"

enum ENUM_TIME_GAUGE_ID
{
   GAUGE_RUNSCHEDULER,
   GAUGE_PROCESSONEQUEUEDTRANSACTION,
   GAUGE_EXECUTEFASTTASKS,
   GAUGE_EXECUTEMEDIUMTASKS,
   GAUGE_EXECUTESLOWTASKS,
   GAUGE_UPDATESIDEVOLUMEAGGREGATE,
   GAUGE_PROCESSORDERFILL,
   GAUGE_CHECKANDBUILDGRID,
   GAUGE_BUILDGRID,
   GAUGE_VERIFYFRESHGRID,
   GAUGE_REFILLOUTSIDE,
   GAUGE_PROCESSINSIDEMAINTENANCE,
   GAUGE_PROCESSINSIDESTRATEGY,
   GAUGE_REFILLFOLLOWPRICEINSIDE,
   GAUGE_FILLONESIDEINSIDE,
   GAUGE_PROCESSPASSREFILL,
   GAUGE_PLACEREVISITORDER,
   GAUGE_UPDATEOPPOSITEGRID,
   GAUGE_PROCESSSLMANAGER,
   GAUGE_CALCULATESLCANDIDATE,
   GAUGE_APPLYSLTOWINNERS,
   GAUGE_SNAPSHOTWINNERS,
   GAUGE_ARMSL,
   GAUGE_TRAILWALL,
   GAUGE_EXECUTEEMERGENCYCLOSE,
   GAUGE_EXECUTENEXTCLOSESTEP,
   GAUGE_STARTCLEANUPSEQUENCE,
   GAUGE_PLACEPENDINGORDER,
   GAUGE_PLACEPENDINGWITHWIDENING,
   GAUGE_DELETEORDER,
   GAUGE_DELETEALLORDERS,
   GAUGE_CLOSEPOSITION,
   GAUGE_FASTCLOSEPOSITION,
   GAUGE_MODIFYPOSITIONSL,
   GAUGE_COUNTPOSITIONS,
   GAUGE_COUNTORDERS,
   GAUGE_TRIGGERSAFETYSTOP,
   GAUGE_SENDTELEGRAMMESSAGE,
   GAUGE_LOGHISTORY,
   GAUGE_SAVEGRIDSTATE,
   GAUGE_LOADGRIDSTATE,
   GAUGE_BUILDABSPROFITPOSITIONORDER,
   GAUGE_BUILDPROXIMITYORDERORDER,
   GAUGE_GETREQUIREDMARGIN,
   GAUGE_ISSESSIONALLOWED,
   GAUGE_UPDATEDASHBOARD,
   GAUGE_ORDERSEND_PENDING,
   GAUGE_ORDERSEND_DELETE,
   GAUGE_ORDERSEND_CLOSE,
   GAUGE_ORDERSEND_MODIFYSL,
   GAUGE_ORDERSEND_OTHER,
   GAUGE_COUNT
};

string g_gaugeNames[GAUGE_COUNT] =
{
   "RunScheduler",
   "ProcessOneQueuedTransaction",
   "ExecuteFastTasks",
   "ExecuteMediumTasks",
   "ExecuteSlowTasks",
   "UpdateSideVolumeAggregate",
   "ProcessOrderFill",
   "CheckAndBuildGrid",
   "BuildGrid",
   "VerifyFreshGrid",
   "RefillOutside",
   "ProcessInsideMaintenance",
   "ProcessInsideStrategy",
   "RefillFollowPriceInside",
   "FillOneSideInside",
   "ProcessPassRefill",
   "PlaceRevisitOrder",
   "UpdateOppositeGrid",
   "ProcessSLManager",
   "CalculateSLCandidate",
   "ApplySLToWinners",
   "SnapshotWinners",
   "ArmSL",
   "TrailWall",
   "ExecuteEmergencyClose",
   "ExecuteNextCloseStep",
   "StartCleanupSequence",
   "PlacePendingOrder",
   "PlacePendingWithWidening",
   "DeleteOrder",
   "DeleteAllOrders",
   "ClosePosition",
   "FastClosePosition",
   "ModifyPositionSL",
   "CountPositions",
   "CountOrders",
   "TriggerSafetyStop",
   "SendTelegramMessage",
   "LogHistory",
   "SaveGridState",
   "LoadGridState",
   "BuildAbsProfitPositionOrder",
   "BuildProximityOrderOrder",
   "GetRequiredMargin",
   "IsSessionAllowed",
   "UpdateDashboard",
   "OrderSend.Pending",
   "OrderSend.Delete",
   "OrderSend.Close",
   "OrderSend.ModifySL",
   "OrderSend.Other"
};
ulong g_gaugeLastUs[GAUGE_COUNT];
ulong g_gaugeMaxAllUs[GAUGE_COUNT];
ulong g_gaugeMaxIntervalUs[GAUGE_COUNT];
ulong g_gaugeTotalIntervalUs[GAUGE_COUNT];
ulong g_gaugeCalls[GAUGE_COUNT];
ulong g_gaugeReportTimeMs = 0;

void TimeGaugeRecord(int id, ulong startUs)
{
   if(!InpEnableTimeGauge || id < 0 || id >= GAUGE_COUNT) return;
   ulong elapsed = GetMicrosecondCount() - startUs;
   g_gaugeLastUs[id] = elapsed;
   g_gaugeTotalIntervalUs[id] += elapsed;
   g_gaugeCalls[id]++;
   if(elapsed > g_gaugeMaxIntervalUs[id]) g_gaugeMaxIntervalUs[id] = elapsed;
   if(elapsed > g_gaugeMaxAllUs[id]) g_gaugeMaxAllUs[id] = elapsed;
}

// Stack lifetime records every exit, without changing the function's returns.
class CTimeGaugeScope
{
private:
   int m_id;
   ulong m_startUs;
   bool m_enabled;
public:
   CTimeGaugeScope(int id)
   {
      m_id = id;
      m_enabled = InpEnableTimeGauge;
      m_startUs = m_enabled ? GetMicrosecondCount() : 0;
   }
   ~CTimeGaugeScope()
   {
      if(m_enabled) TimeGaugeRecord(m_id, m_startUs);
   }
};

// Same synchronous call and result; only its elapsed time is recorded.
bool TimeGaugeOrderSend(MqlTradeRequest &request, MqlTradeResult &result)
{
   if(!InpEnableTimeGauge) return OrderSend(request, result);
   int id = GAUGE_ORDERSEND_OTHER;
   switch(request.action)
   {
      case TRADE_ACTION_PENDING: id = GAUGE_ORDERSEND_PENDING; break;
      case TRADE_ACTION_REMOVE:  id = GAUGE_ORDERSEND_DELETE; break;
      case TRADE_ACTION_DEAL:    id = GAUGE_ORDERSEND_CLOSE; break;
      case TRADE_ACTION_SLTP:    id = GAUGE_ORDERSEND_MODIFYSL; break;
   }
   CTimeGaugeScope gauge(id);
   return OrderSend(request, result);
}

void TimeGaugeReport()
{
   if(!InpEnableTimeGauge) return;
   ulong nowMs = GetTickCount64();
   if(g_gaugeReportTimeMs == 0)
   {
      g_gaugeReportTimeMs = nowMs;
      return;
   }
   if(nowMs - g_gaugeReportTimeMs < 10000) return;
   g_gaugeReportTimeMs = nowMs;

   string report = "[TIME GAUGE] 10s interval; elapsed milliseconds";
   bool any = false;
   for(int i = 0; i < GAUGE_COUNT; i++)
   {
      ulong calls = g_gaugeCalls[i];
      if(calls == 0) continue;
      any = true;
      report += StringFormat(
         "\n  %s  Last=%.3f ms  Max10s=%.3f ms  MaxAll=%.3f ms  Avg10s=%.3f ms  Calls=%I64u",
         g_gaugeNames[i],
         (double)g_gaugeLastUs[i] / 1000.0,
         (double)g_gaugeMaxIntervalUs[i] / 1000.0,
         (double)g_gaugeMaxAllUs[i] / 1000.0,
         (double)g_gaugeTotalIntervalUs[i] / (double)calls / 1000.0,
         calls);
   }
   if(any) Print(report);
   for(int i = 0; i < GAUGE_COUNT; i++)
   {
      g_gaugeMaxIntervalUs[i] = 0;
      g_gaugeTotalIntervalUs[i] = 0;
      g_gaugeCalls[i] = 0;
   }
}

#endif

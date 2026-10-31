// Elapsed wall time includes broker/network waits; it is not CPU usage.
// Parent and child timings overlap. Never add them together.
#ifndef HG_TIME_GAUGE_MQH
#define HG_TIME_GAUGE_MQH
#include "../Inputs.mqh"
enum ENUM_TIME_GAUGE_ID
{
   TG_RUNSCHEDULER,
   TG_PROCESSONEQUEUEDTRANSACTION,
   TG_EXECUTEFASTTASKS,
   TG_EXECUTEMEDIUMTASKS,
   TG_EXECUTESLOWTASKS,
   TG_BUILDGRID,
   TG_CHECKANDBUILDGRID,
   TG_REFILLOUTSIDE,
   TG_PROCESSINSIDESTRATEGY,
   TG_PROCESSINSIDEMAINTENANCE,
   TG_UPDATEOPPOSITEGRID,
   TG_PROCESSORDERFILL,
   TG_UPDATESIDEVOLUMEAGGREGATE,
   TG_PROCESSRUNAWAYGUARD,
   TG_PROCESSSLMANAGER,
   TG_SL_FINDCANDIDATE,
   TG_APPLYSLTOWINNERS,
   TG_SNAPSHOTWINNERS,
   TG_ARMSL,
   TG_TRAILWALL,
   TG_EXECUTEEMERGENCYCLOSE,
   TG_EXECUTENEXTCLOSESTEP,
   TG_TRIGGERSAFETYSTOP,
   TG_PLACEPENDINGWITHWIDENING,
   TG_DELETEALLORDERS,
   TG_MODIFYPOSITIONSL,
   TG_GETREQUIREDMARGIN,
   TG_UPDATEDASHBOARD,
   TG_LOGHISTORY,
   TG_SENDTELEGRAMMESSAGE,
   TG_SAVEGRIDSTATE,
   TG_LOADGRIDSTATE,
   TG_SEND_PENDING,
   TG_SEND_DELETE,
   TG_SEND_CLOSE,
   TG_SEND_SL,
   TG_SEND_OTHER,
   TG_HISTORY_SELECT,
   TG_COUNT
};
string g_tgNames[TG_COUNT] = {
   "RunScheduler",
   "ProcessOneQueuedTransaction",
   "ExecuteFastTasks",
   "ExecuteMediumTasks",
   "ExecuteSlowTasks",
   "BuildGrid",
   "CheckAndBuildGrid",
   "RefillOutside",
   "ProcessInsideStrategy",
   "ProcessInsideMaintenance",
   "UpdateOppositeGrid",
   "ProcessOrderFill",
   "UpdateSideVolumeAggregate",
   "ProcessRunawayGuard",
   "ProcessSLManager",
   "SL_FindCandidate",
   "ApplySLToWinners",
   "SnapshotWinners",
   "ArmSL",
   "TrailWall",
   "ExecuteEmergencyClose",
   "ExecuteNextCloseStep",
   "TriggerSafetyStop",
   "PlacePendingWithWidening",
   "DeleteAllOrders",
   "ModifyPositionSL",
   "GetRequiredMargin",
   "UpdateDashboard",
   "LogHistory",
   "SendTelegramMessage",
   "SaveGridState",
   "LoadGridState",
   "OrderSend.Pending",
   "OrderSend.Delete",
   "OrderSend.Close",
   "OrderSend.SL",
   "OrderSend.Other",
   "HistoryDealSelect"
};
ulong g_tgCalls[TG_COUNT], g_tgTotal[TG_COUNT], g_tgMax[TG_COUNT];
ulong g_tgLast[TG_COUNT], g_tgMaxAll[TG_COUNT];
ulong g_tgWindowStart = 0;

// Stack lifetime covers all returns, including failure/early-return paths.
class CTimeGaugeScope
{
private:
   int m_id;
   ulong m_start;
   bool m_enabled;
public:
   CTimeGaugeScope(int id)
   {
      m_enabled = InpEnableTimeGauge;
      m_id = id;
      m_start = m_enabled ? GetMicrosecondCount() : 0;
   }
   ~CTimeGaugeScope()
   {
      if(!m_enabled) return;
      ulong elapsed = GetMicrosecondCount() - m_start;
      g_tgCalls[m_id]++;
      g_tgTotal[m_id] += elapsed;
      g_tgLast[m_id] = elapsed;
      if(elapsed > g_tgMax[m_id]) g_tgMax[m_id] = elapsed;
      if(elapsed > g_tgMaxAll[m_id]) g_tgMaxAll[m_id] = elapsed;
   }
};

bool TimeGaugeOrderSend(MqlTradeRequest &request, MqlTradeResult &result)
{
   if(!InpEnableTimeGauge) return OrderSend(request, result);
   int id = TG_SEND_OTHER;
   switch(request.action)
   {
      case TRADE_ACTION_PENDING: id = TG_SEND_PENDING; break;
      case TRADE_ACTION_REMOVE: id = TG_SEND_DELETE; break;
      case TRADE_ACTION_DEAL: id = TG_SEND_CLOSE; break;
      case TRADE_ACTION_SLTP: id = TG_SEND_SL; break;
   }
   CTimeGaugeScope scope(id);
   return OrderSend(request, result);
}

bool TimeGaugeHistoryDealSelect(ulong ticket)
{
   if(!InpEnableTimeGauge) return HistoryDealSelect(ticket);
   CTimeGaugeScope scope(TG_HISTORY_SELECT);
   return HistoryDealSelect(ticket);
}

// Runs after RunScheduler, so formatting/printing does not inflate its timing.
void TimeGaugeReport(bool force=false)
{
   if(!InpEnableTimeGauge) return;
   ulong now = GetMicrosecondCount();
   if(g_tgWindowStart == 0) { g_tgWindowStart = now; if(!force) return; }
   if(!force && now - g_tgWindowStart < 10000000) return;
   double seconds = (double)(now - g_tgWindowStart) / 1000000.0;
   bool active = false;
   string report = StringFormat("[TIME 14_02_07_02] Window=%.2fs; elapsed ms; nested times overlap", seconds);
   int shown = 0;
   for(int i=0; i<TG_COUNT; i++)
   {
      if(g_tgCalls[i] == 0) continue;
      active = true;
      if((double)g_tgMax[i] / 1000.0 < MathMax(0.0, InpTimeGaugeMinMs)) continue;
      shown++;
      report += StringFormat("\n%s Calls=%I64u Last=%.3f Avg=%.3f Max=%.3f MaxAll=%.3f Total=%.3f",
         g_tgNames[i], g_tgCalls[i], (double)g_tgLast[i]/1000.0,
         (double)g_tgTotal[i]/(double)g_tgCalls[i]/1000.0,
         (double)g_tgMax[i]/1000.0, (double)g_tgMaxAll[i]/1000.0,
         (double)g_tgTotal[i]/1000.0);
   }
   if(active)
   {
      if(shown == 0) report += "\nNo measured function reached the display threshold.";
      Print(report);
   }
   for(int i=0; i<TG_COUNT; i++)
   {
      g_tgCalls[i]=0; g_tgTotal[i]=0; g_tgMax[i]=0;
   }
   g_tgWindowStart = GetMicrosecondCount();
}
#endif

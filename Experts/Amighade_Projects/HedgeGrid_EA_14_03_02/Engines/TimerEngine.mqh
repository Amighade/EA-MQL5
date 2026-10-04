//+------------------------------------------------------------------+
//| TimerEngine.mqh                                                  |
//| REV 21 - scheduler / workload governor                           |
//|                                                                  |
//| Architecture for this revision:                                 |
//|   - ONE native MQL5 heartbeat (15 ms default).                   |
//|   - ONE global work budget for the whole heartbeat.              |
//|   - Software tiers have release intervals, not separate timers. |
//|   - OnTick only overwrites the latest market snapshot.           |
//|   - OnTradeTransaction only queues compact event data.           |
//|   - The scheduler consumes events and creates bounded work.      |
//|   - Cleanup can send several async requests, then WAIT.          |
//|   - The cycle is finished only after the required live state is  |
//|     confirmed by reconciliation.                                 |
//+------------------------------------------------------------------+
#ifndef TIMER_ENGINE_MQH
#define TIMER_ENGINE_MQH
#include "../Utils/TimeGauge.mqh"

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/HistoryLogger.mqh"
#include "../Utils/BarUtils.mqh"
#include "../Utils/SessionFilter.mqh"
#include "../Utils/CloseOrderUtils.mqh"
#include "../Engines/OrderMonitor.mqh"
#include "../Engines/GridBuilder.mqh"
#include "../Engines/GridUpdater.mqh"
#include "../Engines/SLManager.mqh"
#include "../Engines/CleanupReset.mqh"

struct SchedulerTransaction
  {
   ENUM_TRADE_TRANSACTION_TYPE type;
   ulong deal;
   ulong order;
   ulong position;
   uint requestId;
   uint retcode;
   int historyRetries;
   ENUM_DEAL_TYPE dealtype;
  };

SchedulerTransaction g_transactionQueue[];
int  g_transactionHead = 0;
bool g_reconcilePending = true;
bool g_transactionQueueFailed = false;
bool g_emergencyCloseRequested = false;

// Queue broker facts here; strategy and trade work runs from OnTimer().
void QueueTradeTransaction(const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
{
   // only DEAL_ADD is relevant — DEAL_UPDATE/DEAL_DELETE never
   // fire for normal trade activity, and TRADE_TRANSACTION_POSITION does
   // not carry deal history (needed for the #2 fix), so it is dropped too.
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol) return;
   if(trans.deal_type != DEAL_TYPE_BUY && trans.deal_type != DEAL_TYPE_SELL) return;

   int size = ArraySize(g_transactionQueue);
   if(ArrayResize(g_transactionQueue, size + 1, 64) != size + 1)
     {
      g_transactionQueueFailed = true;
      return;
     }

   g_transactionQueue[size].type = trans.type;
   g_transactionQueue[size].deal = trans.deal;
   g_transactionQueue[size].order = (trans.type == TRADE_TRANSACTION_REQUEST && result.order > 0)
                                    ? result.order : trans.order;
   g_transactionQueue[size].position = trans.position;
   g_transactionQueue[size].requestId = result.request_id;
   g_transactionQueue[size].retcode = result.retcode;
   g_transactionQueue[size].historyRetries = 0;
   g_transactionQueue[size].dealtype = trans.deal_type;
}

void RemoveQueuedTransaction()
{
   g_transactionHead++;
   int total = ArraySize(g_transactionQueue);

   if(g_transactionHead >= total)
     {
      ArrayFree(g_transactionQueue);
      g_transactionHead = 0;
      return;
     }

   if(g_transactionHead >= 32 && g_transactionHead >= total / 2)
     {
      int remaining = total - g_transactionHead;
      for(int i = 0; i < remaining; i++)
         g_transactionQueue[i] = g_transactionQueue[g_transactionHead + i];
      ArrayResize(g_transactionQueue, remaining);
      g_transactionHead = 0;
     }
}

bool ProcessOneQueuedTransaction(GridState &state)
{
   CTimeGaugeScope timeGauge(GAUGE_PROCESSONEQUEUEDTRANSACTION);
   if(g_transactionHead >= ArraySize(g_transactionQueue))
      return false;

   SchedulerTransaction tx = g_transactionQueue[g_transactionHead];

/*   if(!HistoryDealSelect(tx.deal))
     {
      g_transactionQueue[g_transactionHead].historyRetries++;
      if(g_transactionQueue[g_transactionHead].historyRetries < 4)
         return false;

      LogDebug(StringFormat("[Scheduler] Deal history unavailable after retries. deal=%I64u",
                            tx.deal));
      g_reconcilePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   long dealMagic = 0;
   if(!HistoryDealGetInteger(tx.deal, DEAL_MAGIC, dealMagic))
      return false; // Keep queued; retry if the deal data is not available yet.
*/
//
   long dealMagic = 0;

   if(!HistoryDealSelect(tx.deal) ||
      !HistoryDealGetInteger(tx.deal, DEAL_MAGIC, dealMagic))
     {
      if(InpEnableFailureDiagnostics)
      {
         int diagnosticsError = GetLastError();
         FailureDiagnosticsLog(StringFormat("HISTORY:%I64u:%d", tx.deal, diagnosticsError),
            StringFormat("[DIAG HISTORY] deal=%I64u stage=HistoryDealSelect-or-DEAL_MAGIC error=%d retry=%d",
                         tx.deal, diagnosticsError, g_transactionQueue[g_transactionHead].historyRetries + 1));
      }
      g_transactionQueue[g_transactionHead].historyRetries++;

      if(g_transactionQueue[g_transactionHead].historyRetries < 4)
         return false;

      LogDebug(StringFormat(
         "[Scheduler] Deal data unavailable after retries. deal=%I64u",
         tx.deal));

      g_transactionQueueFailed = true;
      return false; // Retain the transaction until cleanup finishes.
     }
//
   if(dealMagic != (long)state.magicNumber)
     {
      RemoveQueuedTransaction();
      return true;
     }

   ENUM_DEAL_ENTRY dealEntry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.deal, DEAL_ENTRY);

   if(state.cleanupInProgress)
     {
      g_cleanupAdvancePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
     {
      double closeLot = HistoryDealGetDouble(tx.deal, DEAL_VOLUME);
      /*UpdateSideVolumeAggregate(g_state, tx.dealtype, dealEntry, closeLot, 0.0);
      if(!UpdateSideVolumeAggregate(state, tx.deal))
      {
         if(InpEnableFailureDiagnostics)
         {
            int diagnosticsError = GetLastError();
            FailureDiagnosticsLog(StringFormat("AGGREGATE:%I64u:%d", tx.deal, diagnosticsError),
               StringFormat("[DIAG HISTORY] deal=%I64u stage=UpdateSideVolumeAggregate error=%d retry=%d",
                            tx.deal, diagnosticsError, g_transactionQueue[g_transactionHead].historyRetries + 1));
         }
         g_transactionQueue[g_transactionHead].historyRetries++;
         if(g_transactionQueue[g_transactionHead].historyRetries >= 4)
            g_transactionQueueFailed = true;
            return false;
      }*/
      StartCleanupSequence(state);
      g_cleanupAdvancePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(dealEntry != DEAL_ENTRY_IN || tx.position == 0)
     {
      RemoveQueuedTransaction();
      return true;
     }
      // [REV-2026-09-12-BACKBONE]: keep the O(1) aggregate current for the
   // pre-arm decision. Uses the fill's own deal fields, not the position
   // (matches UpdateSideVolumeAggregate's OUT-side reasoning for symmetry,
   // and ProcessOrderFill above may have already changed what
   // PositionGetDouble would report anyway).
   double openLot   = HistoryDealGetDouble(tx.deal, DEAL_VOLUME);
   double openPrice = HistoryDealGetDouble(tx.deal, DEAL_PRICE);
   UpdateSideVolumeAggregate(state, tx.dealtype, dealEntry, openLot, openPrice);
   /*if(!UpdateSideVolumeAggregate(state, tx.deal))
   {
      if(InpEnableFailureDiagnostics)
      {
         int diagnosticsError = GetLastError();
         FailureDiagnosticsLog(StringFormat("AGGREGATE:%I64u:%d", tx.deal, diagnosticsError),
            StringFormat("[DIAG HISTORY] deal=%I64u stage=UpdateSideVolumeAggregate error=%d retry=%d",
                         tx.deal, diagnosticsError, g_transactionQueue[g_transactionHead].historyRetries + 1));
      }
      g_transactionQueue[g_transactionHead].historyRetries++;
      if(g_transactionQueue[g_transactionHead].historyRetries >= 4)
         g_transactionQueueFailed = true;
         return false;
   }*/
   ProcessOrderFill(tx.position, state);
   ReSnapshotIfArmed(state);
   UpdateOppositeGrid(state);
   ProcessInsideStrategy(state);
   state.outsideRefillPending = true;

   LogHistory("ORDER_FILL",
              state.lastHitPrice,
              state.lastHitDirection == ORDER_TYPE_BUY ? "BUY" : "SELL",
              state.lastHitLot,
              state.passCounter,
              state.currentBlockLot,
              state.basketProfit,
              state.sessionAllowed,
              AccountInfoDouble(ACCOUNT_MARGIN_FREE));

   RemoveQueuedTransaction();
   return true;
}

void ExecuteFastTasks(ulong frameStartMicro, ulong budgetMicro, GridState &state)
{
   CTimeGaugeScope timeGauge(GAUGE_EXECUTEFASTTASKS);
/*   if(state.cleanupInProgress)
     {
      if(g_cleanupAdvancePending)
        {
         g_cleanupAdvancePending = false;
         bool done = ExecuteNextCloseStep(state);
         if(done)
           {
            ResetSLManager(state);
            if(state.refillNeeded)
              {
               ProcessInsideMaintenance(state);
               state.refillNeeded = false;
              }
           }
        }
      return;
     }*/
//
   if(state.cleanupInProgress)
      return;
//
   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(state.cycleActive)
      ProcessSLManager(state);
}

void ExecuteMediumTasks(ulong frameStartMicro, ulong budgetMicro, GridState &state)
{
   CTimeGaugeScope timeGauge(GAUGE_EXECUTEMEDIUMTASKS);
//
   if(state.cleanupInProgress)
     {
      if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
         return;

      if(ExecuteNextCloseStep(state))
        {
         ResetSLManager(state);

         // Broker is confirmed empty; discard events from the abandoned cycle.
         ArrayFree(g_transactionQueue);
         g_transactionHead = 0;
         g_transactionQueueFailed = false;
         g_reconcilePending = false;
        }

      return;
     }
//
   bool prevSession = state.sessionAllowed;
   state.sessionAllowed = IsSessionAllowed();

   if(!prevSession && state.sessionAllowed)
      LogSessionChange(true, GetActiveSessionName());
   if(prevSession && !state.sessionAllowed)
      LogSessionChange(false, "Session ended");

   if(g_reconcilePending)
     {
      if(state.cleanupInProgress && CountPositions(state.magicNumber) == 0)
         g_cleanupAdvancePending = true;

      if(state.gridPlaced && !state.cycleActive &&
         CountPositions(state.magicNumber) == 0 &&
         CountOrders(state.magicNumber) == 0)
         ResetGridBuilder(state);

      if(state.slWallArmed && !state.cycleActive)
         ResetSLManager(state);

      g_reconcilePending = false;
     }

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro ||
      state.cleanupInProgress)
      return;

   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE &&
      IsNewBar(state.lastBarGridFirstSL) &&
      state.gridPlaced && !state.cycleActive)
     {
      DeleteAllOrders(state.magicNumber);
      ResetGridBuilder(state);
     }

   CheckAndBuildGrid(state);

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(state.needsGridVerification)
     {
      state.needsGridVerification = false;
      if(!VerifyFreshGrid(state, state.lotMode))
        {
         LogDebug("[Coordinator] Fresh grid failed verification — resetting.");
         TriggerSafetyStop(state, "GRID_VERIFICATION_FAILED");
        }
     }

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(!state.cleanupInProgress && state.outsideRefillPending)
     {
      RefillOutside(state);
      state.outsideRefillPending = false;
     }

   if(!state.cleanupInProgress && state.refillNeeded)
     {
      ProcessInsideMaintenance(state);
      state.refillNeeded = false;
     }
}

void ExecuteSlowTasks()
{
   CTimeGaugeScope timeGauge(GAUGE_EXECUTESLOWTASKS);
   UpdateDashboard(g_state);
}


//+------------------------------------------------------------------+
//| The single scheduler entry point.                               |
//| Priority order is: transactions → cleanup → fast → medium →    |
//| slow/background. Cleanup priority never means unlimited CPU; all |
//| work shares one frame budget.                                    |
//+------------------------------------------------------------------+
void RunScheduler(GridState &state)
{
   CTimeGaugeScope timeGauge(GAUGE_RUNSCHEDULER);
   ulong frameStartMicro = GetMicrosecondCount();
   uint currentTick = GetTickCount();

   /*if(g_transactionQueueFailed)
     {
      g_transactionQueueFailed = false;
      g_reconcilePending = true;
      LogDebug("[Scheduler] Transaction queue allocation failed; broker reconciliation requested.");
     }*/
//     
   if(g_transactionQueueFailed)
     {
      g_transactionQueueFailed = false;

      if(!state.cleanupInProgress)
        {
         LogDebug("[Scheduler] Transaction data lost/unavailable — starting cleanup.");
         StartCleanupSequence(state);

         // Make the first cleanup step due immediately.
         state.g_lastTime_500ms =
            currentTick - SCHEDULER_MEDIUM_INTERVAL_MS;
        }
     }
//
   if(g_emergencyCloseRequested)
     {
      g_emergencyCloseRequested = false;
      ExecuteEmergencyClose(g_state);
      ResetSLManager(g_state);
     }

   int processed = 0;
/*   while(g_transactionHead < ArraySize(g_transactionQueue) &&
         processed < 8 &&
         GetMicrosecondCount() - frameStartMicro < SCHEDULER_BUDGET_US)
*/         
//
   while(!state.cleanupInProgress &&
         g_transactionHead < ArraySize(g_transactionQueue) &&
         processed < 8 &&
         GetMicrosecondCount() - frameStartMicro < SCHEDULER_BUDGET_US)
//         
     {
      if(!ProcessOneQueuedTransaction(g_state))
         break;
      processed++;
     }
// A failure found while processing the queue is handled next heartbeat.
   if(g_transactionQueueFailed)
      return;
//      
   if((uint)(currentTick - g_state.g_lastTime_50ms) >= SCHEDULER_FAST_INTERVAL_MS)
     {
      g_state.g_lastTime_50ms = currentTick;
      ExecuteFastTasks(frameStartMicro, SCHEDULER_BUDGET_US, g_state);
     }

/*   ulong elapsed = GetMicrosecondCount() - frameStartMicro;
   if(elapsed < SCHEDULER_BUDGET_US &&
      ((uint)(currentTick - g_state.g_lastTime_500ms) >= SCHEDULER_MEDIUM_INTERVAL_MS ||
       g_state.cleanupInProgress))
     {
      if(!g_state.cleanupInProgress)
         g_state.g_lastTime_500ms = currentTick;
      ExecuteMediumTasks(frameStartMicro, SCHEDULER_BUDGET_US, g_state);
     }*/
//
   ulong elapsed = GetMicrosecondCount() - frameStartMicro;

   if(elapsed < SCHEDULER_BUDGET_US &&
      (uint)(currentTick - state.g_lastTime_500ms) >= SCHEDULER_MEDIUM_INTERVAL_MS)
     {
      state.g_lastTime_500ms = currentTick;
      ExecuteMediumTasks(frameStartMicro, SCHEDULER_BUDGET_US, state);
     }
//
   elapsed = GetMicrosecondCount() - frameStartMicro;
   if(elapsed < SCHEDULER_BUDGET_US &&
      (uint)(currentTick - g_state.g_lastTime_2000ms) >=
      (uint)MathMax(1000, InpTimerIntervalSec * 1000))
     {
      g_state.g_lastTime_2000ms = currentTick;
      ExecuteSlowTasks();
     }

   // Reserved for low-frequency maintenance; no such task exists in Rev13.01.
   if((uint)(currentTick - g_state.g_lastTime_60000ms) >= SCHEDULER_BACKGROUND_MS)
      g_state.g_lastTime_60000ms = currentTick;
}

#endif

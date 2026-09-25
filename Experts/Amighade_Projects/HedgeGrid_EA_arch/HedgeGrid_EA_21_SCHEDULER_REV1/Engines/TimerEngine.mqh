//+------------------------------------------------------------------+
//| TimerEngine.mqh                                                  |
//| Rev 21 scheduler: one native heartbeat + software task tiers.    |
//|                                                                   |
//| Design goals for this first implementation:                       |
//|   1) OnTick is cheap and keeps only the latest price snapshot.    |
//|   2) OnTradeTransaction is cheap and LOSSLESS for queued events.  |
//|   3) Heavy strategy work is serviced by a bounded scheduler frame.|
//|   4) Cleanup is high priority but NON-BLOCKING.                    |
//|   5) A cleanup request is never treated as completion.            |
//|                                                                   |
//| The intervals below are starting values only. They are deliberately|
//| easy to retune after real VPS measurements.                       |
//+------------------------------------------------------------------+
#ifndef TIMER_ENGINE_MQH
#define TIMER_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/CloseOrderUtils.mqh"
#include "../Utils/SafetyNet.mqh"
#include "../Utils/HistoryLogger.mqh"
#include "../Utils/SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
ulong SchedulerBudgetMicro()
{
   int ms = InpSchedulerFrameBudgetMs;
   if(ms < 1) ms = 1;
   return (ulong)ms * (ulong)1000;
}

bool SchedulerBudgetAvailable(ulong frameStartMicro, ulong budgetMicro)
{
   return (GetMicrosecondCount() - frameStartMicro) < budgetMicro;
}

bool SchedulerIntervalDue(ulong nowMs, ulong lastMs, int intervalMs)
{
   if(intervalMs <= 0) return true;
   return (nowMs - lastMs) >= (ulong)intervalMs;
}

//+------------------------------------------------------------------+
//| Cleanup transaction bridge.                                      |
//| Trade events only release/mark cleanup work; they do not perform  |
//| the next close directly inside OnTradeTransaction.                |
//+------------------------------------------------------------------+
void HandleCleanupTransaction(const MqlTradeTransactionShort &tx, GridState &state)
{
   if(!state.cleanupInProgress) return;

   // A request result can definitively tell us that an async submission was
   // rejected. Remove only that waiting request so the scheduler may retry.
   if(tx.type == TRADE_TRANSACTION_REQUEST && tx.request_id != 0)
     {
      bool accepted = (tx.retcode == TRADE_RETCODE_DONE ||
                       tx.retcode == TRADE_RETCODE_DONE_PARTIAL ||
                       tx.retcode == TRADE_RETCODE_PLACED ||
                       tx.retcode == TRADE_RETCODE_NO_CHANGES);

      if(!accepted)
        {
         for(int i = ArraySize(state.cleanupPending) - 1; i >= 0; i--)
           {
            if(state.cleanupPending[i].requestId == tx.request_id)
              {
               LogDebug(StringFormat("[Cleanup] Async request failed request_id=%I64u rc=%d ticket=%I64u",
                                     tx.request_id, tx.retcode,
                                     state.cleanupPending[i].ticket));
               CleanupRemovePendingAt(state, i);
               break;
              }
           }
        }
     }

   // A deal-add related to a position close releases that ticket's in-flight
   // slot. The actual position state is still checked by reconciliation.
   if(tx.type == TRADE_TRANSACTION_DEAL_ADD && tx.deal != 0)
     {
      if(!HistoryDealSelect(tx.deal)) return;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.deal, DEAL_ENTRY);

      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
        {
         for(int i = ArraySize(state.cleanupPending) - 1; i >= 0; i--)
           {
            if(state.cleanupPending[i].kind == CLEANUP_REQ_POSITION &&
               state.cleanupPending[i].ticket == tx.position)
              {
               CleanupRemovePendingAt(state, i);
               break;
              }
           }
        }
     }
}

//+------------------------------------------------------------------+
//| Process one queued trade event using the ORIGINAL strategy flow.  |
//| The important change is only WHERE it runs: now from the scheduler,|
//| not inside OnTradeTransaction itself.                             |
//+------------------------------------------------------------------+
void ProcessQueuedTradeEvent(const MqlTradeTransactionShort &tx, GridState &state)
{
   HandleCleanupTransaction(tx, state);

   // The current strategy logic only acts on DEAL_ADD for this symbol.
   if(tx.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(tx.symbol != _Symbol) return;
   if(tx.deal == 0) return;
   if(tx.deal_type != DEAL_TYPE_BUY && tx.deal_type != DEAL_TYPE_SELL) return;

   if(!HistoryDealSelect(tx.deal)) return;
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.deal, DEAL_ENTRY);

   // Cleanup remains authoritative. A transaction arriving during cleanup
   // never opens/modifies anything and never starts a second cleanup sequence.
   if(state.cleanupInProgress)
      return;

   ulong positionTicket = tx.position;
   if(positionTicket == 0) return;

   // Any externally-created close is still a cleanup trigger, preserving the
   // existing strategy rule. The actual close work is now scheduled below.
   if(dealEntry == DEAL_ENTRY_OUT ||
      dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
     {
      StartCleanupSequence(state);
      return;
     }

   if(dealEntry != DEAL_ENTRY_IN) return;

   // ------------------------ NORMAL FILL ---------------------------
   double currentPrice  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double expectedPrice = 0.0;

   // Gap-fault block remains disabled exactly as in Rev 20.
   /*ulong faultTicket = CheckGapFault(currentPrice, state.magicNumber, expectedPrice);
   if(faultTicket != 0)
     {
      state.gapFaultDetected = true;
      LogGapFault(expectedPrice, currentPrice, faultTicket);
      TriggerSafetyStop(state, StringFormat("GAP_FAULT ticket=%I64u expected=%.5f current=%.5f",
                                             faultTicket, expectedPrice, currentPrice));
      return;
     }*/

   ProcessOrderFill(positionTicket, state);
   ReSnapshotIfArmed(state);
   UpdateOppositeGrid(state);
   ShiftGrid(state);
   ProcessInsideStrategy(state);

   // Preserve Rev 20 behavior: outside refill is marked pending here and
   // executed by the normal fast market task, not directly in the event hook.
   state.outsideRefillPending = true;

   // SL check remains in the same logical position in the normal fill flow.
   ProcessSLManager(state);

   LogHistory("ORDER_FILL",
              state.lastHitPrice,
              state.lastHitDirection==ORDER_TYPE_BUY ? "BUY" : "SELL",
              state.lastHitLot,
              state.passCounter,
              state.currentBlockLot,
              state.basketProfit,
              state.sessionAllowed,
              AccountInfoDouble(ACCOUNT_MARGIN_FREE));
}

//+------------------------------------------------------------------+
//| Lossless transaction queue worker.                                |
//| The queue stores facts; this worker consumes them under the        |
//| scheduler's global frame budget.                                  |
//+------------------------------------------------------------------+
void ProcessTransactionQueue(ulong frameStartMicro, ulong budgetMicro, GridState &state)
{
   int processedThisFrame = 0;
   int total = ArraySize(state.g_txQueue);

   while(state.g_txReadIndex < total &&
         processedThisFrame < InpSchedulerMaxTransactionsPerFrame)
     {
      if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
         return;

      MqlTradeTransactionShort tx = state.g_txQueue[state.g_txReadIndex];
      state.g_txReadIndex++;
      processedThisFrame++;

      ProcessQueuedTradeEvent(tx, state);

      // Strategy work may start cleanup or change cycle state, but we keep
      // consuming the queue only within the same bounded scheduler frame.
   }

   if(state.g_txReadIndex >= total)
     {
      ArrayFree(state.g_txQueue);
      state.g_txReadIndex = 0;
      state.g_txDirty = false;
     }
}

//+------------------------------------------------------------------+
//| Fast market tier. Runs at a controlled interval, not per tick.    |
//| The call order intentionally follows the previous OnTick flow.    |
//+------------------------------------------------------------------+
void ExecuteFastTasks(GridState &state, ulong frameStartMicro, ulong budgetMicro)
{
   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   // Cleanup always outranks opening/modifying. Nothing below this point is
   // allowed to run while cleanup remains active.
   if(state.cleanupInProgress) return;

   state.sessionAllowed = state.sessionAllowed; // explicit: session work is medium tier

   // Preserve the old calculation order: basket values are refreshed before
   // the SL manager uses them.
   CalculateBasketProfits(state);
   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   CheckAndBuildGrid(state);
   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   if(state.needsGridVerification)
     {
      state.needsGridVerification = false;
      if(!VerifyFreshGrid(state))
        {
         LogDebug("[Coordinator] Fresh grid failed verification — resetting.");
         TriggerSafetyStop(state, "GRID_VERIFICATION_FAILED");
         return;
        }
     }

   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   if(ProcessRecentering(state))
      BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), state);

   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   if(state.cycleActive)
      ProcessSLManager(state);

   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   if(state.outsideRefillPending)
     {
      RefillOutside(state);
      state.outsideRefillPending = false;
     }
}

//+------------------------------------------------------------------+
//| Medium tier: low-frequency reconciliation / session housekeeping. |
//| No strategy state is invented here; only known broker-state       |
//| inconsistencies are reconciled.                                   |
//+------------------------------------------------------------------+
void ExecuteMediumTasks(GridState &state, ulong frameStartMicro, ulong budgetMicro)
{
   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   bool prevSession = state.sessionAllowed;
   state.sessionAllowed = IsSessionAllowed();

   if(prevSession != state.sessionAllowed)
     {
      if(state.sessionAllowed)
         LogSessionChange(true, GetActiveSessionName());
      else
         LogSessionChange(false, "Session ended");
     }

   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   // Cleanup safety backstop: if the state says cleanup is active but there
   // are no positions, the cleanup worker gets another chance to resolve the
   // remaining order phase. We do NOT clear cleanup here.
   if(state.cleanupInProgress)
      return;

   // Phantom grid: state says a grid exists, broker has neither positions nor
   // pending orders. This is a reconciliation reset, not a new strategy rule.
   if(state.gridPlaced &&
      CountPositions(state.magicNumber) == 0 &&
      CountOrders(state.magicNumber) == 0)
     {
      ResetGridBuilder(state);
     }

   if(!SchedulerBudgetAvailable(frameStartMicro, budgetMicro)) return;

   // Orphaned SL wall: armed state without an active cycle is stale.
   if(state.slWallArmed && !state.cycleActive)
      ResetSLManager(state);
}

//+------------------------------------------------------------------+
//| Slow tier: dashboard only.                                      |
//+------------------------------------------------------------------+
void ExecuteSlowTasks(GridState &state)
{
   if(InpShowDashboard)
      UpdateDashboard(state);
}

//+------------------------------------------------------------------+
//| Background tier placeholder. Kept separate so future file/history |
//| maintenance can be scheduled without entering the fast path.      |
//+------------------------------------------------------------------+
void ExecuteBackgroundTasks(GridState &state)
{
   // Intentionally empty in Rev 21. No new strategy behavior is added here.
}

//+------------------------------------------------------------------+
//| Main scheduler. One native heartbeat services all software tiers.  |
//+------------------------------------------------------------------+
void RunScheduler(GridState &state)
{
   ulong frameStartMicro = GetMicrosecondCount();
   ulong budgetMicro     = SchedulerBudgetMicro();
   ulong nowMs            = GetTickCount64();

   // Priority 1: consume queued trade events. The callback itself stays tiny.
   if(state.g_txDirty && SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
      ProcessTransactionQueue(frameStartMicro, budgetMicro, state);

   // Priority 2: cleanup gets the next available budget. Waiting for broker
   // confirmation never blocks the rest of the scheduler.
   if(state.cleanupInProgress && SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
      ExecuteCleanupTasks(state, frameStartMicro, budgetMicro);

   // Priority 3: fast market work at a controlled release interval.
   if(SchedulerIntervalDue(nowMs, state.g_lastTimeFast, InpSchedulerFastIntervalMs) &&
      SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
     {
      state.g_lastTimeFast = nowMs;
      ExecuteFastTasks(state, frameStartMicro, budgetMicro);
     }

   // Priority 4: medium reconciliation / session state.
   if(SchedulerIntervalDue(nowMs, state.g_lastTimeMedium, InpSchedulerMediumIntervalMs) &&
      SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
     {
      state.g_lastTimeMedium = nowMs;
      ExecuteMediumTasks(state, frameStartMicro, budgetMicro);
     }

   // Priority 5: dashboard / low-frequency visual work.
   if(SchedulerIntervalDue(nowMs, state.g_lastTimeSlow, InpSchedulerSlowIntervalMs) &&
      SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
     {
      state.g_lastTimeSlow = nowMs;
      ExecuteSlowTasks(state);
     }

   // Priority 6: background maintenance.
   if(SchedulerIntervalDue(nowMs, state.g_lastTimeBackground, InpSchedulerBackgroundIntervalMs) &&
      SchedulerBudgetAvailable(frameStartMicro, budgetMicro))
     {
      state.g_lastTimeBackground = nowMs;
      ExecuteBackgroundTasks(state);
     }
}

#endif

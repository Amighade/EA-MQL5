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
#include "../Engines/RunawayGuard.mqh"

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
   if(g_transactionHead >= ArraySize(g_transactionQueue))
      return false;

   SchedulerTransaction tx = g_transactionQueue[g_transactionHead];

   long dealMagic = 0;
   long entryValue = 0;
   long positionId = 0;

   if(!HistoryDealSelect(tx.deal) ||
      !HistoryDealGetInteger(tx.deal, DEAL_MAGIC, dealMagic) ||
      !HistoryDealGetInteger(tx.deal, DEAL_ENTRY, entryValue) ||
      !HistoryDealGetInteger(tx.deal, DEAL_POSITION_ID, positionId) ||
      positionId <= 0)
     {
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
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)entryValue;

   bool owned = (dealMagic == (long)state.magicNumber);

   if(!owned &&
      (dealEntry == DEAL_ENTRY_OUT ||
       dealEntry == DEAL_ENTRY_OUT_BY ||
       dealEntry == DEAL_ENTRY_INOUT))
     {
      for(int i = 0; i < ArraySize(state.ownedPositionIds); i++)
        {
         if(state.ownedPositionIds[i] == (ulong)positionId)
           {
            owned = true;
            break;
           }
        }
     }

   if(!owned)
     {
      RemoveQueuedTransaction();
      return true;
     }

   if(state.cleanupInProgress)
     {
      g_cleanupAdvancePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
     {
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

   bool recorded = false;

   for(int i = 0; i < ArraySize(state.ownedPositionIds); i++)
     {
      if(state.ownedPositionIds[i] == (ulong)positionId)
        {
         recorded = true;
         break;
        }
     }

   if(!recorded)
     {
      int size = ArraySize(state.ownedPositionIds);

      if(ArrayResize(state.ownedPositionIds, size + 1, 16) != size + 1)
        {
         g_transactionQueueFailed = true;
         return false;
        }

      state.ownedPositionIds[size] = (ulong)positionId;
     }
      // [REV-2026-09-12-BACKBONE]: keep the O(1) aggregate current for the
   // pre-arm decision. Uses the fill's own deal fields, not the position
   // (matches UpdateSideVolumeAggregate's OUT-side reasoning for symmetry,
   // and ProcessOrderFill above may have already changed what
   // PositionGetDouble would report anyway).
   // Store the live position once, updating it on additional opening fills.
   if(PositionSelectByTicket(tx.position))
     {
      int index = -1;
   
      for(int i = 0; i < ArraySize(state.positionItems); i++)
        {
         if(state.positionItems[i].identifier == (ulong)positionId)
           {
            index = i;
            break;
           }
        }
   
      bool isNew = (index < 0);
   
      if(isNew)
        {
         int size = ArraySize(state.positionItems);
   
         if(ArrayResize(state.positionItems, size + 1, 16) != size + 1)
           {
            g_transactionQueueFailed = true;
            return false;
           }
   
         index = size;
        }
   
      state.positionItems[index].identifier = (ulong)positionId;
      state.positionItems[index].ticket     = tx.position;
      state.positionItems[index].side       = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      state.positionItems[index].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      state.positionItems[index].volume     = PositionGetDouble(POSITION_VOLUME);
   
      // New position: include only this record.
      // Existing position: rebuild summaries from the updated array.
      int first = index;
   
      if(!isNew)
        {
         state.sellpositionCount       = 0;
         state.buypositionCount        = 0;
         state.positionCount           = 0;
         state.lowestSellPositionPrice = DBL_MAX;
         state.lowestSellPositionLot   = 0.0;
         state.highestBuyPositionPrice = 0.0;
         state.highestBuyPositionLot   = 0.0;
   
         first = 0;
        }
   
      int total = ArraySize(state.positionItems);
   
      for(int i = first; i < total; i++)
        {
         ENUM_POSITION_TYPE type = state.positionItems[i].side;
         double p   = state.positionItems[i].entryPrice;
         double lot = state.positionItems[i].volume;
   
         state.positionCount++;
   
         if(type == POSITION_TYPE_SELL)
           {
            state.sellpositionCount++;
   
            if(p < state.lowestSellPositionPrice)
              {
               state.lowestSellPositionPrice = p;
               state.lowestSellPositionLot   = lot;
              }
           }
         else if(type == POSITION_TYPE_BUY)
           {
            state.buypositionCount++;
   
            if(p > state.highestBuyPositionPrice)
              {
               state.highestBuyPositionPrice = p;
               state.highestBuyPositionLot   = lot;
              }
           }
        }
     }
 
 
 
   double openLot   = HistoryDealGetDouble(tx.deal, DEAL_VOLUME);
   double openPrice = HistoryDealGetDouble(tx.deal, DEAL_PRICE);
   UpdateSideVolumeAggregate(g_state, tx.dealtype, dealEntry, openLot, openPrice);

   ProcessOrderFill(tx.position, tx.dealtype, openLot, openPrice, state);
   
//   ENUM_ORDER_TYPE fillDirection = (tx.dealtype == DEAL_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
//   UpdateRunawayStreak(state, fillDirection);
   ProcessRunawayGuard(state);
/*
   if(InpRunawayN > 0 &&
      (InpRunawayAction == RUNAWAY_ACTION_CLOSE_ALL ||
       InpRunawaySLMode != RA_SL_NONE))
     {
      if(!ProcessRunawayGuard(state))
        {
         RemoveQueuedTransaction();
         return true;
        }
     }
     */
//   ProcessOrderFill(tx.position, state);
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

   if(state.cycleActive || state.slWallArmed)
      ProcessSLManager(state);
}

void ExecuteMediumTasks(ulong frameStartMicro, ulong budgetMicro, GridState &state)
{
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
//
   CheckAndBuildGrid(state);
   
   if(state.cleanupInProgress ||
      GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;
/*
   CheckAndBuildGrid(state);

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(state.needsGridVerification)
     {
      state.needsGridVerification = false;
      if(!VerifyFreshGrid(state))
        {
         LogDebug("[Coordinator] Fresh grid failed verification — resetting.");
         TriggerSafetyStop(state, "GRID_VERIFICATION_FAILED");
        }
     }

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;
*/
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
   ulong frameStartMicro = GetMicrosecondCount();
   uint currentTick = GetTickCount();

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

   if(g_emergencyCloseRequested)
     {
      g_emergencyCloseRequested = false;
      ExecuteEmergencyClose(g_state);
      ResetSLManager(g_state);
     }

   int processed = 0;

   while(!state.cleanupInProgress &&
         g_transactionHead < ArraySize(g_transactionQueue) &&
         processed < 8 &&
         GetMicrosecondCount() - frameStartMicro < SCHEDULER_BUDGET_US)       
     {
      if(!ProcessOneQueuedTransaction(g_state))
         break;
      processed++;
     }
// A failure found while processing the queue is handled next heartbeat.
   if(g_transactionQueueFailed)
      return;
      
   if((uint)(currentTick - g_state.g_lastTime_50ms) >= SCHEDULER_FAST_INTERVAL_MS)
     {
      g_state.g_lastTime_50ms = currentTick;
      ExecuteFastTasks(frameStartMicro, SCHEDULER_BUDGET_US, g_state);
     }

   ulong elapsed = GetMicrosecondCount() - frameStartMicro;

   if(elapsed < SCHEDULER_BUDGET_US &&
      (uint)(currentTick - state.g_lastTime_500ms) >= SCHEDULER_MEDIUM_INTERVAL_MS)
     {
      state.g_lastTime_500ms = currentTick;
      ExecuteMediumTasks(frameStartMicro, SCHEDULER_BUDGET_US, state);
     }

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

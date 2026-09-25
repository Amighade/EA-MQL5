//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                 |
//| BRICK 7 cleanup state machine.                                   |
//|                                                                   |
//| Rev 21 scheduler design:                                         |
//|   - Cleanup requests are NON-BLOCKING.                           |
//|   - A small number of close/delete requests may be outstanding.  |
//|   - The scheduler continues other eligible work while the broker |
//|     processes those requests.                                    |
//|   - A request being sent is NEVER treated as a completed action. |
//|   - A cycle is finished only after the required account objects   |
//|     are actually gone.                                           |
//+------------------------------------------------------------------+
#ifndef CLEANUP_RESET_MQH
#define CLEANUP_RESET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/CloseOrderUtils.mqh"
#include "../Utils/SafetyNet.mqh"

#define CLEANUP_REQ_POSITION 0
#define CLEANUP_REQ_ORDER    1

//+------------------------------------------------------------------+
//| Full state reset, preserving the magic number.                   |
//| Scheduler and queued transaction state are deliberately retained  |
//| by ResetGridState so a cycle reset cannot erase events that are    |
//| still waiting for scheduled processing.                           |
//+------------------------------------------------------------------+
void ResetCycle(GridState &state)
{
   int magic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = magic;
}

//+------------------------------------------------------------------+
//| Universal emergency close — manual button or broker fault.       |
//| The legacy emergency path remains unchanged in this first         |
//| scheduler revision; normal cleanup uses the async worker below.  |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose(GridState &state)
{
   TriggerSafetyStop(state, "EMERGENCY_CLOSE");
}

bool CleanupHasPending(const GridState &state, ulong ticket, int kind)
{
   for(int i = 0; i < ArraySize(state.cleanupPending); i++)
      if(state.cleanupPending[i].ticket == ticket && state.cleanupPending[i].kind == kind)
         return true;
   return false;
}

int CleanupPendingCount(const GridState &state, int kind)
{
   int count = 0;
   for(int i = 0; i < ArraySize(state.cleanupPending); i++)
      if(state.cleanupPending[i].kind == kind)
         count++;
   return count;
}

void CleanupAddPending(GridState &state, ulong ticket, ulong requestId, int kind)
{
   int n = ArraySize(state.cleanupPending);
   if(ArrayResize(state.cleanupPending, n + 1) <= n)
      return;

   state.cleanupPending[n].ticket   = ticket;
   state.cleanupPending[n].requestId = requestId;
   state.cleanupPending[n].kind     = kind;
   state.cleanupPending[n].sentAtMs = GetTickCount64();
}

void CleanupRemovePendingAt(GridState &state, int index)
{
   int n = ArraySize(state.cleanupPending);
   if(index < 0 || index >= n) return;

   for(int i = index + 1; i < n; i++)
      state.cleanupPending[i - 1] = state.cleanupPending[i];
   ArrayResize(state.cleanupPending, n - 1);
}

// Remove requests only when the requested object is actually gone.
// This is intentionally account-state based; one transaction callback is not
// treated as proof that the complete close/delete operation is finished.
void CleanupReconcilePending(GridState &state)
{
   for(int i = ArraySize(state.cleanupPending) - 1; i >= 0; i--)
     {
      ulong ticket = state.cleanupPending[i].ticket;
      int   kind   = state.cleanupPending[i].kind;
      bool  gone   = false;

      if(kind == CLEANUP_REQ_POSITION)
         gone = !PositionSelectByTicket(ticket);
      else
         gone = !OrderSelect(ticket);

      if(gone)
         CleanupRemovePendingAt(state, i);
     }
}

//+------------------------------------------------------------------+
//| Begin confirmation-based cleanup after an exit/SL close.         |
//+------------------------------------------------------------------+
void StartCleanupSequence(GridState &state)
{
   if(state.cleanupInProgress)
      return; // Already cleaning; never restart/duplicate the sequence.

   LogCleanupStarted(EnumToString(InpCleanupMode));

   ArrayResize(state.closeSequence, 0);
   state.closeIndex = 0;
   ArrayResize(state.cleanupPending, 0);

   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);

   state.cleanupType       = InpCleanupMode;
   state.cleanupInProgress = true;
   state.cleanupStep       = 0;
   state.cleanupLastRetryMs = 0;
   state.cleanupLastRebuildMs = 0;
}

//+------------------------------------------------------------------+
//| Advance cleanup without blocking.                                |
//| The scheduler calls this repeatedly. A small async batch may be   |
//| outstanding while other scheduler tasks continue.                 |
//+------------------------------------------------------------------+
void ExecuteCleanupTasks(GridState &state, ulong frameStartMicro, ulong budgetMicro)
{
   if(!state.cleanupInProgress)
      return;

   // This first reconciliation is cheap and lets completed async requests
   // release their slots without requiring the scheduler to know event order.
   CleanupReconcilePending(state);

   ulong nowMs = GetTickCount64();

   // A rejected submission must not turn into a 15ms request storm. The
   // cleanup state remains active, but retries are spaced out modestly.
   if(state.cleanupLastRetryMs != 0 &&
      (nowMs - state.cleanupLastRetryMs) < 250)
      return;

   int pendingPositions = CleanupPendingCount(state, CLEANUP_REQ_POSITION);
   int pendingOrders    = CleanupPendingCount(state, CLEANUP_REQ_ORDER);

   // ---------------------------------------------------------------
   // Phase 1: close remaining positions.
   // ---------------------------------------------------------------
   int positionCount = CountPositions(state.magicNumber);

   if(positionCount > 0)
     {
      // When the current sequence is exhausted AND nothing is in-flight,
      // rebuild from the live account. This avoids stale array indexes after
      // positions disappear between scheduler frames.
      if(state.closeIndex >= ArraySize(state.closeSequence) && pendingPositions == 0)
        {
         if(nowMs - state.cleanupLastRebuildMs >= 50)
           {
            BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
            state.closeIndex = 0;
            state.cleanupLastRebuildMs = nowMs;
           }
        }

      int batchLeft = InpCleanupAsyncBatchSize - pendingPositions;
      if(batchLeft < 0) batchLeft = 0;

      while(batchLeft > 0 && state.closeIndex < ArraySize(state.closeSequence))
        {
         if((GetMicrosecondCount() - frameStartMicro) >= budgetMicro)
            return;

         ulong ticket = state.closeSequence[state.closeIndex++];
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         if(CleanupHasPending(state, ticket, CLEANUP_REQ_POSITION))
            continue;

         ulong requestId = 0;
         TradeActionResult out = ClosePositionAsync(ticket, requestId);

         if(out.sent && out.success)
           {
            CleanupAddPending(state, ticket, requestId, CLEANUP_REQ_POSITION);
            state.cleanupStep++;
            batchLeft--;
           }
         else
           {
            // Failed submission does not mean cleanup is complete. Leave the
            // position in the account and retry later, with a small cooldown
            // to avoid hammering the broker during a fault.
            state.cleanupLastRetryMs = nowMs;
            LogDebug(StringFormat("[Cleanup] Async close submit failed ticket=%I64u rc=%d err=%d",
                                  ticket, out.retcode, out.lastError));
            break;
           }
        }

      return; // Positions always finish before pending-order deletion in CLOSE_ALL.
     }

   // ---------------------------------------------------------------
   // Phase 2: in CLEANUP_CLOSE_ALL, delete remaining pending orders.
   // ---------------------------------------------------------------
   if(state.cleanupType == CLEANUP_CLOSE_ALL)
     {
      int orderCount = CountOrders(state.magicNumber);

      if(orderCount > 0)
        {
         // Rebuild the live order sequence only when the prior batch has no
         // outstanding requests. This keeps continuation state stable.
         if(state.closeIndex >= ArraySize(state.closeSequence) && pendingOrders == 0)
           {
            if(nowMs - state.cleanupLastRebuildMs >= 50)
              {
               BuildProximityOrderOrder(state.magicNumber, state.closeSequence);
               state.closeIndex = 0;
               state.cleanupLastRebuildMs = nowMs;
              }
           }

         int batchLeft = InpCleanupAsyncBatchSize - pendingOrders;
         if(batchLeft < 0) batchLeft = 0;

         while(batchLeft > 0 && state.closeIndex < ArraySize(state.closeSequence))
           {
            if((GetMicrosecondCount() - frameStartMicro) >= budgetMicro)
               return;

            ulong ticket = state.closeSequence[state.closeIndex++];
            if(ticket == 0 || !OrderSelect(ticket))
               continue;

            if(CleanupHasPending(state, ticket, CLEANUP_REQ_ORDER))
               continue;

            ulong requestId = 0;
            TradeActionResult out = DeleteOrderAsync(ticket, requestId);

            if(out.sent && out.success)
              {
               CleanupAddPending(state, ticket, requestId, CLEANUP_REQ_ORDER);
               state.cleanupStep++;
               batchLeft--;
              }
            else
              {
               state.cleanupLastRetryMs = nowMs;
               LogDebug(StringFormat("[Cleanup] Async delete submit failed ticket=%I64u rc=%d err=%d",
                                     ticket, out.retcode, out.lastError));
               break;
              }
           }

         return;
        }
     }

   // ---------------------------------------------------------------
   // Phase 3: only now may the cleanup state transition to complete.
   // ---------------------------------------------------------------
   // Hard rule for CLEANUP_CLOSE_ALL: no EA position AND no EA order.
   // We deliberately check the live account again before changing state.
   if(CountPositions(state.magicNumber) == 0 &&
      (state.cleanupType != CLEANUP_CLOSE_ALL || CountOrders(state.magicNumber) == 0))
     {
      state.cleanupInProgress = false;
      state.cleanupStep       = 0;
      ArrayResize(state.cleanupPending, 0);
      ArrayResize(state.closeSequence, 0);
      state.closeIndex = 0;

      if(state.cleanupType == CLEANUP_CLOSE_ALL)
        {
         ResetCycle(state);
         state.gridPlaced = false; // next candle-open check may build a fresh grid
        }
      else
        {
         // Preserve the existing CLOSE_POSITIONS semantics: pending orders
         // are intentionally left alone, so the grid remains placed.
         state.cycleActive = false;
         if(InpInsideMaintenanceStyle != MAINTENANCE_NONE)
           {
            state.refillNeeded = true;
            ProcessInsideMaintenance(state);
            state.refillNeeded = false;
           }
        }

      LogCleanupComplete();
     }
}

// Legacy entry kept only as a compatibility reference. Rev 21's active
// coordinator uses ExecuteCleanupTasks() from the scheduler instead.
bool ExecuteNextCloseStep(GridState &state)
{
   // Do one bounded scheduler cleanup pass; do not claim completion merely
   // because a close request was submitted.
   ulong start = GetMicrosecondCount();
   ExecuteCleanupTasks(state, start, 15000);
   return !state.cleanupInProgress;
}

#endif

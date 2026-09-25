//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                 |
//| BRICK 7 + REV 21 scheduler cleanup engine                        |
//|                                                                  |
//| The strategy meaning of cleanup is unchanged: after a qualifying |
//| close/safety event, positions are closed first; in               |
//| CLEANUP_CLOSE_ALL, pending orders are deleted after positions.   |
//|                                                                  |
//| REV 21 execution change:                                        |
//|   - close/delete requests use OrderSendAsync();                 |
//|   - a small number may be in flight simultaneously;              |
//|   - no Sleep() is used in the scheduler cleanup path;             |
//|   - request submission is NOT treated as completion;              |
//|   - OnTradeTransaction supplies request/result facts;             |
//|   - live Positions/Orders state is the final completion authority.|
//+------------------------------------------------------------------+
#ifndef CLEANUP_RESET_MQH
#define CLEANUP_RESET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/ProfilerUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/CloseOrderUtils.mqh"
#include "../Utils/SafetyNet.mqh"

#define CLEANUP_ACTION_CLOSE_POSITION 1
#define CLEANUP_ACTION_DELETE_ORDER   2

//+------------------------------------------------------------------+
//| Full strategy-cycle reset. Scheduler queues live outside state,  |
//| therefore resetting the strategy cannot erase pending events.    |
//+------------------------------------------------------------------+
void ResetCycle(GridState &state)
{
   int magic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = magic;
}

//+------------------------------------------------------------------+
//| Universal emergency close remains a synchronous exceptional path. |
//| Normal SL cleanup uses the non-blocking scheduler below.           |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose(GridState &state)
{
   TriggerSafetyStop(state, "EMERGENCY_CLOSE");
}

//+------------------------------------------------------------------+
//| Return true if this position ticket was intentionally targeted by |
//| the current/last cleanup. This prevents a cleanup-generated DEAL_ |
//| ENTRY_OUT from being mistaken for a new external cleanup trigger. |
//+------------------------------------------------------------------+
bool CleanupWasOurPosition_old(GridState &state, ulong ticket)
{
   if(ticket == 0) return false;
   for(int i = 0; i < ArraySize(state.cleanupHandledPositions); i++)
      if(state.cleanupHandledPositions[i] == ticket)
         return true;
   return false;
}

bool CleanupWasOurPosition(GridState &state, ulong ticket)
{
   if(ticket == 0)
      return false;

   for(int i = 0; i < ArraySize(state.cleanupHandledPositions); i++)
      if(state.cleanupHandledPositions[i] == ticket)
         return true;

   for(int i = 0; i < ArraySize(state.cleanupPreviousHandledPositions); i++)
      if(state.cleanupPreviousHandledPositions[i] == ticket)
         return true;

   return false;
}

void RememberCleanupPosition(GridState &state, ulong ticket)
{
   if(ticket == 0 || CleanupWasOurPosition(state, ticket)) return;
   int n = ArraySize(state.cleanupHandledPositions);
   if(ArrayResize(state.cleanupHandledPositions, n + 1) == n + 1)
      state.cleanupHandledPositions[n] = ticket;
}

//+------------------------------------------------------------------+
//| Find whether a cleanup request for the same target/action already |
//| exists. This is the duplicate-request safety barrier.             |
//+------------------------------------------------------------------+
int CleanupFindAnyRequest(GridState &state, ulong targetTicket, int action)
{
   for(int i = 0; i < ArraySize(state.cleanupRequests); i++)
     {
      if(state.cleanupRequests[i].targetTicket == targetTicket &&
         state.cleanupRequests[i].action == action)
         return i;
     }
   return -1;
}

// A request is considered active while it is waiting for its REQUEST result,
// while an accepted request is still inside its confirmation grace period, or
// while a failed request is inside its retry delay. Once the delay expires,
// the same record can be reused for a new submission.
int CleanupFindActiveRequest(GridState &state, ulong targetTicket, int action)
{
   ulong now = GetTickCount64();
   for(int i = 0; i < ArraySize(state.cleanupRequests); i++)
     {
      if(state.cleanupRequests[i].targetTicket != targetTicket ||
         state.cleanupRequests[i].action != action)
         continue;

      if(state.cleanupRequests[i].requestId != 0 ||
         state.cleanupRequests[i].requestAccepted ||
         now < state.cleanupRequests[i].retryAfterMs)
         return i;
     }
   return -1;
}

int CleanupInFlightCount(GridState &state)
{
   int count = 0;
   for(int i = 0; i < ArraySize(state.cleanupRequests); i++)
      if(state.cleanupRequests[i].requestId != 0 || state.cleanupRequests[i].requestAccepted)
         count++;
   return count;
}

bool CleanupHasAnyRequests(GridState &state)
{
   return ArraySize(state.cleanupRequests) > 0;
}

void CleanupRemoveRequest(GridState &state, int index)
{
   int n = ArraySize(state.cleanupRequests);
   if(index < 0 || index >= n) return;

   for(int i = index; i < n - 1; i++)
      state.cleanupRequests[i] = state.cleanupRequests[i + 1];

   ArrayResize(state.cleanupRequests, n - 1);
}

//+------------------------------------------------------------------+
//| Start a new confirmation-based cleanup sequence.                  |
//+------------------------------------------------------------------+
void StartCleanupSequence_old(GridState &state)
{
   if(state.cleanupInProgress)
      return;

   state.cleanupInProgress = true;
   state.cleanupStep       = 0;
   state.closeIndex        = 0;
   state.orderIndex        = 0;

   ArrayResize(state.closeSequence, 0);
   ArrayResize(state.orderSequence, 0);
   ArrayResize(state.cleanupRequests, 0);
   // Keep cleanupHandledPositions across cycle resets. Position tickets are
   // unique, so retaining these closed tickets lets the classifier ignore late
   // cleanup-generated DEAL_ENTRY_OUT events even after the next cycle starts.

   // The sequence is only a preferred ordering. Before every actual request
   // the ticket is revalidated against the live account state.
   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
   for(int i = 0; i < ArraySize(state.closeSequence); i++)
      RememberCleanupPosition(state, state.closeSequence[i]);

   // The scheduler invalidates any pending fill reaction immediately after it
   // observes cleanup activation. Transaction facts remain in its lossless queue.
   state.refillNeeded = false;
}

//+------------------------------------------------------------------+
//| Start a new confirmation-based cleanup sequence.                 |
//+------------------------------------------------------------------+
void StartCleanupSequence(GridState &state)
{
   if(state.cleanupInProgress)
      return;

   state.cleanupInProgress = true;
   state.cleanupStep       = 0;
   state.closeIndex        = 0;
   state.orderIndex        = 0;

   ArrayResize(state.closeSequence, 0);
   ArrayResize(state.orderSequence, 0);
   ArrayResize(state.cleanupRequests, 0);

   // REV22:
   // Keep only one previous cleanup generation for recognizing
   // late cleanup-generated transaction events.
   ArrayResize(state.cleanupPreviousHandledPositions, 0);

   int handledCount = ArraySize(state.cleanupHandledPositions);

   if(handledCount > 0)
     {
      ArrayResize(state.cleanupPreviousHandledPositions, handledCount);

      ArrayCopy(state.cleanupPreviousHandledPositions,
                state.cleanupHandledPositions);
     }

   // Current cleanup starts with a fresh handled-position list.
   ArrayResize(state.cleanupHandledPositions, 0);

   // The sequence is only a preferred ordering. Before every actual request
   // the ticket is revalidated against the live account state.
   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);

   for(int i = 0; i < ArraySize(state.closeSequence); i++)
      RememberCleanupPosition(state, state.closeSequence[i]);

   // The scheduler invalidates any pending fill reaction immediately after it
   // observes cleanup activation. Transaction facts remain in its lossless queue.
   state.refillNeeded = false;
}

//+------------------------------------------------------------------+
//| Request-result handling for async cleanup.                        |
//| The REQUEST event is only a report about the request. It does not |
//| itself prove that the target has disappeared from the account.     |
//+------------------------------------------------------------------+
void CleanupHandleRequestResult(GridState &state, uint requestId, int retcode)
{
   if(requestId == 0) return;

   for(int i = 0; i < ArraySize(state.cleanupRequests); i++)
     {
      if(state.cleanupRequests[i].requestId != requestId)
         continue;

      state.cleanupRequests[i].lastRetcode = retcode;
      state.cleanupRequests[i].requestId = 0;

      if(retcode == TRADE_RETCODE_DONE ||
         retcode == TRADE_RETCODE_DONE_PARTIAL ||
         retcode == TRADE_RETCODE_PLACED ||
         retcode == TRADE_RETCODE_NO_CHANGES)
        {
         // Accepted/processed request: keep the work item alive until live
         // position/order state confirms the target is really gone.
         state.cleanupRequests[i].requestAccepted = true;
         state.cleanupRequests[i].retryAfterMs = GetTickCount64() +
                                                (ulong)InpAsyncConfirmGraceMs;
        }
      else
        {
         // Request was not accepted. Keep the target as retryable work, but
         // never spin inside this callback.
         state.cleanupRequests[i].requestAccepted = false;
         state.cleanupRequests[i].retryAfterMs = GetTickCount64() +
                                                (ulong)InpSafetyRetryDelayMs;
        }
      return;
     }
}

//+------------------------------------------------------------------+
//| Reconcile in-flight cleanup targets against actual live state.    |
//| This is deliberately authoritative: request events are hints,      |
//| account state determines completion.                              |
//+------------------------------------------------------------------+
void CleanupReconcileRequests(GridState &state)
{
   ulong now = GetTickCount64();

   for(int i = ArraySize(state.cleanupRequests) - 1; i >= 0; i--)
     {
      bool exists = false;

      if(state.cleanupRequests[i].action == CLEANUP_ACTION_CLOSE_POSITION)
         exists = PositionSelectByTicket(state.cleanupRequests[i].targetTicket);
      else if(state.cleanupRequests[i].action == CLEANUP_ACTION_DELETE_ORDER)
         exists = OrderSelect(state.cleanupRequests[i].targetTicket);

      if(!exists)
        {
         // Target no longer exists in the live terminal state: request is done.
         CleanupRemoveRequest(state, i);
         continue;
        }

      // Request-result failure or an accepted request followed by a partial/no-op
      // leaves the target live. It becomes retryable after the grace period.
      if(state.cleanupRequests[i].requestId == 0 &&
         now >= state.cleanupRequests[i].retryAfterMs)
         state.cleanupRequests[i].requestAccepted = false;
     }
}

//+------------------------------------------------------------------+
//| Add a cleanup request record.                                     |
//+------------------------------------------------------------------+
int CleanupAddRequest(GridState &state, ulong ticket, int action,
                      uint requestId, int attempts, ulong sentAtMs)
{
   int n = ArraySize(state.cleanupRequests);
   if(ArrayResize(state.cleanupRequests, n + 1) != n + 1)
      return -1;

   state.cleanupRequests[n].targetTicket    = ticket;
   state.cleanupRequests[n].requestId       = requestId;
   state.cleanupRequests[n].action          = action;
   state.cleanupRequests[n].attempts        = attempts;
   state.cleanupRequests[n].sentAtMs        = sentAtMs;
   state.cleanupRequests[n].retryAfterMs    = sentAtMs + (ulong)InpAsyncConfirmGraceMs;
   state.cleanupRequests[n].lastRetcode     = 0;
   state.cleanupRequests[n].requestAccepted = (requestId != 0);
   return n;
}

//+------------------------------------------------------------------+
//| Find a previously submitted target that is now retryable.         |
//| This check comes before new targets so a failed/partial request   |
//| cannot become permanently stranded behind the sequence cursor.    |
//+------------------------------------------------------------------+
bool CleanupFindRetryableTarget(GridState &state, int action, ulong &ticket)
{
   ticket = 0;
   ulong now = GetTickCount64();

   for(int i = 0; i < ArraySize(state.cleanupRequests); i++)
     {
      if(state.cleanupRequests[i].action != action) continue;
      if(state.cleanupRequests[i].requestId != 0 ||
         state.cleanupRequests[i].requestAccepted) continue;
      if(now < state.cleanupRequests[i].retryAfterMs) continue;

      if(action == CLEANUP_ACTION_CLOSE_POSITION)
        {
         if(PositionSelectByTicket(state.cleanupRequests[i].targetTicket))
           {
            ticket = state.cleanupRequests[i].targetTicket;
            return true;
           }
        }
      else if(action == CLEANUP_ACTION_DELETE_ORDER)
        {
         if(OrderSelect(state.cleanupRequests[i].targetTicket))
           {
            ticket = state.cleanupRequests[i].targetTicket;
            return true;
           }
        }
     }

   return false;
}

//+------------------------------------------------------------------+
//| Find next position target not yet requested.                      |
//+------------------------------------------------------------------+
bool CleanupFindNextPosition(GridState &state, ulong &ticket)
{
   if(CleanupFindRetryableTarget(state, CLEANUP_ACTION_CLOSE_POSITION, ticket))
      return true;
   ticket = 0;

   // The sequence is rebuilt only after all requests from the current sequence
   // are resolved. This preserves the original close ordering without creating
   // duplicates while requests are in flight.
   while(state.closeIndex < ArraySize(state.closeSequence))
     {
      ulong t = state.closeSequence[state.closeIndex++];
      if(!PositionSelectByTicket(t))
         continue;
      if(CleanupFindActiveRequest(state, t, CLEANUP_ACTION_CLOSE_POSITION) >= 0)
         continue;
      ticket = t;
      return true;
     }

   if(CleanupHasAnyRequests(state))
      return false;

   // Sequence drained and nothing is in flight: rebuild to catch positions that
   // appeared after the original snapshot or partial closes that remain.
   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
   state.closeIndex = 0;

   while(state.closeIndex < ArraySize(state.closeSequence))
     {
      ulong t = state.closeSequence[state.closeIndex++];
      if(!PositionSelectByTicket(t)) continue;
      if(CleanupFindActiveRequest(state, t, CLEANUP_ACTION_CLOSE_POSITION) >= 0) continue;
      RememberCleanupPosition(state, t);
      ticket = t;
      return true;
     }

   return false;
}

//+------------------------------------------------------------------+
//| Find next pending order target not yet requested.                 |
//+------------------------------------------------------------------+
bool CleanupFindNextOrder(GridState &state, ulong &ticket)
{
   if(CleanupFindRetryableTarget(state, CLEANUP_ACTION_DELETE_ORDER, ticket))
      return true;

   ticket = 0;

   while(state.orderIndex < ArraySize(state.orderSequence))
     {
      ulong t = state.orderSequence[state.orderIndex++];
      if(!OrderSelect(t)) continue;
      if(CleanupFindActiveRequest(state, t, CLEANUP_ACTION_DELETE_ORDER) >= 0) continue;
      ticket = t;
      return true;
     }

   if(CleanupHasAnyRequests(state))
      return false;

   BuildProximityOrderOrder(state.magicNumber, state.orderSequence);
   state.orderIndex = 0;

   while(state.orderIndex < ArraySize(state.orderSequence))
     {
      ulong t = state.orderSequence[state.orderIndex++];
      if(!OrderSelect(t)) continue;
      if(CleanupFindActiveRequest(state, t, CLEANUP_ACTION_DELETE_ORDER) >= 0) continue;
      ticket = t;
      return true;
     }

   return false;
}

//+------------------------------------------------------------------+
//| Send one asynchronous close.                                     |
//+------------------------------------------------------------------+
bool CleanupSubmitClose(GridState &state, ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return true;

   if(CleanupFindActiveRequest(state, ticket, CLEANUP_ACTION_CLOSE_POSITION) >= 0)
      return true;

   uint requestId = 0;
   bool sent = SendClosePositionAsync(ticket, requestId);
   if(!sent)
      return false;

   int existing = CleanupFindAnyRequest(state, ticket, CLEANUP_ACTION_CLOSE_POSITION);
   ulong now = GetTickCount64();
   if(existing >= 0)
     {
      // Reuse the old task record after its retry delay rather than appending
      // an unbounded second record for the same target.
      state.cleanupRequests[existing].requestId       = requestId;
      state.cleanupRequests[existing].attempts++;
      state.cleanupRequests[existing].sentAtMs        = now;
      state.cleanupRequests[existing].retryAfterMs    = now + (ulong)InpAsyncConfirmGraceMs;
      state.cleanupRequests[existing].lastRetcode     = 0;
      state.cleanupRequests[existing].requestAccepted = (requestId != 0);
     }
   else if(CleanupAddRequest(state, ticket, CLEANUP_ACTION_CLOSE_POSITION,
                             requestId, 1, now) < 0)
      return false;

   state.cleanupStep++;
   RememberCleanupPosition(state, ticket);
   return true;
}

//+------------------------------------------------------------------+
//| Send one asynchronous pending-order deletion.                    |
//+------------------------------------------------------------------+
bool CleanupSubmitDelete(GridState &state, ulong ticket)
{
   if(ticket == 0 || !OrderSelect(ticket))
      return true;

   if(CleanupFindActiveRequest(state, ticket, CLEANUP_ACTION_DELETE_ORDER) >= 0)
      return true;

   uint requestId = 0;
   bool sent = SendDeleteOrderAsync(ticket, requestId);
   if(!sent)
      return false;

   int existing = CleanupFindAnyRequest(state, ticket, CLEANUP_ACTION_DELETE_ORDER);
   ulong now = GetTickCount64();
   if(existing >= 0)
     {
      state.cleanupRequests[existing].requestId       = requestId;
      state.cleanupRequests[existing].attempts++;
      state.cleanupRequests[existing].sentAtMs        = now;
      state.cleanupRequests[existing].retryAfterMs    = now + (ulong)InpAsyncConfirmGraceMs;
      state.cleanupRequests[existing].lastRetcode     = 0;
      state.cleanupRequests[existing].requestAccepted = (requestId != 0);
     }
   else if(CleanupAddRequest(state, ticket, CLEANUP_ACTION_DELETE_ORDER,
                             requestId, 1, now) < 0)
      return false;

   state.cleanupStep++;
   return true;
}

//+------------------------------------------------------------------+
//| Completion barrier.                                             |
//| Cleanup completes only when positions == 0, orders == 0, cleanup |
//| requests are resolved, and no normal async placement can still   |
//| create a late pending order after the cycle is declared clean.    |
//+------------------------------------------------------------------+
bool CleanupTryFinish(GridState &state, int positions, int orders)
{
   if(positions > 0)
      return false;

   if(orders > 0 || CleanupHasAnyRequests(state))
      return false;

   // REV 22.5: an accepted async placement can materialize after the current
   // OrdersTotal() scan. Do not finish cleanup until those requests resolve.
   if(HasAsyncPendingPlacements())
      return false;

   // Only now is the cycle physically clean. Reset strategy state AFTER the
   // account is empty, never immediately after sending the last request.
   state.cleanupInProgress = false;
   state.cleanupStep = 0;
   ResetCycle(state);
   state.gridPlaced = false;

   LogCleanupComplete();
   return true;
}

//+------------------------------------------------------------------+
//| Process a bounded cleanup slice.                                 |
//| Priority is high, but CPU remains bounded by the caller's global |
//| frame budget. Waiting for broker responses never blocks.          |
//+------------------------------------------------------------------+
void ProcessCleanupWork(ulong frameStartUs, ulong budgetUs, GridState &state)
{
   if(!state.cleanupInProgress)
      return;

   // A disconnect stops new broker requests, but does not erase cleanup state.
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return;

   // REV 22.3: reconcile once per cleanup release. Do not repeatedly rescan
   // the full account inside the same scheduler frame while async requests are
   // still awaiting broker/terminal confirmation.
   ulong profReconcileStart = GetMicrosecondCount();
   CleanupReconcileRequests(state);
   ProfilerRecord(PROF_CLEANUP_RECONCILE, profReconcileStart);

   int positions = CountPositions(state.magicNumber);
   int orders    = (positions == 0) ? CountOrders(state.magicNumber) : -1;

   // Account-state completion remains authoritative.
   if(CleanupTryFinish(state, positions, orders))
      return;

   // Never submit more than the configured small async window.
   int batchLimit = MathMax(1, InpCleanupAsyncBatch);

   while(SchedulerBudgetAvailable(frameStartUs, budgetUs))
     {
      int inflight = CleanupInFlightCount(state);
      if(inflight >= batchLimit)
         return; // wait for request/transaction/state feedback

      if(positions == 0)
        {
         // Positions are gone; now delete pending orders.
         ulong orderTicket = 0;
         if(!CleanupFindNextOrder(state, orderTicket))
            return; // either waiting for requests or no orders

         ulong profSubmitStart = GetMicrosecondCount();
         CleanupSubmitDelete(state, orderTicket);
         ProfilerRecord(PROF_CLEANUP_SUBMIT_DELETE, profSubmitStart);
         continue;
        }

      // Default cleanup phase: positions first.
      ulong positionTicket = 0;
      if(!CleanupFindNextPosition(state, positionTicket))
         return; // existing requests may still be in flight

      ulong profSubmitStart = GetMicrosecondCount();
      CleanupSubmitClose(state, positionTicket);
      ProfilerRecord(PROF_CLEANUP_SUBMIT_CLOSE, profSubmitStart);
     }
}

#endif

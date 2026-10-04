#ifndef CLEANUP_ENGINE_MQH
#define CLEANUP_ENGINE_MQH

#include "../Models/GridState.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/ProfilerUtils.mqh"

// Reconciliation owns broker facts. Cleanup owns only CLOSE / DELETE intent.
// Calling this again is safe and routes objects found since the previous pass.
void StartCleanup(GridState &state, string reason)
  {
   ulong profStart = GetMicrosecondCount();
   state.lifecycle = GRID_CLEANUP;
   if(state.cleanupReason == "") state.cleanupReason = reason;
   ulong now = GetTickCount64();

   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      TradeItem item = state.items[i];
      item.replaceAfterDelete = false;
      state.items[i] = item;
      if(item.actionStatus == ACTION_WAIT_RESULT ||
         item.actionStatus == ACTION_WAIT_CONFIRM) continue;

      // Discard unsent plans. Stale broker objects are removed by reconciliation.
      if(item.kind == ITEM_ORDER && item.orderTicket == 0 &&
         item.action == ACTION_PLACE)
        {
         RemoveTradeItem(state, i);
         continue;
        }
      if(!item.brokerPresent || item.reconcilePending) continue;
      if(item.actionStatus == ACTION_FAILED &&
         now - item.sentTimeMs < (ulong)MathMax(1, InpSafetyRetryDelayMs)) continue;

      ENUM_ITEM_ACTION needed = (item.kind == ITEM_POSITION) ? ACTION_CLOSE : ACTION_DELETE;
      if(item.action == needed && item.actionStatus == ACTION_READY) continue;
      item.action = needed;
      item.actionStatus = ACTION_READY;
      item.requestId = 0;
      state.items[i] = item;
     }
   Profiler30Record(PROF30_START_CLEANUP, profStart);
  }

bool CleanupFinished(GridState &state)
  {
   if(state.lifecycle != GRID_CLEANUP || !TerminalInfoInteger(TERMINAL_CONNECTED)) return false;
   if(ArraySize(state.items) > 0) return false; // Includes unresolved async PLACE requests.
   return (CountLiveTerminalPositions(state.magicNumber) == 0 &&
           CountLiveTerminalOrders(state.magicNumber) == 0);
  }

void ProcessCleanupState(GridState &state)
  {
   if(!CleanupFinished(state)) return;
   ulong nextCycle = state.cycleId + 1;
   ResetGridState(state);
   state.cycleId = nextCycle;
  }

#endif

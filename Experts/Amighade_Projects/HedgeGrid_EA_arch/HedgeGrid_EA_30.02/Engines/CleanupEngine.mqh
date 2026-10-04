#ifndef CLEANUP_ENGINE_MQH
#define CLEANUP_ENGINE_MQH

#include "../Models/GridState.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/ProfilerUtils.mqh"

//+------------------------------------------------------------------+
//| Cleanup is expressed only by changing TradeItem.action.          |
//| No closeSequence[], orderSequence[] or cleanupRequests[] exist.  |
//+------------------------------------------------------------------+
void StartCleanup(GridState &state, string reason)
  {
   ulong profStart = GetMicrosecondCount();
   if(state.lifecycle == GRID_CLEANUP)
     {
      Profiler30Record(PROF30_START_CLEANUP, profStart);
      return;
     }

   state.lifecycle     = GRID_CLEANUP;
   state.cleanupReason = reason;

   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      TradeItem item = state.items[i];

      if(item.actionStatus == ACTION_FAILED && !item.brokerPresent)
        {
         RemoveTradeItem(state, i);
         continue;
        }

      if(item.kind == ITEM_POSITION)
        {
         item.action       = ACTION_CLOSE;
         item.actionStatus = ACTION_READY;
         item.requestId    = 0;
         state.items[i]    = item;
         continue;
        }

      if(item.kind == ITEM_ORDER)
        {
         // Unsent planned order can simply disappear from the local book.
         if(item.action == ACTION_PLACE && item.actionStatus == ACTION_READY && item.orderTicket == 0)
           {
            RemoveTradeItem(state, i);
            continue;
           }

         // A PLACE request already left the terminal. Keep the member until
         // broker outcome is known, then delete the resulting order.
         if(item.action == ACTION_PLACE &&
            (item.actionStatus == ACTION_WAIT_RESULT ||
             item.actionStatus == ACTION_WAIT_CONFIRM))
           {
            item.cleanupAfterConfirm = true;
            state.items[i] = item;
            continue;
           }

         if(item.orderTicket > 0)
           {
            item.replaceAfterDelete = false;
            item.action             = ACTION_DELETE;
            item.actionStatus       = ACTION_READY;
            item.requestId          = 0;
            state.items[i]          = item;
           }
        }
     }

   Profiler30Record(PROF30_START_CLEANUP, profStart);
  }

bool CleanupFinished(GridState &state)
  {
   if(state.lifecycle != GRID_CLEANUP)
      return false;

   if(ArraySize(state.items) > 0)
      return false;

   // Hard invariant: live broker account must also confirm zero / zero.
   if(CountLiveTerminalPositions(state.magicNumber) > 0)
      return false;
   if(CountLiveTerminalOrders(state.magicNumber) > 0)
      return false;

   return true;
  }

void ProcessCleanupState(GridState &state)
  {
   ulong profStart = GetMicrosecondCount();
   if(!CleanupFinished(state))
     {
      Profiler30Record(PROF30_PROCESS_CLEANUP_STATE, profStart);
      return;
     }

   int savedMagic = state.magicNumber;
   ulong nextCycle = state.cycleId + 1;
   ResetGridState(state);
   state.magicNumber = savedMagic;
   state.cycleId = nextCycle;
   Profiler30Record(PROF30_PROCESS_CLEANUP_STATE, profStart);
  }

#endif

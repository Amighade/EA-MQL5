#ifndef CLEANUP_ENGINE_MQH
#define CLEANUP_ENGINE_MQH

#include "../Models/GridState.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/ProfilerUtils.mqh"

//+------------------------------------------------------------------+
//| Whole-cycle cleanup.                                             |
//| This function is intentionally idempotent: it may be called      |
//| again while GRID_CLEANUP is active so newly-reconciled objects   |
//| are routed into CLOSE / DELETE using the same normal path.       |
//+------------------------------------------------------------------+
void StartCleanup(GridState &state, string reason)
  {
   ulong profStart = GetMicrosecondCount();

   if(state.lifecycle != GRID_CLEANUP)
     {
      state.lifecycle     = GRID_CLEANUP;
      state.cleanupReason = reason;
     }
   else if(state.cleanupReason == "" && reason != "")
     {
      state.cleanupReason = reason;
     }

   // Cleanup owns the whole cycle. If a live EA object exists at the broker
   // but a transaction was missed, adopt it into the same TradeItem book
   // before assigning cleanup actions.
   for(int p = 0; p < PositionsTotal(); p++)
     {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;
      if(FindItemByPositionTicket(state, ticket) >= 0) continue;

      int idx = AddTradeItem(state);
      state.items[idx].kind           = ITEM_POSITION;
      state.items[idx].positionTicket = ticket;
      state.items[idx].side           = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      state.items[idx].openPrice      = PositionGetDouble(POSITION_PRICE_OPEN);
      state.items[idx].volume         = PositionGetDouble(POSITION_VOLUME);
      state.items[idx].targetLot      = state.items[idx].volume;
      state.items[idx].originalLot    = state.items[idx].volume;
      state.items[idx].currentSL      = PositionGetDouble(POSITION_SL);
      state.items[idx].currentTP      = PositionGetDouble(POSITION_TP);
      state.items[idx].brokerPresent  = true;
     }

   for(int o = 0; o < OrdersTotal(); o++)
     {
      ulong ticket = OrderGetTicket(o);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
      if(FindItemByOrderTicket(state, ticket) >= 0) continue;

      int idx = AddTradeItem(state);
      state.items[idx].kind        = ITEM_ORDER;
      state.items[idx].orderTicket = ticket;
      state.items[idx].orderType   = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      state.items[idx].side        = (state.items[idx].orderType == ORDER_TYPE_BUY_STOP ||
                                      state.items[idx].orderType == ORDER_TYPE_BUY_LIMIT)
                                     ? POSITION_TYPE_BUY
                                     : POSITION_TYPE_SELL;
      state.items[idx].targetPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      state.items[idx].targetLot   = OrderGetDouble(ORDER_VOLUME_CURRENT);
      state.items[idx].originalLot = state.items[idx].targetLot;
      state.items[idx].openPrice   = state.items[idx].targetPrice;
      state.items[idx].volume      = state.items[idx].targetLot;
      state.items[idx].currentSL   = OrderGetDouble(ORDER_SL);
      state.items[idx].currentTP   = OrderGetDouble(ORDER_TP);
      state.items[idx].brokerPresent = true;
     }

   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      TradeItem item = state.items[i];

      // Reconciliation owns uncertain presence. Do not send a broker
      // command until that one item has been resolved.
      if(item.reconcilePending)
         continue;

      if(item.actionStatus == ACTION_FAILED)
        {
         if(!item.brokerPresent)
            RemoveTradeItem(state, i);

         // Do not create an implicit retry loop here. Retry policy is separate.
         continue;
        }

      // ------------------------------------------------------------
      // Live position -> CLOSE
      // ------------------------------------------------------------
      if(item.kind == ITEM_POSITION)
        {
         // Never resend or overwrite an action that is already in flight.
         if(item.actionStatus == ACTION_WAIT_RESULT ||
            item.actionStatus == ACTION_WAIT_CONFIRM)
            continue;

         if(item.action == ACTION_CLOSE &&
            item.actionStatus == ACTION_READY)
            continue;

         item.action       = ACTION_CLOSE;
         item.actionStatus = ACTION_READY;
         item.requestId    = 0;
         state.items[i]    = item;
         continue;
        }

      // ------------------------------------------------------------
      // Pending / planned order -> DELETE or discard unsent PLACE
      // ------------------------------------------------------------
      if(item.kind == ITEM_ORDER)
        {
         // PLACE has not left the terminal yet: remove local plan only.
         if(item.action == ACTION_PLACE &&
            item.actionStatus == ACTION_READY &&
            item.orderTicket == 0)
           {
            RemoveTradeItem(state, i);
            continue;
           }

         // PLACE already left the terminal. Wait for broker reality first.
         // A later cleanup pass will route the confirmed ORDER/POSITION.
         if(item.action == ACTION_PLACE &&
            (item.actionStatus == ACTION_WAIT_RESULT ||
             item.actionStatus == ACTION_WAIT_CONFIRM))
            continue;

         // Never resend or overwrite an action that is already in flight.
         if(item.actionStatus == ACTION_WAIT_RESULT ||
            item.actionStatus == ACTION_WAIT_CONFIRM)
            continue;

         if(item.action == ACTION_DELETE &&
            item.actionStatus == ACTION_READY)
            continue;

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

   // Hard invariant: broker account must also confirm zero / zero.
   if(CountLiveTerminalPositions(state.magicNumber) > 0)
      return false;

   if(CountLiveTerminalOrders(state.magicNumber) > 0)
      return false;

   return true;
  }

void ProcessCleanupState(GridState &state)
  {
   ulong profStart = GetMicrosecondCount();

   if(state.lifecycle != GRID_CLEANUP)
     {
      Profiler30Record(PROF30_PROCESS_CLEANUP_STATE, profStart);
      return;
     }

   // Route any order/position that appeared or was reconciled after cleanup
   // first started. Cleanup remains one whole-cycle operation.
   StartCleanup(state, state.cleanupReason);

   if(!CleanupFinished(state))
     {
      Profiler30Record(PROF30_PROCESS_CLEANUP_STATE, profStart);
      return;
     }

   int savedMagic = state.magicNumber;
   ulong nextCycle = state.cycleId + 1;

   ResetGridState(state);
   state.magicNumber = savedMagic;
   state.cycleId     = nextCycle;

   Profiler30Record(PROF30_PROCESS_CLEANUP_STATE, profStart);
  }

#endif

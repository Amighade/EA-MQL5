#ifndef RECONCILE_ENGINE_MQH
#define RECONCILE_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/ProfilerUtils.mqh"

int FindMatchingLiveOrder(GridState &state, TradeItem &item)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != item.orderType) continue;
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - item.requestedPrice) > tick * 0.5) continue;
      return i;
     }
   return -1;
  }

bool AnyPlacementStillPending(GridState &state)
  {
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].action != ACTION_PLACE) continue;
      if(state.items[i].actionStatus == ACTION_READY ||
         state.items[i].actionStatus == ACTION_WAIT_RESULT ||
         state.items[i].actionStatus == ACTION_WAIT_CONFIRM)
         return true;
     }
   return false;
  }

void ConfirmReplacementOrRemove(GridState &state, int index)
  {
   if(index < 0 || index >= ArraySize(state.items)) return;

   TradeItem item = state.items[index];
   if(item.replaceAfterDelete && state.lifecycle != GRID_CLEANUP)
     {
      item.orderTicket        = 0;
      item.brokerPresent      = false;
      item.targetPrice        = item.replacementPrice;
      item.targetLot          = item.replacementLot;
      item.requestedPrice     = item.replacementPrice;
      item.requestedLot       = item.replacementLot;
      item.requestedSL        = item.replacementSL;
      item.requestedTP        = item.replacementTP;
      item.replaceAfterDelete = false;
      item.action             = ACTION_PLACE;
      item.actionStatus       = ACTION_READY;
      item.requestId          = 0;
      item.sentTimeMs         = 0;
      item.resultTimeMs       = 0;
      state.items[index]      = item;
      return;
     }

   RemoveTradeItem(state, index);
  }

//+------------------------------------------------------------------+
//| Live broker state is the final confirmation layer.               |
//+------------------------------------------------------------------+
void ReconcileTradeItems(GridState &state)
  {
   ulong profStart = GetMicrosecondCount();
   ulong now = GetTickCount64();
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;

   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      TradeItem item = state.items[i];

      if(item.actionStatus == ACTION_WAIT_RESULT)
        {
         if(item.sentTimeMs > 0 &&
            now - item.sentTimeMs >= (ulong)MathMax(0, InpAsyncResultTimeoutMs))
           {
            item.actionStatus = ACTION_FAILED;
            item.lastRetcode  = TRADE_RETCODE_TIMEOUT;
            state.items[i]    = item;
           }
         continue;
        }

      if(item.actionStatus == ACTION_WAIT_CONFIRM)
        {
         ulong confirmStart = (item.resultTimeMs > 0) ? item.resultTimeMs : item.sentTimeMs;

         if(item.action == ACTION_PLACE)
           {
            bool found = false;

            if(item.orderTicket > 0 && OrderSelect(item.orderTicket))
               found = true;
            else
              {
               ulong profFindStart = GetMicrosecondCount();
               int liveIndex = FindMatchingLiveOrder(state, item);
               Profiler30Record(PROF30_FIND_MATCHING_LIVE_ORDER, profFindStart);
               if(liveIndex >= 0)
                 {
                  ulong ticket = OrderGetTicket(liveIndex);
                  if(ticket > 0 && OrderSelect(ticket))
                    {
                     item.orderTicket = ticket;
                     found = true;
                    }
                 }
              }

            if(found)
              {
               item.brokerPresent = true;
               item.openPrice     = OrderGetDouble(ORDER_PRICE_OPEN);
               item.volume        = OrderGetDouble(ORDER_VOLUME_CURRENT);
               item.currentSL     = OrderGetDouble(ORDER_SL);
               item.currentTP     = OrderGetDouble(ORDER_TP);
               item.action        = ACTION_NONE;
               item.actionStatus  = ACTION_IDLE;
               item.requestId     = 0;

               if(state.lifecycle == GRID_CLEANUP && item.cleanupAfterConfirm)
                 {
                  item.cleanupAfterConfirm = false;
                  item.action              = ACTION_DELETE;
                  item.actionStatus        = ACTION_READY;
                 }
               state.items[i] = item;
               continue;
              }
           }
         else if(item.action == ACTION_DELETE)
           {
            if(item.orderTicket == 0 || !OrderSelect(item.orderTicket))
              {
               ConfirmReplacementOrRemove(state, i);
               continue;
              }
           }
         else if(item.action == ACTION_CLOSE)
           {
            if(item.positionTicket == 0 || !PositionSelectByTicket(item.positionTicket))
              {
               RemoveTradeItem(state, i);
               continue;
              }
           }
         else if(item.action == ACTION_MODIFY_SL)
           {
            if(item.positionTicket == 0 || !PositionSelectByTicket(item.positionTicket))
              {
               RemoveTradeItem(state, i);
               continue;
              }

            double liveSL = PositionGetDouble(POSITION_SL);
            if(MathAbs(liveSL - item.requestedSL) <= tick * 0.5)
              {
               item.currentSL    = liveSL;
               item.action       = ACTION_NONE;
               item.actionStatus = ACTION_IDLE;
               item.requestId    = 0;
               state.items[i]    = item;
               continue;
              }
           }

         if(confirmStart > 0 &&
            now - confirmStart >= (ulong)MathMax(0, InpAsyncLiveConfirmTimeoutMs))
           {
            item.actionStatus = ACTION_FAILED;
            item.lastRetcode  = TRADE_RETCODE_TIMEOUT;
            state.items[i]    = item;
           }
         continue;
        }

      // Keep live fields fresh for stable confirmed items.
      if(item.actionStatus == ACTION_IDLE && item.kind == ITEM_ORDER && item.orderTicket > 0)
        {
         if(OrderSelect(item.orderTicket))
           {
            item.brokerPresent = true;
            item.openPrice     = OrderGetDouble(ORDER_PRICE_OPEN);
            item.volume        = OrderGetDouble(ORDER_VOLUME_CURRENT);
            item.currentSL     = OrderGetDouble(ORDER_SL);
            item.currentTP     = OrderGetDouble(ORDER_TP);
           }
         else
            item.brokerPresent = false;
         state.items[i] = item;
        }
      else if(item.actionStatus == ACTION_IDLE && item.kind == ITEM_POSITION && item.positionTicket > 0)
        {
         if(PositionSelectByTicket(item.positionTicket))
           {
            item.brokerPresent = true;
            item.openPrice     = PositionGetDouble(POSITION_PRICE_OPEN);
            item.volume        = PositionGetDouble(POSITION_VOLUME);
            item.currentSL     = PositionGetDouble(POSITION_SL);
            item.currentTP     = PositionGetDouble(POSITION_TP);
           }
         else
            item.brokerPresent = false;
         state.items[i] = item;
        }
     }

   if(state.lifecycle == GRID_BUILDING && !AnyPlacementStillPending(state))
     {
      if(CountBookOrders(state) > 0)
         state.lifecycle = GRID_READY;
      else if(ArraySize(state.items) == 0)
         state.lifecycle = GRID_IDLE;
     }

   Profiler30Record(PROF30_RECONCILE_TRADE_ITEMS, profStart);
  }

#endif

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

//+------------------------------------------------------------------+
//| Live broker state is the final confirmation layer.               |
//| Reconciliation updates reality; it does not invent strategy work.|
//+------------------------------------------------------------------+
void ReconcileTradeItems(GridState &state)
  {
   ulong profStart = GetMicrosecondCount();
   ulong now = GetTickCount64();

   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = _Point;

   int maxReconcileMisses = (InpSafetyRetryAttempts > 0) ? InpSafetyRetryAttempts : 1;

   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      TradeItem item = state.items[i];

      //=============================================================
      // HANDLER RETRIES EXHAUSTED / OBJECT DISAPPEARANCE UNCERTAIN
      //=============================================================
      if(item.reconcilePending)
        {
         // 1) Position exists: synchronize this same TradeItem.
         if(item.positionTicket > 0 &&
            PositionSelectByTicket(item.positionTicket))
           {
            item.kind             = ITEM_POSITION;
            item.side             = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            item.openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);
            item.volume           = PositionGetDouble(POSITION_VOLUME);
            item.currentSL        = PositionGetDouble(POSITION_SL);
            item.currentTP        = PositionGetDouble(POSITION_TP);
            item.brokerPresent    = true;
            item.reconcilePending = false;
            item.reconcileMisses  = 0;

            // Broker confirmation completes PLACE. No new command is made.
            if(item.action == ACTION_PLACE)
              {
               item.action              = ACTION_NONE;
               item.actionStatus        = ACTION_IDLE;
               item.requestId           = 0;
                    }

            state.items[i] = item;
            continue;
           }

         // 2) No position. Check whether the order still exists.
         if(item.orderTicket > 0 &&
            OrderSelect(item.orderTicket))
           {
            item.kind             = ITEM_ORDER;
            item.orderType        = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            item.side             = (item.orderType == ORDER_TYPE_BUY_STOP ||
                                     item.orderType == ORDER_TYPE_BUY_LIMIT)
                                    ? POSITION_TYPE_BUY
                                    : POSITION_TYPE_SELL;
            item.openPrice        = OrderGetDouble(ORDER_PRICE_OPEN);
            item.volume           = OrderGetDouble(ORDER_VOLUME_CURRENT);
            item.currentSL        = OrderGetDouble(ORDER_SL);
            item.currentTP        = OrderGetDouble(ORDER_TP);
            item.brokerPresent    = true;
            item.reconcilePending = false;
            item.reconcileMisses  = 0;

            // Broker confirmation completes PLACE. No new command is made.
            if(item.action == ACTION_PLACE)
              {
               item.action              = ACTION_NONE;
               item.actionStatus        = ACTION_IDLE;
               item.requestId           = 0;
                    }

            state.items[i] = item;
            continue;
           }

         // 3) Neither object is currently present. Do not remove on one miss.
         item.brokerPresent = false;
         item.reconcileMisses++;

         if(item.reconcileMisses >= maxReconcileMisses)
           {
            RemoveTradeItem(state, i);
            continue;
           }

         state.items[i] = item;
         continue;
        }

      //=============================================================
      // ASYNC REQUEST SENT - WAITING FOR BROKER RESULT
      //=============================================================
      if(item.actionStatus == ACTION_WAIT_RESULT)
        {
         if(item.sentTimeMs > 0 &&
            now - item.sentTimeMs >=
            (ulong)MathMax(0, InpAsyncResultTimeoutMs))
           {
            item.actionStatus = ACTION_FAILED;
            item.lastRetcode  = TRADE_RETCODE_TIMEOUT;
            state.items[i]    = item;
           }

         continue;
        }

      //=============================================================
      // BROKER ACCEPTED REQUEST - WAITING FOR LIVE CONFIRMATION
      //=============================================================
      if(item.actionStatus == ACTION_WAIT_CONFIRM)
        {
         ulong confirmStart =
            (item.resultTimeMs > 0)
            ? item.resultTimeMs
            : item.sentTimeMs;

         // ---------------------------------------------------------
         // PLACE
         // ---------------------------------------------------------
         if(item.action == ACTION_PLACE)
           {
            bool found = false;

            if(item.orderTicket > 0 && OrderSelect(item.orderTicket))
              {
               found = true;
              }
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
               item.kind              = ITEM_ORDER;
               item.orderType         = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
               item.side              = (item.orderType == ORDER_TYPE_BUY_STOP ||
                                         item.orderType == ORDER_TYPE_BUY_LIMIT)
                                        ? POSITION_TYPE_BUY
                                        : POSITION_TYPE_SELL;
               item.brokerPresent     = true;
               item.openPrice         = OrderGetDouble(ORDER_PRICE_OPEN);
               item.volume            = OrderGetDouble(ORDER_VOLUME_CURRENT);
               item.currentSL         = OrderGetDouble(ORDER_SL);
               item.currentTP         = OrderGetDouble(ORDER_TP);
               item.action            = ACTION_NONE;
               item.actionStatus      = ACTION_IDLE;
               item.requestId         = 0;
               item.reconcilePending  = false;
               item.reconcileMisses   = 0;

               state.items[i] = item;
               continue;
              }
           }

         // ---------------------------------------------------------
         // DELETE
         // ---------------------------------------------------------
         else if(item.action == ACTION_DELETE)
           {
            if(item.orderTicket == 0 || !OrderSelect(item.orderTicket))
              {
               ConfirmReplacementOrRemove(state, i);
               continue;
              }
           }

         // ---------------------------------------------------------
         // CLOSE
         // ---------------------------------------------------------
         else if(item.action == ACTION_CLOSE)
           {
            if(item.positionTicket == 0 ||
               !PositionSelectByTicket(item.positionTicket))
              {
               RemoveTradeItem(state, i);
               continue;
              }
           }

         // ---------------------------------------------------------
         // MODIFY SL
         // ---------------------------------------------------------
         else if(item.action == ACTION_MODIFY_SL)
           {
            if(item.positionTicket == 0 ||
               !PositionSelectByTicket(item.positionTicket))
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

         // ---------------------------------------------------------
         // LIVE CONFIRMATION TIMEOUT
         // ---------------------------------------------------------
         if(confirmStart > 0 &&
            now - confirmStart >=
            (ulong)MathMax(0, InpAsyncLiveConfirmTimeoutMs))
           {
            item.actionStatus = ACTION_FAILED;
            item.lastRetcode  = TRADE_RETCODE_TIMEOUT;
            state.items[i]    = item;
           }

         continue;
        }

      //=============================================================
      // STABLE CONFIRMED ORDER - KEEP LIVE DATA FRESH WHEN CALLED
      //=============================================================
      if(item.actionStatus == ACTION_IDLE &&
         item.kind == ITEM_ORDER &&
         item.orderTicket > 0)
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
           {
            // An order can disappear because it filled. Keep the logical
            // item briefly so a following DEAL_ADD can convert it to POSITION.
            item.brokerPresent    = false;
            item.reconcilePending = true;
            item.reconcileMisses  = 1;
           }

         state.items[i] = item;
        }

      //=============================================================
      // STABLE CONFIRMED POSITION - KEEP LIVE DATA FRESH WHEN CALLED
      //=============================================================
      else if(item.actionStatus == ACTION_IDLE &&
              item.kind == ITEM_POSITION &&
              item.positionTicket > 0)
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
           {
            item.brokerPresent    = false;
            item.reconcilePending = true;
            item.reconcileMisses  = 1;
           }

         state.items[i] = item;
        }
     }

   //===============================================================
   // INITIAL GRID PLACEMENT FINISHED
   //===============================================================
   if(state.lifecycle == GRID_BUILDING &&
      !AnyPlacementStillPending(state))
     {
      if(CountBookOrders(state) > 0)
         state.lifecycle = GRID_READY;
      else if(ArraySize(state.items) == 0)
         state.lifecycle = GRID_IDLE;
     }

   Profiler30Record(PROF30_RECONCILE_TRADE_ITEMS, profStart);
  }

#endif

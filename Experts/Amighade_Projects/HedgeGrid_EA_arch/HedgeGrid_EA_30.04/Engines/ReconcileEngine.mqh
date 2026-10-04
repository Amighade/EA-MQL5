#ifndef RECONCILE_ENGINE_MQH
#define RECONCILE_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/ProfilerUtils.mqh"

bool AnyPlacementStillPending(GridState &state)
  {
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].action == ACTION_PLACE &&
         state.items[i].actionStatus != ACTION_FAILED)
         return true;
   return false;
  }

// Refresh broker facts once, then resolve each existing EA command.
// A timeout is uncertainty, never permission to submit a duplicate request.
void ReconcileTradeItems(GridState &state)
  {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return;
   ulong profStart = GetMicrosecondCount();
   ulong now = GetTickCount64();
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   if(!RebuildTradeBookFromTerminal(state)) return;

   for(int i = ArraySize(state.items) - 1; i >= 0; i--)
     {
      TradeItem item = state.items[i];
      bool waiting = (item.actionStatus == ACTION_WAIT_RESULT ||
                      item.actionStatus == ACTION_WAIT_CONFIRM);
      bool complete = false;

      if(item.action == ACTION_PLACE)
        {
         complete = item.brokerPresent;
         if(complete && item.kind == ITEM_ORDER)
           {
            complete = OrderSelect(item.orderTicket);
            if(complete)
              {
               ENUM_ORDER_STATE liveStatus = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
               complete = (liveStatus == ORDER_STATE_PLACED || liveStatus == ORDER_STATE_PARTIAL);
              }
           }
         if(!complete && item.orderTicket > 0 && HistoryOrderSelect(item.orderTicket))
           {
            ENUM_ORDER_STATE status = (ENUM_ORDER_STATE)HistoryOrderGetInteger(item.orderTicket, ORDER_STATE);
            complete = (status == ORDER_STATE_CANCELED ||
                        status == ORDER_STATE_EXPIRED || status == ORDER_STATE_REJECTED);
            if(status == ORDER_STATE_FILLED)
              {
               // A fill may precede live position visibility. Do not mistake
               // that gap for flatness. A rapid open+close can instead be
               // confirmed from the complete position deal history.
               ulong positionId = (ulong)HistoryOrderGetInteger(item.orderTicket, ORDER_POSITION_ID);
               if(positionId > 0 && HistorySelectByPosition(positionId))
                 {
                  double netVolume = 0.0;
                  bool opened = false;
                  for(int d = 0; d < HistoryDealsTotal(); d++)
                    {
                     ulong deal = HistoryDealGetTicket(d);
                     ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
                     if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
                     ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
                     double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
                     if(entry == DEAL_ENTRY_IN)
                       {
                        netVolume += volume;
                        opened = true;
                       }
                     if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) netVolume -= volume;
                    }
                  complete = (opened && MathAbs(netVolume) < 0.00000001);
                 }
              }
           }
         if(!complete && item.actionStatus == ACTION_FAILED)
           {
            RemoveTradeItem(state, i); // Definitive rejection; no broker object was created.
            continue;
           }
        }
      else if(item.action == ACTION_DELETE)
        {
         if(!item.brokerPresent)
           {
            ConfirmReplacementOrRemove(state, i);
            continue;
           }
        }
      else if(item.action == ACTION_CLOSE || item.action == ACTION_MODIFY_SL)
        {
         if(!item.brokerPresent)
           {
            RemoveTradeItem(state, i);
            continue;
           }
         if(item.action == ACTION_MODIFY_SL)
            complete = (MathAbs(item.currentSL - item.requestedSL) <= tick * 0.5 &&
                        (!waiting || (item.resultTimeMs > 0 &&
                         (item.lastRetcode == TRADE_RETCODE_DONE ||
                          item.lastRetcode == TRADE_RETCODE_NO_CHANGES))));
         else if(item.actionStatus == ACTION_WAIT_CONFIRM &&
                 item.lastRetcode == TRADE_RETCODE_DONE_PARTIAL &&
                 item.volume < item.requestedLot)
           {
            // The broker finished this partial request; the CLOSE command still
            // owns the remainder. Reuse it only after live volume decreased.
            item.actionStatus = ACTION_READY;
            item.requestId = 0;
            item.reconcilePending = false;
            state.items[i] = item;
            continue;
           }
        }

      if(complete)
        {
         item.action = ACTION_NONE;
         item.actionStatus = ACTION_IDLE;
         item.requestId = 0;
         item.reconcilePending = false;
         waiting = false;
        }

      if(waiting)
        {
         ulong since = (item.resultTimeMs > 0) ? item.resultTimeMs : item.sentTimeMs;
         int timeout = (item.actionStatus == ACTION_WAIT_RESULT)
                       ? InpAsyncResultTimeoutMs : InpAsyncLiveConfirmTimeoutMs;
         if(now - since >= (ulong)MathMax(1, timeout))
           {
            if(!item.reconcilePending && InpEnableDebugLog)
               PrintFormat("[REV30.04] Item %u: broker outcome unresolved; no resend.", item.id);
            item.reconcilePending = true;
           }
         state.items[i] = item;
         continue;
        }

      // Unsent plans are local work. Everything else must have a live target.
      if(item.action == ACTION_PLACE && item.actionStatus == ACTION_READY)
        {
         item.reconcilePending = false;
         state.items[i] = item;
         continue;
        }
      if(item.brokerPresent)
        {
         item.reconcilePending = false;
         item.reconcileMisses = 0;
        }
      else
        {
         item.reconcilePending = true;
         item.reconcileMisses++;
         if(item.reconcileMisses >= MathMax(1, InpSafetyRetryAttempts))
           {
            RemoveTradeItem(state, i);
            continue;
           }
        }
      state.items[i] = item;
     }

   if(state.lifecycle != GRID_CLEANUP)
     {
      if(CountBookPositions(state) > 0)
         state.lifecycle = GRID_ACTIVE;
      else if(AnyPlacementStillPending(state))
         state.lifecycle = GRID_BUILDING;
      else if(CountBookOrders(state) > 0 && state.lifecycle != GRID_ACTIVE)
         state.lifecycle = GRID_READY;
      else if(ArraySize(state.items) == 0 &&
              CountLiveTerminalPositions(state.magicNumber) == 0 &&
              CountLiveTerminalOrders(state.magicNumber) == 0 && state.lifecycle != GRID_IDLE)
        {
         ulong nextCycle = state.cycleId + 1;
         ResetGridState(state);
         state.cycleId = nextCycle;
        }
     }
   Profiler30Record(PROF30_RECONCILE_TRADE_ITEMS, profStart);
  }

#endif

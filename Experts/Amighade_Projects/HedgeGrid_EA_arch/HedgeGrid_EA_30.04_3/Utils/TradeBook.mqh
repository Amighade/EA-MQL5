#ifndef TRADE_BOOK_MQH
#define TRADE_BOOK_MQH

#include "../Models/GridState.mqh"
#include "ProfilerUtils.mqh"

//+------------------------------------------------------------------+
//| Small helpers around GridState.items[].                           |
//| This is the only durable order/position book used by Rev 30.04. |
//+------------------------------------------------------------------+

int TradeBookSize(GridState &state)
  {
   return ArraySize(state.items);
  }

int FindItemById(GridState &state, uint id)
  {
   if(id == 0) return -1;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].id == id)
         return i;
   return -1;
  }

int FindItemByOrderTicket(GridState &state, ulong ticket)
  {
   if(ticket == 0) return -1;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].kind == ITEM_ORDER && state.items[i].orderTicket == ticket)
         return i;
   return -1;
  }

int FindItemByPositionTicket(GridState &state, ulong ticket)
  {
   if(ticket == 0) return -1;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].positionTicket == ticket)
         return i;
   return -1;
  }

int FindItemByRequestId(GridState &state, uint requestId)
  {
   if(requestId == 0) return -1;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].requestId == requestId)
         return i;
   return -1;
  }

int FindPlannedOrder(GridState &state, ENUM_ORDER_TYPE type, double price)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;

   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].kind != ITEM_ORDER) continue;
      if(state.items[i].orderType != type) continue;

      double p = (state.items[i].targetPrice > 0.0)
                 ? state.items[i].targetPrice
                 : state.items[i].openPrice;
      if(MathAbs(p - price) <= tick * 0.5)
         return i;
     }
   return -1;
  }

int AddTradeItem(GridState &state)
  {
   int n = ArraySize(state.items);
   if(ArrayResize(state.items, n + 1, 64) < 0)
     {
      state.needsGridVerification = true;
      Print("[REV30.04] Trade book allocation failed; broker scan will retry.");
      return -1;
     }
   ResetTradeItem(state.items[n]);
   state.items[n].id = state.nextItemId++;
   if(state.nextItemId == 0) state.nextItemId = 1;
   return n;
  }

void RemoveTradeItem(GridState &state, int index)
  {
   int total = ArraySize(state.items);
   if(index < 0 || index >= total) return;

   for(int i = index; i < total - 1; i++)
      state.items[i] = state.items[i + 1];

   ArrayResize(state.items, total - 1);
  }

//+------------------------------------------------------------------+
//| Resolve an absent order before removing it or placing its        |
//| already-requested replacement. A delayed fill is still exposure. |
//+------------------------------------------------------------------+
void ConfirmReplacementOrRemove(GridState &state, int index)
  {
   if(index < 0 || index >= ArraySize(state.items)) return;
   TradeItem old = state.items[index];
   if(old.orderTicket == 0)
     {
      RemoveTradeItem(state, index);
      return;
     }
   if(OrderSelect(old.orderTicket)) return;

   // An absent order may have filled before its position became visible.
   // Resolve that transition before discarding the order or replacing it.
   if(!HistoryOrderSelect(old.orderTicket))
     {
      state.items[index].reconcilePending = true;
      return;
     }
   ENUM_ORDER_STATE status = (ENUM_ORDER_STATE)HistoryOrderGetInteger(old.orderTicket, ORDER_STATE);
   if(status != ORDER_STATE_FILLED &&
      status != ORDER_STATE_CANCELED && status != ORDER_STATE_EXPIRED &&
      status != ORDER_STATE_REJECTED)
     {
      state.items[index].reconcilePending = true;
      return;
     }
   ulong positionId = (ulong)HistoryOrderGetInteger(old.orderTicket, ORDER_POSITION_ID);
   double filledVolume = HistoryOrderGetDouble(old.orderTicket, ORDER_VOLUME_INITIAL) -
                         HistoryOrderGetDouble(old.orderTicket, ORDER_VOLUME_CURRENT);
   if(positionId > 0 || status == ORDER_STATE_FILLED)
     {
      bool resolved = false;
      for(int j = 0; j < ArraySize(state.items); j++)
         if(state.items[j].kind == ITEM_POSITION && state.items[j].orderTicket == positionId &&
            state.items[j].brokerPresent && PositionSelectByTicket(state.items[j].positionTicket))
            resolved = true;
      if(!resolved && positionId > 0 && HistorySelectByPosition(positionId))
        {
         double netVolume = 0.0;
         double entryVolume = 0.0;
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
               if((ulong)HistoryDealGetInteger(deal, DEAL_ORDER) == old.orderTicket)
                  entryVolume += volume;
              }
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) netVolume -= volume;
           }
         resolved = (entryVolume > 0.0 && entryVolume + 0.00000001 >= filledVolume &&
                     MathAbs(netVolume) < 0.00000001);
        }
      if(!resolved)
        {
         state.items[index].reconcilePending = true;
         return;
        }
     }

   if(old.replaceAfterDelete && state.lifecycle != GRID_CLEANUP &&
      (status == ORDER_STATE_CANCELED || status == ORDER_STATE_EXPIRED ||
       status == ORDER_STATE_REJECTED))
     {
      ResetTradeItem(state.items[index]);
      state.items[index].id             = old.id;
      state.items[index].kind           = ITEM_ORDER;
      state.items[index].orderType      = old.orderType;
      state.items[index].side           = old.side;
      state.items[index].level          = old.level;
      state.items[index].originalLot    = old.originalLot;
      state.items[index].targetPrice    = old.replacementPrice;
      state.items[index].targetLot      = old.replacementLot;
      state.items[index].requestedPrice = old.replacementPrice;
      state.items[index].requestedLot   = old.replacementLot;
      state.items[index].requestedSL    = old.replacementSL;
      state.items[index].requestedTP    = old.replacementTP;
      state.items[index].action         = ACTION_PLACE;
      state.items[index].actionStatus   = ACTION_READY;
      return;
     }
   RemoveTradeItem(state, index);
  }

int CountBookOrders(GridState &state)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].kind != ITEM_ORDER) continue;
      if(!state.items[i].brokerPresent &&
         (state.items[i].action != ACTION_PLACE || state.items[i].actionStatus == ACTION_FAILED)) continue;
      count++;
     }
   return count;
  }

int CountBookPositions(GridState &state)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].kind != ITEM_POSITION) continue;
      if(!state.items[i].brokerPresent) continue;
      count++;
     }
   return count;
  }

int CountBookOrderType(GridState &state, ENUM_ORDER_TYPE type)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].kind != ITEM_ORDER) continue;
      if(!state.items[i].brokerPresent &&
         (state.items[i].action != ACTION_PLACE || state.items[i].actionStatus == ACTION_FAILED)) continue;
      if(state.items[i].orderType != type) continue;
      count++;
     }
   return count;
  }

int CountLiveTerminalPositions(int magicNumber)
  {
   ulong profStart = GetMicrosecondCount();
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      count++;
     }
   Profiler30Record(PROF30_COUNT_LIVE_POSITIONS, profStart);
   return count;
  }

int CountLiveTerminalOrders(int magicNumber)
  {
   ulong profStart = GetMicrosecondCount();
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type < ORDER_TYPE_BUY_LIMIT || type > ORDER_TYPE_SELL_STOP_LIMIT) continue;
      count++;
     }
   Profiler30Record(PROF30_COUNT_LIVE_ORDERS, profStart);
   return count;
  }

bool TerminalOrderExists(ulong ticket)
  {
   return (ticket > 0 && OrderSelect(ticket));
  }

bool TerminalPositionExists(ulong ticket)
  {
   return (ticket > 0 && PositionSelectByTicket(ticket));
  }

//+------------------------------------------------------------------+
//| Merge live broker objects into the existing book.                |
//| Also used at startup; never discard an existing EA command.      |
//+------------------------------------------------------------------+
bool RebuildTradeBookFromTerminal(GridState &state)
  {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return false;
   // One broker-data path for startup, events, reconciliation and cleanup.
   // A scan marks presence; ReconcileTradeItems decides action completion.
   for(int i = 0; i < ArraySize(state.items); i++)
      state.items[i].brokerPresent = false;

   for(int o = 0; o < OrdersTotal(); o++)
     {
      ulong ticket = OrderGetTicket(o);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type < ORDER_TYPE_BUY_LIMIT || type > ORDER_TYPE_SELL_STOP_LIMIT) continue;
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      int idx = FindItemByOrderTicket(state, ticket);
      if(idx < 0) idx = AddTradeItem(state);
      if(idx < 0) return false;

      state.items[idx].kind          = ITEM_ORDER;
      state.items[idx].orderTicket   = ticket;
      state.items[idx].orderType     = type;
      state.items[idx].side          = (type == ORDER_TYPE_BUY_LIMIT ||
                                       type == ORDER_TYPE_BUY_STOP ||
                                       type == ORDER_TYPE_BUY_STOP_LIMIT)
                                      ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      state.items[idx].openPrice     = price;
      state.items[idx].volume        = OrderGetDouble(ORDER_VOLUME_CURRENT);
      state.items[idx].currentSL     = OrderGetDouble(ORDER_SL);
      state.items[idx].currentTP     = OrderGetDouble(ORDER_TP);
      state.items[idx].brokerPresent = true;
      if(state.items[idx].targetPrice == 0.0) state.items[idx].targetPrice = price;
      if(state.items[idx].targetLot == 0.0) state.items[idx].targetLot = state.items[idx].volume;
      if(state.items[idx].originalLot == 0.0)
         state.items[idx].originalLot = OrderGetDouble(ORDER_VOLUME_INITIAL);
     }

   for(int p = 0; p < PositionsTotal(); p++)
     {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;
      ulong sourceOrder = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int idx = FindItemByPositionTicket(state, ticket);

      // The stable opening-order identity also survives broker ticket changes.
      if(idx < 0)
         for(int j = 0; j < ArraySize(state.items); j++)
            if(state.items[j].kind == ITEM_POSITION && state.items[j].orderTicket == sourceOrder)
              {
               idx = j;
               break;
              }

      int source = FindItemByOrderTicket(state, sourceOrder);

      // Keep DELETE on its original order until history distinguishes a fill
      // from cancellation of a partially filled remainder.
      bool reuseSource = (source >= 0 && !state.items[source].brokerPresent &&
                          state.items[source].action != ACTION_DELETE);
      if(idx < 0 && reuseSource)
         idx = source;
      else if(idx >= 0 && reuseSource)
        {
         // Recovery may have found the position before its source history.
         // Merge that old order/plan instead of leaving a second waiting item.
         if(state.items[idx].level < 0) state.items[idx].level = state.items[source].level;
         state.items[idx].originalLot = state.items[source].originalLot;
         RemoveTradeItem(state, source);
         if(source < idx) idx--;
         source = -1;
        }
      if(idx < 0)
        {
         idx = AddTradeItem(state);
         if(idx < 0) return false;
         if(source >= 0)
           {
            state.items[idx].level       = state.items[source].level;
            state.items[idx].targetPrice = state.items[source].targetPrice;
            state.items[idx].originalLot = state.items[source].originalLot;
           }
        }

      state.items[idx].kind           = ITEM_POSITION;
      state.items[idx].orderTicket    = sourceOrder;
      state.items[idx].positionTicket = ticket;
      state.items[idx].side           = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      state.items[idx].openPrice      = PositionGetDouble(POSITION_PRICE_OPEN);
      state.items[idx].volume         = PositionGetDouble(POSITION_VOLUME);
      state.items[idx].currentSL      = PositionGetDouble(POSITION_SL);
      state.items[idx].currentTP      = PositionGetDouble(POSITION_TP);
      state.items[idx].brokerPresent  = true;
      if(state.items[idx].targetLot == 0.0) state.items[idx].targetLot = state.items[idx].volume;
      if(state.items[idx].originalLot == 0.0) state.items[idx].originalLot = state.items[idx].volume;
     }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return false;
   state.needsGridVerification = false;
   return true;
  }

#endif

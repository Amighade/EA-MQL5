#ifndef TRADE_BOOK_MQH
#define TRADE_BOOK_MQH

#include "../Models/GridState.mqh"
#include "ProfilerUtils.mqh"

//+------------------------------------------------------------------+
//| Small helpers around GridState.items[].                           |
//| This is the only durable order/position book used by Rev 30.01. |
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
      if(state.items[i].orderTicket == ticket)
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
      if(state.items[i].actionStatus == ACTION_FAILED) continue;
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
   ArrayResize(state.items, n + 1);
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

int CountBookOrders(GridState &state)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      if(state.items[i].kind != ITEM_ORDER) continue;
      if(state.items[i].actionStatus == ACTION_FAILED) continue;
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
      if(state.items[i].actionStatus == ACTION_FAILED) continue;
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
      if(state.items[i].actionStatus == ACTION_FAILED) continue;
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
//| Rebuild the durable book from live terminal state.               |
//| Used only at initialization/account reconciliation.              |
//+------------------------------------------------------------------+
void RebuildTradeBookFromTerminal(GridState &state)
  {
   ArrayResize(state.items, 0);
   state.nextItemId = 1;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;

      int idx = AddTradeItem(state);
      state.items[idx].kind          = ITEM_ORDER;
      state.items[idx].orderTicket   = ticket;
      state.items[idx].orderType     = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      state.items[idx].side          = (state.items[idx].orderType == ORDER_TYPE_BUY_STOP ||
                                        state.items[idx].orderType == ORDER_TYPE_BUY_LIMIT)
                                       ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      state.items[idx].targetPrice   = OrderGetDouble(ORDER_PRICE_OPEN);
      state.items[idx].targetLot     = OrderGetDouble(ORDER_VOLUME_CURRENT);
      state.items[idx].originalLot   = state.items[idx].targetLot;
      state.items[idx].openPrice     = state.items[idx].targetPrice;
      state.items[idx].volume        = state.items[idx].targetLot;
      state.items[idx].currentSL     = OrderGetDouble(ORDER_SL);
      state.items[idx].currentTP     = OrderGetDouble(ORDER_TP);
      state.items[idx].brokerPresent = true;
     }

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;

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

   int positions = CountBookPositions(state);
   int orders    = CountBookOrders(state);

   if(positions > 0)
      state.lifecycle = GRID_ACTIVE;
   else if(orders > 0)
      state.lifecycle = GRID_READY;
   else
      state.lifecycle = GRID_IDLE;
  }

#endif

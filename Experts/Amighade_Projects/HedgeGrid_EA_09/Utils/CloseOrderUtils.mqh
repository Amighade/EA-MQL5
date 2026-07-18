//+------------------------------------------------------------------+
//| CloseOrderUtils.mqh                                                |
//| Shared ordering helpers for closing positions and deleting        |
//| pending orders, per the priority rules:                          |
//|   - Positions: zigzag by profit (most positive, most negative,   |
//|     next most positive, next most negative, ...), ticket order   |
//|     tie-break. Applies to ALL position-closing scenarios.        |
//|   - Pending orders: closest to current price first, outward.     |
//+------------------------------------------------------------------+
#ifndef CLOSE_ORDER_UTILS_MQH
#define CLOSE_ORDER_UTILS_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Build the zigzag (most-positive/most-negative alternating) close |
//| order for every open position belonging to this EA.              |
//+------------------------------------------------------------------+
void BuildZigzagPositionOrder(int magicNumber, ulong &orderedTickets[])
  {
   ulong  tickets[];
   double profits[];
   int    n = 0;

   ArrayResize(tickets, PositionsTotal());
   ArrayResize(profits, PositionsTotal());

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;

      tickets[n] = t;
      profits[n] = PositionGetDouble(POSITION_PROFIT);
      n++;
     }

   ArrayResize(tickets, n);
   ArrayResize(profits, n);

   // Sort descending by profit (simple insertion sort — n is small, grid-sized)
   // Ticket order is the natural tie-break since ties keep their relative order (stable sort).
   for(int i = 1; i < n; i++)
     {
      double keyP = profits[i];
      ulong  keyT = tickets[i];
      int j = i - 1;
      while(j >= 0 && profits[j] < keyP)
        {
         profits[j+1] = profits[j];
         tickets[j+1] = tickets[j];
         j--;
        }
      profits[j+1] = keyP;
      tickets[j+1] = keyT;
     }

   // Zigzag: [max, min, 2nd max, 2nd min, ...]
   ArrayResize(orderedTickets, n);
   int lo = 0, hi = n - 1, out = 0;
   bool takeHigh = true;
   while(lo <= hi)
     {
      if(takeHigh) { orderedTickets[out++] = tickets[lo++]; }
      else         { orderedTickets[out++] = tickets[hi--]; }
      takeHigh = !takeHigh;
     }
  }

//+------------------------------------------------------------------+
//| Build the proximity close order for every pending order belonging|
//| to this EA: closest to current price first, outward.             |
//+------------------------------------------------------------------+
void BuildProximityOrderOrder(int magicNumber, ulong &orderedTickets[])
  {
   ulong  tickets[];
   double dist[];
   int    n = 0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   ArrayResize(tickets, OrdersTotal());
   ArrayResize(dist,    OrdersTotal());

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)     continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;

      tickets[n] = t;
      dist[n]    = MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price);
      n++;
     }

   ArrayResize(tickets, n);
   ArrayResize(dist,    n);

   // Sort ascending by distance (closest first)
   for(int i = 1; i < n; i++)
     {
      double keyD = dist[i];
      ulong  keyT = tickets[i];
      int j = i - 1;
      while(j >= 0 && dist[j] > keyD)
        {
         dist[j+1]    = dist[j];
         tickets[j+1] = tickets[j];
         j--;
        }
      dist[j+1]    = keyD;
      tickets[j+1] = keyT;
     }

   ArrayResize(orderedTickets, n);
   for(int i = 0; i < n; i++)
      orderedTickets[i] = tickets[i];
  }

#endif

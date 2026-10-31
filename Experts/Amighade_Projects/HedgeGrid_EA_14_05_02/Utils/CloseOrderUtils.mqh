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
//| Build the proximity close order for every pending order belonging|
//| to this EA: closest to current price first, outward.             |
//+------------------------------------------------------------------+
void BuildProximityOrderOrder(int magicNumber, ulong &orderedTickets[])
  {
   ulong  tickets[];
   double dist[];
   int    n = 0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    total = OrdersTotal();      // captured ONCE

   ArrayResize(tickets, total);
   ArrayResize(dist,    total);

   for(int i = 0; i < total; i++)     // loop bound is the SAME captured value
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
  
  void CollectOrderTickets(int magicNumber, ulong &orderedTickets[])
{
   int total = OrdersTotal();
   int count = 0;

   if(ArrayResize(orderedTickets, total) != total)
     {
      ArrayFree(orderedTickets);
      return;
     }

   for(int i = 0; i < total; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;

      orderedTickets[count++] = ticket;
     }

   ArrayResize(orderedTickets, count);
}

//+------------------------------------------------------------------+
//| Build the close order for every open position, sorted by         |
//| absolute profit descending — biggest winner or loser closes      |
//| first, regardless of sign. No zigzag interleaving.               |
//+------------------------------------------------------------------+
void BuildAbsProfitPositionOrder_ongoing(GridState &state,
                                ulong &orderedTickets[])
{
   int total = ArraySize(state.positionItems);
   double volumes[];

   if(ArrayResize(orderedTickets, total) != total ||
      ArrayResize(volumes, total) != total)
     {
      ArrayFree(orderedTickets);
      return;
     }

   for(int i = 0; i < total; i++)
     {
      orderedTickets[i] = state.positionItems[i].ticket;
      volumes[i]        = state.positionItems[i].volume;
     }

   // Largest position volume first; preserve order for equal volumes.
   for(int i = 1; i < total; i++)
     {
      double keyVolume = volumes[i];
      ulong  keyTicket = orderedTickets[i];
      int j = i - 1;

      while(j >= 0 && volumes[j] < keyVolume)
        {
         volumes[j + 1]        = volumes[j];
         orderedTickets[j + 1] = orderedTickets[j];
         j--;
        }

      volumes[j + 1]        = keyVolume;
      orderedTickets[j + 1] = keyTicket;
     }
}


void BuildAbsProfitPositionOrder(int magicNumber, ulong &orderedTickets[])
  {
   ulong  tickets[];
   double absProfits[];
   int    n = 0;
   int    total = PositionsTotal();   // captured ONCE

   ArrayResize(tickets, total);
   ArrayResize(absProfits, total);

   for(int i = 0; i < total; i++)     // loop bound is the SAME captured value
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;

      tickets[n]    = t;
      absProfits[n] = MathAbs(PositionGetDouble(POSITION_PROFIT));
      n++;
     }

   ArrayResize(tickets, n);
   ArrayResize(absProfits, n);

   // Sort descending by |profit| — stable insertion sort, same style as the zigzag builder
   for(int i = 1; i < n; i++)
     {
      double keyP = absProfits[i];
      ulong  keyT = tickets[i];
      int j = i - 1;
      while(j >= 0 && absProfits[j] < keyP)
        {
         absProfits[j+1] = absProfits[j];
         tickets[j+1]    = tickets[j];
         j--;
        }
      absProfits[j+1] = keyP;
      tickets[j+1]    = keyT;
     }

   ArrayResize(orderedTickets, n);
   for(int i = 0; i < n; i++)
      orderedTickets[i] = tickets[i];
  }
 
#endif

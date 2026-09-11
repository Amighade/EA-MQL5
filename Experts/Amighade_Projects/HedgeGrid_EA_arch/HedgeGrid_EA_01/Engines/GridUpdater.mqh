//+------------------------------------------------------------------+
//| GridUpdater.mqh                                                   |
//| Update opposite grid lot sizes after an order is hit             |
//| 1st pass (counter < 2): update orders where lot < newLot        |
//| 2nd pass (counter >= 2): replace ALL opposite orders with newLot |
//+------------------------------------------------------------------+
#ifndef GRID_UPDATER_MQH
#define GRID_UPDATER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Get the order type of the OPPOSITE side                          |
//| If BUY was hit → we update SELL STOP orders, and vice versa      |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetOppositeOrderType(ENUM_ORDER_TYPE hitDirection)
  {
   return (hitDirection == ORDER_TYPE_BUY) ?
           ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
  }

//+------------------------------------------------------------------+
//| Collect all pending orders on the opposite side                   |
//| Fills arrays with ticket and current lot for each order          |
//| Returns count of orders found                                    |
//+------------------------------------------------------------------+
int CollectOppositeOrders(ENUM_ORDER_TYPE oppositeType, int magicNumber,
                          ulong &tickets[], double &lots[], double &prices[])
  {
   int count = 0;
   ArrayResize(tickets, 0);
   ArrayResize(lots,    0);
   ArrayResize(prices,  0);

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)    != _Symbol)     continue;
      if(OrderGetInteger(ORDER_MAGIC)    != magicNumber)  continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != oppositeType) continue;

      ArrayResize(tickets, count + 1);
      ArrayResize(lots,    count + 1);
      ArrayResize(prices,  count + 1);
      tickets[count] = ticket;
      lots[count]    = OrderGetDouble(ORDER_VOLUME_CURRENT);
      prices[count]  = OrderGetDouble(ORDER_PRICE_OPEN);
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| 1st pass update: only update orders where currentLot < newLot   |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_FirstPass(ENUM_ORDER_TYPE hitDirection, double newLot, GridState &state)
  {
   ENUM_ORDER_TYPE oppositeType = GetOppositeOrderType(hitDirection);

   ulong  tickets[];
   double lots[];
   double prices[];
   int    count = CollectOppositeOrders(oppositeType, state.magicNumber, tickets, lots, prices);

   int    updatedCount = 0;
   double oldLot       = 0.0;

   for(int i = 0; i < count; i++)
     {
      if(lots[i] < newLot)
        {
         // Delete old order and replace with same price but new lot
         oldLot = lots[i];
         DeleteOrder(tickets[i]);

         if(oppositeType == ORDER_TYPE_SELL_STOP)
            PlaceSellStop(prices[i], newLot);
         else
            PlaceBuyStop(prices[i], newLot);

         updatedCount++;
        }
      // Orders with lot >= newLot are left completely unchanged
     }

   if(updatedCount > 0)
     {
      state.currentBlockLot = newLot;
      LogLotUpdated(updatedCount, oldLot, newLot);
     }
  }

//+------------------------------------------------------------------+
//| 2nd pass update: replace ALL opposite orders with newLot         |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_SecondPass(ENUM_ORDER_TYPE hitDirection, double newLot, GridState &state)
  {
   ENUM_ORDER_TYPE oppositeType = GetOppositeOrderType(hitDirection);

   ulong  tickets[];
   double lots[];
   double prices[];
   int    count = CollectOppositeOrders(oppositeType, state.magicNumber, tickets, lots, prices);

   double oldLot = (count > 0) ? lots[0] : 0.0;

   // Delete all opposite orders
   for(int i = 0; i < count; i++)
      DeleteOrder(tickets[i]);

   // Replace with new lot at same prices
   for(int i = 0; i < count; i++)
     {
      if(oppositeType == ORDER_TYPE_SELL_STOP)
         PlaceSellStop(prices[i], newLot);
      else
         PlaceBuyStop(prices[i], newLot);
     }

   state.currentBlockLot = newLot;
   LogLotUpdated(count, oldLot, newLot);
  }

//+------------------------------------------------------------------+
//| Master function — selects 1st or 2nd pass based on counter       |
//| Called by HedgeGrid.mq5 after every order fill                   |
//+------------------------------------------------------------------+
void UpdateOppositeGrid(GridState &state)
  {
   double newLot = NormalizeDouble(state.lastHitLot * 2.0, 2);

   if(state.passCounter < 2)
      UpdateOppositeGrid_FirstPass(state.lastHitDirection, newLot, state);
   else
      UpdateOppositeGrid_SecondPass(state.lastHitDirection, newLot, state);
  }


#endif
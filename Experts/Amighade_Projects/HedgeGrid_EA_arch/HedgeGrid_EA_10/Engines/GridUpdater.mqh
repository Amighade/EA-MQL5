//+------------------------------------------------------------------+
//| GridUpdater.mqh                                                   |
//| BRICK 1: increase the OPPOSITE side's lot size after a hit.      |
//| Gated by InpEnableLotIncrease. If enabled, InpLotIncreaseMode     |
//| selects the algorithm:                                            |
//|   LOT_INC_A: pass-counter driven (implemented, see below):       |
//|     1st pass (counter < 2): update orders where lot < newLot     |
//|     2nd pass (counter >= 2): replace ALL opposite orders          |
//|   LOT_INC_B / LOT_INC_C: reserved stubs, currently no-op.        |
//| If disabled entirely, lots never change (equivalent to the old   |
//| Style C's fixed-lot-forever behavior).                            |
//| NOTE: keep InpEnableLotIncrease = false when either refill brick |
//| is enabled — not auto-enforced, user's responsibility.            |
//+------------------------------------------------------------------+
#ifndef GRID_UPDATER_MQH
#define GRID_UPDATER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Get the pending order type of the OPPOSITE side                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetOppositeOrderType(ENUM_ORDER_TYPE hitDirection)
{
   return (hitDirection == ORDER_TYPE_BUY) ?
           ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
}

//+------------------------------------------------------------------+
//| Collect all pending orders on the opposite side                  |
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
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
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
//| 1st pass: update only orders where currentLot < newLot           |
//| Orders already at newLot or higher are left completely unchanged  |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_FirstPass(ENUM_ORDER_TYPE hitDirection,
                                  double newLot,
                                  GridState &state)
{
   ENUM_ORDER_TYPE oppositeType = GetOppositeOrderType(hitDirection);

   ulong  tickets[];
   double lots[];
   double prices[];
   int    count = CollectOppositeOrders(oppositeType, state.magicNumber,
                                        tickets, lots, prices);

   int    updatedCount = 0;
   double oldLot       = 0.0;

   for(int i = 0; i < count; i++)
     {
      if(lots[i] < newLot)
        {
         oldLot = lots[i];
         DeleteOrder(tickets[i]);

         if(oppositeType == ORDER_TYPE_SELL_STOP)
            PlaceSellStop(prices[i], newLot, state.magicNumber);
         else
            PlaceBuyStop(prices[i],  newLot, state.magicNumber);

         updatedCount++;
        }
      // Orders with lot >= newLot: leave untouched at original price and lot
     }

   if(updatedCount > 0)
     {
      state.currentBlockLot = newLot;
      LogLotUpdated(updatedCount, oldLot, newLot);
     }
}
//+------------------------------------------------------------------+
//| 2nd pass: replace opposite orders with newLot — but only the     |
//| ones that actually differ. Orders already at newLot are left     |
//| untouched, so repeated same-side hits with no real lot change    |
//| don't churn the whole side for nothing.                          |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_SecondPass(ENUM_ORDER_TYPE hitDirection,
                                   double newLot,
                                   GridState &state)
{
   ENUM_ORDER_TYPE oppositeType = GetOppositeOrderType(hitDirection);
   ulong  tickets[];
   double lots[];
   double prices[];
   int    count = CollectOppositeOrders(oppositeType, state.magicNumber,
                                        tickets, lots, prices);

   int    updatedCount = 0;
   double oldLot       = 0.0;
   double newLotNorm    = NormalizeDouble(newLot, 2);

   for(int i = 0; i < count; i++)
     {
      if(NormalizeDouble(lots[i], 2) == newLotNorm)
         continue; // already correct — leave it alone

      oldLot = lots[i];
      DeleteOrder(tickets[i]);
      if(oppositeType == ORDER_TYPE_SELL_STOP)
         PlaceSellStop(prices[i], newLot, state.magicNumber);
      else
         PlaceBuyStop(prices[i],  newLot, state.magicNumber);
      updatedCount++;
     }

   state.currentBlockLot = newLot;
   if(updatedCount > 0)
      LogLotUpdated(updatedCount, oldLot, newLot);
}
//+------------------------------------------------------------------+
//| Sub-option A — pass-counter driven (the only implemented mode)   |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_ModeA(GridState &state)
{
   double newLot = AlignVolume(_Symbol, state.lastHitLot * 2.0);
   UpdateOppositeGrid_FirstPass(state.lastHitDirection, newLot, state);

   /*if(state.passCounter < 2)
      UpdateOppositeGrid_FirstPass(state.lastHitDirection, newLot, state);
   else
      UpdateOppositeGrid_SecondPass(state.lastHitDirection, newLot, state);*/
}

//+------------------------------------------------------------------+
//| Sub-option B — STUB. Reserved for future logic. Currently no-op. |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_ModeB(GridState &state)
{
   // TODO: implement when a second lot-increase algorithm is defined.
}

//+------------------------------------------------------------------+
//| Sub-option C — STUB. Reserved for future logic. Currently no-op. |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_ModeC(GridState &state)
{
   // TODO: implement when a third lot-increase algorithm is defined.
}

//+------------------------------------------------------------------+
//| Master entry point. No-op unless InpEnableLotIncrease is true.   |
//| Called by HedgeGrid.mq5 after every confirmed order fill.        |
//+------------------------------------------------------------------+
void UpdateOppositeGrid(GridState &state)
{
   if(!InpEnableLotIncrease) return;

   switch(InpLotIncreaseMode)
     {
      case LOT_INC_A: UpdateOppositeGrid_ModeA(state); break;
      case LOT_INC_B: UpdateOppositeGrid_ModeB(state); break;
      case LOT_INC_C: UpdateOppositeGrid_ModeC(state); break;
     }
}

#endif

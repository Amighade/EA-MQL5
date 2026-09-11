#ifndef POSITION_ORDER_SNAPSHOT_MQH
#define POSITION_ORDER_SNAPSHOT_MQH

#include "../Models/GridState.mqh"

void RefreshPositionSnapshot(GridState &state)
{
   state.sellPositionCount        = 0;
   state.buyPositionCount         = 0;
   state.positionCount            = 0;
   state.lowestSellPositionPrice  = DBL_MAX;
   state.lowestSellPositionLot    = 0.0;
   state.highestBuyPositionPrice  = 0.0;
   state.highestBuyPositionLot    = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)          continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;

      state.positionCount++;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double p   = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);

      if(type == POSITION_TYPE_SELL)
        {
         state.sellPositionCount++;
         if(p < state.lowestSellPositionPrice)
           {
            state.lowestSellPositionPrice = p;
            state.lowestSellPositionLot   = lot;
           }
        }
      else if(type == POSITION_TYPE_BUY)
        {
         state.buyPositionCount++;
         if(p > state.highestBuyPositionPrice)
           {
            state.highestBuyPositionPrice = p;
            state.highestBuyPositionLot   = lot;
           }
        }
     }
   if(state.lowestSellPositionPrice == DBL_MAX) state.lowestSellPositionPrice = 0.0;
}

void RefreshOrderSnapshot(GridState &state)
{
   state.sellOrderCount       = 0;
   state.buyOrderCount        = 0;
   state.lowestSellOrderPrice = DBL_MAX;
   state.lowestSellOrderLot   = 0.0;
   state.highestBuyOrderPrice = 0.0;
   state.highestBuyOrderLot   = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)              continue;
      if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber)    continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double p   = OrderGetDouble(ORDER_PRICE_OPEN);
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);

      if(type == ORDER_TYPE_SELL_STOP)
        {
         state.sellOrderCount++;
         if(p < state.lowestSellOrderPrice)
           {
            state.lowestSellOrderPrice = p;
            state.lowestSellOrderLot   = lot;
           }
        }
      else if(type == ORDER_TYPE_BUY_STOP)
        {
         state.buyOrderCount++;
         if(p > state.highestBuyOrderPrice)
           {
            state.highestBuyOrderPrice = p;
            state.highestBuyOrderLot   = lot;
           }
        }
     }
   if(state.lowestSellOrderPrice == DBL_MAX) state.lowestSellOrderPrice = 0.0;
}

#endif
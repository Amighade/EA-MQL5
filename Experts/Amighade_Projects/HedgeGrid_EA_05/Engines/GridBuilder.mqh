#ifndef GRID_BUILDER_MQH
#define GRID_BUILDER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "SizingEngine.mqh"

//+------------------------------------------------------------------+
//| SHARED ORDER QUERY HELPERS                                       |
//+------------------------------------------------------------------+

int CountOrderType(ENUM_ORDER_TYPE orderType, int magicNumber)
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
      count++;
     }
   return count;
}

double GetNearestBuyStop(int magicNumber)
{
   double nearest = DBL_MAX;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p < nearest) nearest = p;
     }
   return (nearest == DBL_MAX) ? 0.0 : nearest;
}

double GetNearestSellStop(int magicNumber)
{
   double nearest = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p > nearest) nearest = p;
     }
   return nearest;
}

double GetHighestBuyStop(int magicNumber)
{
   double highest = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p > highest) highest = p;
     }
   return highest;
}

double GetLowestSellStop(int magicNumber)
{
   double lowest = DBL_MAX;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p < lowest) lowest = p;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
}

//+------------------------------------------------------------------+
//| SHARED PLACEMENT HELPER                                          |
//+------------------------------------------------------------------+
void PlaceOrderPair(double buyPrice, double buyLot,
                    double sellPrice, double sellLot, int magicNumber)
{
   if(IsBullishCandle())
     { PlaceSellStop(sellPrice, sellLot, magicNumber);
       PlaceBuyStop(buyPrice,   buyLot,  magicNumber); }
   else
     { PlaceBuyStop(buyPrice,   buyLot,  magicNumber);
       PlaceSellStop(sellPrice, sellLot, magicNumber); }
}

//+------------------------------------------------------------------+
//| STYLE A — Asymmetric ladder                                      |
//+------------------------------------------------------------------+
void BuildGrid_A(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);
   double firstBuy  = AlignToTick(_Symbol, price + halfGap);
   double firstSell = AlignToTick(_Symbol, price - halfGap);
   for(int level = 1; level <= maxLevels; level++)
     {
      double bp = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
      double sp = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
      PlaceOrderPair(bp, GetLot(level,lotMode), sp, GetLot(level,lotMode), state.magicNumber);
     }
   state.anchorBuy  = firstBuy;
   state.anchorSell = firstSell;
   state.gridPlaced = true; state.cycleActive = false;
   LogGridBuilt(firstBuy, firstSell, lotMode==LOT_FULL?"FULL":"HALF");
}

//+------------------------------------------------------------------+
//| STYLE B — Symmetric fixed lot                                    |
//+------------------------------------------------------------------+
void BuildGrid_B(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);
   double lot       = GetLot(1, lotMode);
   double firstBuy  = AlignToTick(_Symbol, price + halfGap);
   double firstSell = AlignToTick(_Symbol, price - halfGap);
   for(int level = 1; level <= maxLevels; level++)
     {
      double bp = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
      double sp = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
      PlaceOrderPair(bp, lot, sp, lot, state.magicNumber);
     }
   state.anchorBuy  = firstBuy;
   state.anchorSell = firstSell;
   state.gridPlaced = true; state.cycleActive = false;
   LogGridBuilt(firstBuy, firstSell, lotMode==LOT_FULL?"FULL":"HALF");
}

//+------------------------------------------------------------------+
//| STYLE C — Persistent fixed lot grid                              |
//+------------------------------------------------------------------+
void BuildGrid_C(double price, GridState &state)
{
   double halfGap  = InpInitialGap / 2.0;
   double firstBuy = AlignToTick(_Symbol, price + halfGap);
   double firstSell= AlignToTick(_Symbol, price - halfGap);
   for(int level = 1; level <= InpInitialGridLevels; level++)
     {
      double bp = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
      double sp = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
      PlaceOrderPair(bp, InpFixedLot, sp, InpFixedLot, state.magicNumber);
     }
   state.anchorBuy  = firstBuy;
   state.anchorSell = firstSell;
   state.gridPlaced = true; state.cycleActive = false;
   LogGridBuilt(firstBuy, firstSell, "STYLE_C");
}

//+------------------------------------------------------------------+
//| STYLE C — Fill one side of grid after SL hit                    |
//|                                                                  |
//| Inside gap: ALWAYS fill regardless of current count             |
//|   Fill between nearest SELL STOP and nearest BUY STOP           |
//|   Maintain InpInitialGap between nearest pair                   |
//|                                                                  |
//| Outside: ONLY fill if count < InpMinGridLevels                  |
//|   Extend beyond outermost order to reach InpInitialGridLevels   |
//|                                                                  |
//| Skip silently on broker rejection                                |
//+------------------------------------------------------------------+
void FillOneSide(ENUM_ORDER_TYPE orderType, GridState &state)
{
   bool   isBuy      = (orderType == ORDER_TYPE_BUY_STOP);
   double nearestBuy = GetNearestBuyStop(state.magicNumber);
   double nearestSell= GetNearestSellStop(state.magicNumber);
   int    current    = CountOrderType(orderType, state.magicNumber);

   // ---- INSIDE FILL (always, regardless of count) ----
   // Boundary: must preserve InpInitialGap between nearest pair
   // BUY side inside fill: from (nearestSell + InpInitialGap) up to (nearestBuy - InpGridSpacing)
   // SELL side inside fill: from (nearestBuy - InpInitialGap) down to (nearestSell + InpGridSpacing)
   if(nearestBuy > 0 && nearestSell > 0)
     {
      double insideStart = isBuy ?
         AlignToTick(_Symbol, nearestSell + InpInitialGap) :
         AlignToTick(_Symbol, nearestBuy  - InpInitialGap);
      double insideEnd = isBuy ?
         AlignToTick(_Symbol, nearestBuy  - InpGridSpacing) :
         AlignToTick(_Symbol, nearestSell + InpGridSpacing);

      for(double p = insideStart;
          isBuy ? (p <= insideEnd) : (p >= insideEnd);
          p = isBuy ? p + InpGridSpacing : p - InpGridSpacing)
        {
         double price = AlignToTick(_Symbol, p);
         // Skip if level already occupied
         bool exists = false;
         for(int i = 0; i < OrdersTotal() && !exists; i++)
           {
            ulong t = OrderGetTicket(i);
            if(!OrderSelect(t)) continue;
            if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
            if(OrderGetInteger(ORDER_MAGIC)  != state.magicNumber) continue;
            if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
            if(NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), price)) exists = true;
           }
         if(exists) continue;
         if(isBuy) PlaceBuyStop(price,  InpFixedLot, state.magicNumber);
         else      PlaceSellStop(price, InpFixedLot, state.magicNumber);
        }
     }

   // ---- OUTSIDE FILL (only if count < InpMinGridLevels) ----
   current = CountOrderType(orderType, state.magicNumber); // recount after inside fill
   if(current >= InpMinGridLevels) return;

   int    needed    = InpInitialGridLevels - current;
   double outermost = isBuy ? GetHighestBuyStop(state.magicNumber)
                            : GetLowestSellStop(state.magicNumber);
   if(outermost <= 0 || needed <= 0) return;

   double outsideStart = isBuy ?
      AlignToTick(_Symbol, outermost + InpGridSpacing) :
      AlignToTick(_Symbol, outermost - InpGridSpacing);

   for(int i = 0; i < needed; i++)
     {
      double price = isBuy ?
         AlignToTick(_Symbol, outsideStart + InpGridSpacing * i) :
         AlignToTick(_Symbol, outsideStart - InpGridSpacing * i);
      if(isBuy) PlaceBuyStop(price,  InpFixedLot, state.magicNumber);
      else      PlaceSellStop(price, InpFixedLot, state.magicNumber);
     }
}

// Called by coordinator after Style C SL cleanup complete
void CheckAndRefill(GridState &state)
{
   FillOneSide(ORDER_TYPE_BUY_STOP,  state);
   FillOneSide(ORDER_TYPE_SELL_STOP, state);
   state.c_RefillNeeded = false;
   LogDebug(StringFormat("[GridBuilder] Refill done. BUY=%d SELL=%d",
                         CountOrderType(ORDER_TYPE_BUY_STOP,  state.magicNumber),
                         CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber)));
}

//+------------------------------------------------------------------+
//| MASTER                                                           |
//+------------------------------------------------------------------+
void BuildGrid(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   switch(InpStrategyStyle)
     {
      case STYLE_A: BuildGrid_A(price, lotMode, state); break;
      case STYLE_B: BuildGrid_B(price, lotMode, state); break;
      case STYLE_C: BuildGrid_C(price, state);          break;
      default:      BuildGrid_A(price, lotMode, state); break;
     }
}

#endif

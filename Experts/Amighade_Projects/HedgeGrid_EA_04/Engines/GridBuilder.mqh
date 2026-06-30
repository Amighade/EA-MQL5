#ifndef GRID_BUILDER_MQH
#define GRID_BUILDER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "SizingEngine.mqh"

//+------------------------------------------------------------------+
//| GRID ORDER HELPERS — used by all styles                          |
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

// Count pending orders of a given type
int CountOrderType(ENUM_ORDER_TYPE orderType, int magicNumber)
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)     continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber)  continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
      count++;
     }
   return count;
}

// Nearest BUY STOP (lowest price = closest to market)
double GetNearestBuyStop(int magicNumber)
{
   double nearest = DBL_MAX;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p < nearest) nearest = p;
     }
   return (nearest == DBL_MAX) ? 0.0 : nearest;
}

// Nearest SELL STOP (highest price = closest to market)
double GetNearestSellStop(int magicNumber)
{
   double nearest = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p > nearest) nearest = p;
     }
   return nearest;
}

// Highest BUY STOP (furthest from market)
double GetHighestBuyStop(int magicNumber)
{
   double highest = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p > highest) highest = p;
     }
   return highest;
}

// Lowest SELL STOP (furthest from market)
double GetLowestSellStop(int magicNumber)
{
   double lowest = DBL_MAX;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double p = OrderGetDouble(ORDER_PRICE_OPEN);
      if(p < lowest) lowest = p;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
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
      double lot = GetLot(level, lotMode);
      PlaceOrderPair(bp, lot, sp, lot, state.magicNumber);
     }

   state.anchorBuy  = firstBuy;
   state.anchorSell = firstSell;
   state.gridPlaced = true;
   state.cycleActive= false;
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
   state.gridPlaced = true;
   state.cycleActive= false;
   LogGridBuilt(firstBuy, firstSell, lotMode==LOT_FULL?"FULL":"HALF");
}

//+------------------------------------------------------------------+
//| STYLE C — Persistent fixed lot grid (InpInitialGridLevels/side) |
//+------------------------------------------------------------------+
void BuildGrid_C(double price, GridState &state)
{
   double halfGap   = InpInitialGap / 2.0;
   double firstBuy  = AlignToTick(_Symbol, price + halfGap);
   double firstSell = AlignToTick(_Symbol, price - halfGap);

   for(int level = 1; level <= InpInitialGridLevels; level++)
     {
      double bp = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
      double sp = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
      PlaceOrderPair(bp, InpFixedLot, sp, InpFixedLot, state.magicNumber);
     }

   state.anchorBuy  = firstBuy;
   state.anchorSell = firstSell;
   state.gridPlaced = true;
   state.cycleActive= false;
   LogGridBuilt(firstBuy, firstSell, "STYLE_C");
}

//+------------------------------------------------------------------+
//| STYLE C — Refill both sides after SL hit                        |
//| Only triggers when a side drops below InpMinGridLevels           |
//| Fills inside gap first, then extends outside                     |
//| Skips silently on broker rejection                               |
//+------------------------------------------------------------------+
void FillOneSide(ENUM_ORDER_TYPE orderType, GridState &state)
{
   int    current = CountOrderType(orderType, state.magicNumber);
   int    needed  = InpInitialGridLevels - current;
   if(needed <= 0) return;

   bool   isBuy       = (orderType == ORDER_TYPE_BUY_STOP);
   double nearestBuy  = GetNearestBuyStop(state.magicNumber);
   double nearestSell = GetNearestSellStop(state.magicNumber);
   int    placed      = 0;

   // Inside fill boundary — maintain InpInitialGap between nearest pair
   double insideBoundary = isBuy ?
      AlignToTick(_Symbol, nearestSell + InpInitialGap) :
      AlignToTick(_Symbol, nearestBuy  - InpInitialGap);

   double outermost = isBuy ? GetHighestBuyStop(state.magicNumber)
                             : GetLowestSellStop(state.magicNumber);

   // Inside fill
   if(nearestBuy > 0 && nearestSell > 0)
     {
      double start = insideBoundary;
      double end   = isBuy ? AlignToTick(_Symbol, nearestBuy  - InpGridSpacing)
                           : AlignToTick(_Symbol, nearestSell + InpGridSpacing);

      for(double p = start;
          isBuy ? (p <= end) : (p >= end) && placed < needed;
          p = isBuy ? p + InpGridSpacing : p - InpGridSpacing)
        {
         double price = AlignToTick(_Symbol, p);
         // Skip if level already occupied
         bool exists = false;
         for(int i = 0; i < OrdersTotal() && !exists; i++)
           {
            ulong t = OrderGetTicket(i);
            if(!OrderSelect(t)) continue;
            if(OrderGetString(ORDER_SYMBOL) != _Symbol)    continue;
            if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
            if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
            if(NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), price)) exists = true;
           }
         if(exists) continue;

         ulong ticket = isBuy ? PlaceBuyStop(price,  InpFixedLot, state.magicNumber)
                              : PlaceSellStop(price, InpFixedLot, state.magicNumber);
         if(ticket > 0) placed++;
        }
     }

   // Outside fill
   if(placed < needed && outermost > 0)
     {
      double start = isBuy ? AlignToTick(_Symbol, outermost + InpGridSpacing)
                           : AlignToTick(_Symbol, outermost - InpGridSpacing);
      for(int i = 0; i < needed - placed; i++)
        {
         double price = isBuy ? AlignToTick(_Symbol, start + InpGridSpacing * i)
                              : AlignToTick(_Symbol, start - InpGridSpacing * i);
         ulong ticket = isBuy ? PlaceBuyStop(price,  InpFixedLot, state.magicNumber)
                              : PlaceSellStop(price, InpFixedLot, state.magicNumber);
         if(ticket > 0) placed++;
        }
     }

   LogDebug(StringFormat("[GridBuilder] %s refill: needed=%d placed=%d",
                         isBuy?"BUY":"SELL", needed, placed));
}

void CheckAndRefill(GridState &state)
{
   int buyCount  = CountOrderType(ORDER_TYPE_BUY_STOP,  state.magicNumber);
   int sellCount = CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber);

   if(buyCount >= InpMinGridLevels && sellCount >= InpMinGridLevels)
     { LogDebug(StringFormat("[GridBuilder] Refill not needed. BUY=%d SELL=%d", buyCount, sellCount));
       return; }

   LogDebug(StringFormat("[GridBuilder] Refill triggered. BUY=%d SELL=%d min=%d",
                         buyCount, sellCount, InpMinGridLevels));
   FillOneSide(ORDER_TYPE_BUY_STOP,  state);
   FillOneSide(ORDER_TYPE_SELL_STOP, state);
}

//+------------------------------------------------------------------+
//| MASTER — routes to correct style                                 |
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

//+------------------------------------------------------------------+
//| GridFiller_C.mqh                                                  |
//| Style C: Grid refill after SL hit                                |
//|                                                                  |
//| Fills both sides (inside gap + outside) up to InpInitialGridLevels|
//| Only triggered when a side drops below InpMinGridLevels          |
//| Skips silently on broker rejection — no blocking                 |
//+------------------------------------------------------------------+
#ifndef GRID_FILLER_C_MQH
#define GRID_FILLER_C_MQH

#include "../../Inputs.mqh"
#include "../../Models/GridState.mqh"
#include "../../Utils/TradeUtils.mqh"
#include "../../Utils/MathUtils.mqh"
#include "../../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Count pending orders of a given type for this EA                 |
//+------------------------------------------------------------------+
int CountOrderType(ENUM_ORDER_TYPE orderType, int magicNumber)
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
      count++;
     }
   return count;
}

//+------------------------------------------------------------------+
//| Get nearest BUY STOP price (lowest BUY STOP = closest to price) |
//+------------------------------------------------------------------+
double GetNearestBuyStop(int magicNumber)
{
   double nearest = DBL_MAX;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      if(price < nearest) nearest = price;
     }
   return (nearest == DBL_MAX) ? 0.0 : nearest;
}

//+------------------------------------------------------------------+
//| Get nearest SELL STOP price (highest SELL STOP = closest to price)|
//+------------------------------------------------------------------+
double GetNearestSellStop(int magicNumber)
{
   double nearest = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      if(price > nearest) nearest = price;
     }
   return nearest;
}

//+------------------------------------------------------------------+
//| Get highest BUY STOP price (furthest from price)                 |
//+------------------------------------------------------------------+
double GetHighestBuyStop(int magicNumber)
{
   double highest = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      if(price > highest) highest = price;
     }
   return highest;
}

//+------------------------------------------------------------------+
//| Get lowest SELL STOP price (furthest from price)                 |
//+------------------------------------------------------------------+
double GetLowestSellStop(int magicNumber)
{
   double lowest = DBL_MAX;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      if(price < lowest) lowest = price;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
}

//+------------------------------------------------------------------+
//| Fill BUY STOP side to target count                               |
//| Fills inside gap first, then extends outside                     |
//+------------------------------------------------------------------+
void FillBuySide(GridState &state)
{
   int    currentCount = CountOrderType(ORDER_TYPE_BUY_STOP, state.magicNumber);
   int    needed       = InpInitialGridLevels - currentCount;
   if(needed <= 0) return;

   double nearestBuy  = GetNearestBuyStop(state.magicNumber);
   double nearestSell = GetNearestSellStop(state.magicNumber);
   double highestBuy  = GetHighestBuyStop(state.magicNumber);

   // Minimum allowed buy price: InpInitialGap/2 above nearestSell
   // (to preserve gap between the two sides)
   double minBuyPrice = (nearestSell > 0) ?
                        nearestSell + InpInitialGap :
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) + InpInitialGap / 2.0;

   int placed = 0;

   // --- Inside fill: place orders between nearestSell+gap and nearestBuy
   if(nearestBuy > 0 && nearestSell > 0)
     {
      double insideStart = AlignToTick(_Symbol, minBuyPrice);
      double insideEnd   = AlignToTick(_Symbol, nearestBuy - InpGridSpacing);

      for(double p = insideStart; p <= insideEnd && placed < needed; p += InpGridSpacing)
        {
         double price = AlignToTick(_Symbol, p);
         // Skip if order already exists at this level
         bool exists = false;
         for(int i = 0; i < OrdersTotal(); i++)
           {
            ulong t = OrderGetTicket(i);
            if(!OrderSelect(t)) continue;
            if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
            if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
            if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
            if(NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), price)) { exists = true; break; }
           }
         if(exists) continue;

         ulong ticket = PlaceBuyStop(price, InpFixedLot, state.magicNumber);
         if(ticket > 0) placed++;
         // Skip silently on rejection — no retry
        }
     }

   // --- Outside fill: extend above highest existing BUY STOP
   if(placed < needed && highestBuy > 0)
     {
      double outsideStart = AlignToTick(_Symbol, highestBuy + InpGridSpacing);
      for(int i = 0; i < needed - placed; i++)
        {
         double price = AlignToTick(_Symbol, outsideStart + InpGridSpacing * i);
         ulong  ticket = PlaceBuyStop(price, InpFixedLot, state.magicNumber);
         if(ticket > 0) placed++;
        }
     }

   LogDebug(StringFormat("[GridFiller_C] BUY side filled: needed=%d placed=%d total=%d",
                         needed, placed, currentCount + placed));
}

//+------------------------------------------------------------------+
//| Fill SELL STOP side to target count                              |
//| Fills inside gap first, then extends outside                     |
//+------------------------------------------------------------------+
void FillSellSide(GridState &state)
{
   int    currentCount = CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber);
   int    needed       = InpInitialGridLevels - currentCount;
   if(needed <= 0) return;

   double nearestBuy  = GetNearestBuyStop(state.magicNumber);
   double nearestSell = GetNearestSellStop(state.magicNumber);
   double lowestSell  = GetLowestSellStop(state.magicNumber);

   // Maximum allowed sell price: InpInitialGap/2 below nearestBuy
   double maxSellPrice = (nearestBuy > 0) ?
                         nearestBuy - InpInitialGap :
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) - InpInitialGap / 2.0;

   int placed = 0;

   // --- Inside fill: place orders between nearestSell and maxSellPrice
   if(nearestBuy > 0 && nearestSell > 0)
     {
      double insideStart = AlignToTick(_Symbol, maxSellPrice);
      double insideEnd   = AlignToTick(_Symbol, nearestSell + InpGridSpacing);

      for(double p = insideStart; p >= insideEnd && placed < needed; p -= InpGridSpacing)
        {
         double price = AlignToTick(_Symbol, p);
         bool exists = false;
         for(int i = 0; i < OrdersTotal(); i++)
           {
            ulong t = OrderGetTicket(i);
            if(!OrderSelect(t)) continue;
            if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
            if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
            if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
            if(NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), price)) { exists = true; break; }
           }
         if(exists) continue;

         ulong ticket = PlaceSellStop(price, InpFixedLot, state.magicNumber);
         if(ticket > 0) placed++;
        }
     }

   // --- Outside fill: extend below lowest existing SELL STOP
   if(placed < needed && lowestSell > 0)
     {
      double outsideStart = AlignToTick(_Symbol, lowestSell - InpGridSpacing);
      for(int i = 0; i < needed - placed; i++)
        {
         double price = AlignToTick(_Symbol, outsideStart - InpGridSpacing * i);
         ulong  ticket = PlaceSellStop(price, InpFixedLot, state.magicNumber);
         if(ticket > 0) placed++;
        }
     }

   LogDebug(StringFormat("[GridFiller_C] SELL side filled: needed=%d placed=%d total=%d",
                         needed, placed, currentCount + placed));
}

//+------------------------------------------------------------------+
//| Master refill check — call after SL positions close              |
//| Only refills if either side dropped below InpMinGridLevels       |
//+------------------------------------------------------------------+
void CheckAndRefill(GridState &state)
{
   int buyCount  = CountOrderType(ORDER_TYPE_BUY_STOP,  state.magicNumber);
   int sellCount = CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber);

   bool buyNeedsRefill  = (buyCount  < InpMinGridLevels);
   bool sellNeedsRefill = (sellCount < InpMinGridLevels);

   if(!buyNeedsRefill && !sellNeedsRefill)
     {
      LogDebug(StringFormat("[GridFiller_C] No refill needed. BUY=%d SELL=%d",
                            buyCount, sellCount));
      return;
     }

   LogDebug(StringFormat("[GridFiller_C] Refill triggered. BUY=%d SELL=%d threshold=%d",
                         buyCount, sellCount, InpMinGridLevels));

   // Always refill BOTH sides when either side triggers
   FillBuySide(state);
   FillSellSide(state);
}

#endif

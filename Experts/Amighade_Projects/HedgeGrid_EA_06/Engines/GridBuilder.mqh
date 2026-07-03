//+------------------------------------------------------------------+
//| GridBuilder.mqh                                                   |
//| Unified grid construction — no more per-style Build functions.   |
//| Initial lot sizing comes from SizingUtils (InpInitialSizing).   |
//| Level count always InpInitialGridLevels for a fresh build.       |
//|                                                                    |
//| BRICK 4 (refill inside) / BRICK 5 (refill outside) live here too, |
//| gated independently by InpEnableRefillInside / InpEnableRefillOutside.|
//| Priority rule: inside refill always runs before outside refill.  |
//| Build/refill order: price-outward, in pairs (kept exactly as the |
//| original implementation already did this).                       |
//+------------------------------------------------------------------+
#ifndef GRID_BUILDER_MQH
#define GRID_BUILDER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/SizingUtils.mqh"

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
//| SHARED PLACEMENT HELPER — places a BUY/SELL pair, price-outward, |
//| candle-direction ordered (unchanged from original implementation)|
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
//| MASTER BUILD — one unified builder for every brick combination.  |
//| Lot sizing per level comes from SizingUtils (fixed or ladder).  |
//+------------------------------------------------------------------+
void BuildGrid(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);
   double firstBuy  = AlignToTick(_Symbol, price + halfGap);
   double firstSell = AlignToTick(_Symbol, price - halfGap);

   for(int level = 1; level <= maxLevels; level++)
     {
      double bp  = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
      double sp  = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
      double lot = GetLot(level, lotMode);
      PlaceOrderPair(bp, lot, sp, lot, state.magicNumber);
     }

   state.anchorBuy       = firstBuy;
   state.anchorSell      = firstSell;
   state.gridPlaced      = true;
   state.cycleActive     = false;
   state.currentBlockLot = GetLot(1, lotMode); // base lot reference for shifting/lot-increase
   state.farthestHitBuy  = 0.0;
   state.farthestHitSell = 0.0;

   LogGridBuilt(firstBuy, firstSell, lotMode==LOT_FULL?"FULL":"HALF");
}

//+------------------------------------------------------------------+
//| BRICK 4/5 — Fill one side of the grid (inside gap and/or         |
//| outside range), gated independently.                             |
//|                                                                    |
//| Inside gap (BRICK 4): ALWAYS fill regardless of current count,   |
//|   fills between nearest SELL STOP and nearest BUY STOP,          |
//|   maintains InpInitialGap between the nearest pair.               |
//|                                                                    |
//| Outside (BRICK 5): ONLY fill if count < InpMinGridLevels,        |
//|   extends beyond outermost order up to InpMaxGridLevels.          |
//|                                                                    |
//| Refill always uses InpFixedLot (independent of InpInitialSizing  |
//| and of Brick 1's lot-increase state — refill and lot-increase     |
//| should not be combined; that is the user's responsibility).      |
//| Skip silently on broker rejection.                                |
//+------------------------------------------------------------------+
void FillOneSide(ENUM_ORDER_TYPE orderType, GridState &state)
{
   bool   isBuy      = (orderType == ORDER_TYPE_BUY_STOP);
   double nearestBuy = GetNearestBuyStop(state.magicNumber);
   double nearestSell= GetNearestSellStop(state.magicNumber);

   // ---- INSIDE FILL (BRICK 4 — priority over outside fill) ----
   if(InpEnableRefillInside && nearestBuy > 0 && nearestSell > 0)
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

   // ---- OUTSIDE FILL (BRICK 5 — only if count < InpMinGridLevels) ----
   if(!InpEnableRefillOutside) return;

   int current = CountOrderType(orderType, state.magicNumber);
   if(current >= InpMinGridLevels) return;

   int    needed    = InpMaxGridLevels - current;
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

//+------------------------------------------------------------------+
//| Called by coordinator after cleanup completes (if refillNeeded)  |
//+------------------------------------------------------------------+
void CheckAndRefill(GridState &state)
{
   if(!InpEnableRefillInside && !InpEnableRefillOutside)
     {
      state.refillNeeded = false;
      return;
     }

   FillOneSide(ORDER_TYPE_BUY_STOP,  state);
   FillOneSide(ORDER_TYPE_SELL_STOP, state);
   state.refillNeeded = false;
   LogDebug(StringFormat("[GridBuilder] Refill done. BUY=%d SELL=%d",
                         CountOrderType(ORDER_TYPE_BUY_STOP,  state.magicNumber),
                         CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber)));
}

#endif

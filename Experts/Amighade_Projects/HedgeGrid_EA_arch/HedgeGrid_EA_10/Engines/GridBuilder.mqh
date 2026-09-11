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
#include "../Utils/LevelVisitUtils.mqh"

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

/*
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
}*/

double GetHighestBuyStop(int magicNumber, double &outLot)
{
   double highest = 0.0;
   outLot = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double p   = OrderGetDouble(ORDER_PRICE_OPEN);
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(p > highest)
        {
         highest = p;
         outLot = lot;
        }
     }
   return highest;
}

/*
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
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT)
      if(p < lowest) lowest = p;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
}*/

double GetLowestSellStop(int magicNumber, double &outLot)
{
   double lowest = DBL_MAX;
   outLot = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double p   = OrderGetDouble(ORDER_PRICE_OPEN);
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(p < lowest)
        {
         lowest = p;
         outLot = lot;
        }
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
void FillOneSideInside(ENUM_ORDER_TYPE orderType, GridState &state)
{
   bool   isBuy      = (orderType == ORDER_TYPE_BUY_STOP);
   double nearestBuy = GetNearestBuyStop(state.magicNumber);
   double nearestSell= GetNearestSellStop(state.magicNumber);
   if(nearestBuy <= 0 || nearestSell <= 0) return;

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
   double dummyLot;
   double outermost = isBuy ? GetHighestBuyStop(state.magicNumber, dummyLot)
                            : GetLowestSellStop(state.magicNumber, dummyLot);
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
//| BRICK 4 (REFILL_FOLLOW_PRICE style) — walk outward from current  |
//| price in both directions, one InpGridSpacing step at a time, up  |
//| to InpMaxGridLevels steps from center. At each level, fill any   |
//| pending order missing (a position sitting there does NOT count   |
//| as covered — only a live pending order does). Stop each          |
//| direction's walk the first time a level already has an order.   |
//| Called on every fill (see HedgeGrid.mq5), not just after cleanup.|
//+------------------------------------------------------------------+
void RefillFollowPriceInside(GridState &state)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    currentSell = CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber);
   int    currentBuy  = CountOrderType(ORDER_TYPE_BUY_STOP,  state.magicNumber);
   if(currentBuy + currentSell == 0) return;

   double nearestSell = GetNearestSellStop(state.magicNumber);
   double nearestBuy  = GetNearestBuyStop(state.magicNumber);

   if(nearestSell == 0)
     {
      // Backfill BUY side down to the near-price boundary, keeping existing spacing
      for(double level = nearestBuy - InpGridSpacing; level > (ask + InpInitialGap/2); level -= InpGridSpacing)
        {
         double lvl = AlignToTick(_Symbol, level);
         PlaceBuyStop(lvl, InpFixedLot, state.magicNumber);
        }

      // Rebuild SELL side from scratch — first level at InpInitialGap from bid, rest at InpGridSpacing
      double sellLevel = 0.0;
      nearestBuy  = GetNearestBuyStop(state.magicNumber);
      for(int step = 1; step <= InpMaxGridLevels; step++)
        {
         sellLevel = (step == 1) ? (nearestBuy - InpInitialGap) : (sellLevel - InpGridSpacing);
         double lvl = AlignToTick(_Symbol, sellLevel);
         PlaceSellStop(lvl, InpFixedLot, state.magicNumber);
        }
      return;
     }

   if(nearestBuy == 0)
     {
      // Backfill SELL side up to the near-price boundary, keeping existing spacing
      for(double level = nearestSell + InpGridSpacing; level < (bid - InpInitialGap/2); level += InpGridSpacing)
        {
         double lvl = AlignToTick(_Symbol, level);
         PlaceSellStop(lvl, InpFixedLot, state.magicNumber);
        }

      // Rebuild BUY side from scratch — first level at InpInitialGap from ask, rest at InpGridSpacing
      double buyLevel = 0.0;
      double nearestSell = GetNearestSellStop(state.magicNumber);
      for(int step = 1; step <= InpMaxGridLevels; step++)
        {
         buyLevel = (step == 1) ? (nearestSell + InpInitialGap) : (buyLevel + InpGridSpacing);
         double lvl = AlignToTick(_Symbol, buyLevel);
         PlaceBuyStop(lvl, InpFixedLot, state.magicNumber);
        }
      return;
     }

   // ---- Both sides already have orders — top up toward the cap if either has thinned ----
   // Fill SELL inside
   if((bid - nearestSell) > InpInitialGap/2 && nearestSell > 0)
      {
      for(double level = nearestSell + InpGridSpacing; level < (bid - InpInitialGap/2); level += InpGridSpacing)
        {
         double lvl = AlignToTick(_Symbol, level);
         PlaceSellStop(lvl, InpFixedLot, state.magicNumber);
        }
      }

   // Fill Buy inside
   if((nearestBuy - ask) > InpInitialGap/2 && nearestBuy > 0)
      {
      for(double level = nearestBuy - InpGridSpacing; level > (ask + InpInitialGap/2); level -= InpGridSpacing)
        {
         double lvl = AlignToTick(_Symbol, level);
         PlaceBuyStop(lvl, InpFixedLot, state.magicNumber);
        }
      }
}

void RefillOutside(GridState &state)
{
   if(!InpEnableRefillOutside) return;
   
   int    currentSell = CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber);
   int    currentBuy  = CountOrderType(ORDER_TYPE_BUY_STOP,  state.magicNumber);
   if(currentBuy + currentSell == 0) return;

   int    currentSellOut   = CountOrderType(ORDER_TYPE_SELL_STOP, state.magicNumber);
   double outermostLot = 0.0;
   double outermostSellOut = GetLowestSellStop(state.magicNumber, outermostLot);
   if(currentSellOut < InpMinGridLevels && outermostSellOut > 0)
     {
      if(outermostLot <= 0) outermostLot = InpFixedLot;   // fallback, shouldn't normally hit
      int needed = InpMaxGridLevels - currentSellOut;
      for(int step = 1; step <= needed; step++)
        {
         double level = AlignToTick(_Symbol, outermostSellOut - InpGridSpacing * step);
         PlaceSellStop(level, outermostLot, state.magicNumber);
        }
     }

   int    currentBuyOut   = CountOrderType(ORDER_TYPE_BUY_STOP, state.magicNumber);
   double outermostBuyOut = GetHighestBuyStop(state.magicNumber, outermostLot);
   if(currentBuyOut < InpMinGridLevels && outermostBuyOut > 0)
     {
      if(outermostLot <= 0) outermostLot = InpFixedLot;   // fallback, shouldn't normally hit
      int needed = InpMaxGridLevels - currentBuyOut;
      for(int step = 1; step <= needed; step++)
        {
         double level = AlignToTick(_Symbol, outermostBuyOut + InpGridSpacing * step);
         PlaceBuyStop(level, outermostLot, state.magicNumber);
        }
     }
}

//+------------------------------------------------------------------+
//| BRICK 7 — place an opposite pending stop at the exact price of   |
//| the level that just filled, sized via level-increment. This is   |
//| what makes a Sell able to "revisit" a level a Buy filled at:     |
//| the pending order didn't exist until this fill created it.       |
//| Skips if an opposite order already sits at that price.            |
//+------------------------------------------------------------------+
void PlaceRevisitOrder(GridState &state)
{
   if(!InpEnableRevisitRefill) return;
   if(state.prevHitPrice <= 0.0) return;   // no predecessor yet — first fill of the cycle

   double level = AlignToTick(_Symbol, state.prevHitPrice);
   ENUM_ORDER_TYPE oppositeType = (state.prevHitDirection == ORDER_TYPE_BUY) ?
                                   ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;

   bool exists = false;
   for(int i = 0; i < OrdersTotal() && !exists; i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)             continue;
      if(OrderGetInteger(ORDER_MAGIC)  != state.magicNumber)   continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != oppositeType) continue;
      if(NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), level)) exists = true;
     }
   if(exists) return;

   double lot = GetLevelIncrementLot(state, level, InpFixedLot);

   if(oppositeType == ORDER_TYPE_SELL_STOP)
      PlaceSellStop(level, lot, state.magicNumber);
   else
      PlaceBuyStop(level, lot, state.magicNumber);
}

void ProcessInsideRefill(GridState &state)
{
   if(!InpEnableRefillInside) return;

   switch(InpInsideRefillStyle)
     {
      case INSIDE_THRESHOLD:
         FillOneSideInside(ORDER_TYPE_BUY_STOP,  state);
         FillOneSideInside(ORDER_TYPE_SELL_STOP, state);
         break;
      case INSIDE_FOLLOW_PRICE:
         RefillFollowPriceInside(state);
         break;
      case INSIDE_REVISIT:
         PlaceRevisitOrder(state);
         break;
      case INSIDE_PASS_REFILL:
         ProcessPassRefill(state, state.lastHitPrice,
                            state.lastHitDirection == ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
         break;
     }
}

void ProcessPassRefill(GridState &state, double fillPrice, ENUM_POSITION_TYPE filledSide)
{
   int side = (filledSide == POSITION_TYPE_BUY) ? 1 : 2;

   if(state.runSide == 0 || side == state.runSide)
     {
      state.runSide = side;
      int n = ArraySize(state.runLevels);
      ArrayResize(state.runLevels, n + 1);
      state.runLevels[n] = fillPrice;
      return;
     }

   state.passCounter++;

   ENUM_ORDER_TYPE refillType = (state.runSide == 1) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;

   for(int i = 0; i < ArraySize(state.runLevels); i++)
     {
      double level = AlignToTick(_Symbol, state.runLevels[i]);

      bool exists = false;
      for(int j = 0; j < OrdersTotal() && !exists; j++)
        {
         ulong t = OrderGetTicket(j);
         if(!OrderSelect(t)) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)           continue;
         if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
         if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != refillType) continue;
         if(NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), level)) exists = true;
        }
      if(exists) continue;

      double lot = GetPassRefillLot(state, level);

      if(refillType == ORDER_TYPE_BUY_STOP)
         PlaceBuyStop(level, lot, state.magicNumber);
      else
         PlaceSellStop(level, lot, state.magicNumber);
     }

   state.runSide = side;
   ArrayResize(state.runLevels, 1);
   state.runLevels[0] = fillPrice;
}

//+------------------------------------------------------------------+
//| Reset Grid engine state                                         |
//+------------------------------------------------------------------+
void ResetGridBuilder(GridState &state)
{
   state.anchorBuy       = 0.0;
   state.anchorSell      = 0.0;
   state.gridPlaced      = false;
   state.cycleActive     = false;
   state.currentBlockLot = 0.0;
   state.farthestHitBuy  = 0.0;
   state.farthestHitSell = 0.0;
}

#endif
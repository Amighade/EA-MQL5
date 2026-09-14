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

struct OutsideRefillSnapshot
{
   int    sellOrderCount;
   int    buyOrderCount;
   double lowestSellOrderPrice;
   double lowestSellOrderLot;
   double highestBuyOrderPrice;
   double highestBuyOrderLot;
   
   int    sellpositionCount;
   int    buypositionCount;
   int    positionCount;
   double lowestSellPositionPrice;
   double lowestSellPositionLot;
   double highestBuyPositionPrice;
   double highestBuyPositionLot;
};

void BuildOutsideRefillSnapshot(int magicNumber, OutsideRefillSnapshot &snap)
{
   snap.sellOrderCount          = 0;
   snap.buyOrderCount           = 0;
   snap.lowestSellOrderPrice    = DBL_MAX;
   snap.lowestSellOrderLot      = 0.0;
   snap.highestBuyOrderPrice    = 0.0;
   snap.highestBuyOrderLot      = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)     continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber)  continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double p   = OrderGetDouble(ORDER_PRICE_OPEN);
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);

      if(type == ORDER_TYPE_SELL_STOP)
        {
         snap.sellOrderCount++;
         if(p < snap.lowestSellOrderPrice)
           {
            snap.lowestSellOrderPrice = p;
            snap.lowestSellOrderLot   = lot;
           }
        }
      else if(type == ORDER_TYPE_BUY_STOP)
        {
         snap.buyOrderCount++;
         if(p > snap.highestBuyOrderPrice)
           {
            snap.highestBuyOrderPrice = p;
            snap.highestBuyOrderLot   = lot;
           }
        }
     }
   if(snap.lowestSellOrderPrice == DBL_MAX) snap.lowestSellOrderPrice = 0.0;

   snap.sellpositionCount          = 0;
   snap.buypositionCount           = 0;
   snap.positionCount             = 0;
   snap.lowestSellPositionPrice   = DBL_MAX;
   snap.lowestSellPositionLot     = 0.0;
   snap.highestBuyPositionPrice   = 0.0;
   snap.highestBuyPositionLot     = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;

      snap.positionCount++;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double p   = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      
      if(type == POSITION_TYPE_SELL)
        {
         snap.sellpositionCount++;
         if(p < snap.lowestSellPositionPrice)
           {
            snap.lowestSellPositionPrice = p;
            snap.lowestSellPositionLot   = lot;
           }
        }
      else if(type == POSITION_TYPE_BUY)
        {
         snap.buypositionCount++;
         if(p > snap.highestBuyPositionPrice)
           {
            snap.highestBuyPositionPrice = p;
            snap.highestBuyPositionLot   = lot;
           }
        }
     }
   if(snap.lowestSellPositionPrice == DBL_MAX) snap.lowestSellPositionPrice = 0.0;
}

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

int CountPositionType(ENUM_POSITION_TYPE posType, int magicNumber)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != posType)     continue;
      count++;
     }
   return count;
}

double GetLowestSellPosition(int magicNumber, double &outLot)
{
   double lowest = DBL_MAX;
   outLot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)          continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber)      continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_SELL) continue;
      double p   = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      if(p < lowest)
        {
         lowest = p;
         outLot = lot;
        }
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
}

double GetHighestBuyPosition(int magicNumber, double &outLot)
{
   double highest = 0.0;
   outLot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber)     continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;
      double p   = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      if(p > highest)
        {
         highest = p;
         outLot = lot;
        }
     }
   return highest;
}
//+------------------------------------------------------------------+
//| SHARED PLACEMENT HELPER — places a BUY/SELL pair, price-outward, |
//| candle-direction ordered (unchanged from original implementation)|
//+------------------------------------------------------------------+
void PlaceOrderPair(double buyPrice, double buyLot,
                    double sellPrice, double sellLot, int magicNumber, double buySl, double sellSl)
{
   if(IsBullishCandle())
     { PlaceSellStop(sellPrice, sellLot, magicNumber, sellSl);
       PlaceBuyStop(buyPrice,   buyLot,  magicNumber, buySl); }
   else
     { PlaceBuyStop(buyPrice,   buyLot,  magicNumber, buySl);
       PlaceSellStop(sellPrice, sellLot, magicNumber, sellSl); }
}

//+------------------------------------------------------------------+
//| MASTER BUILD — one unified builder for every brick combination.  |
//| Lot sizing per level comes from SizingUtils (fixed or ladder).  |
//+------------------------------------------------------------------+
void BuildGrid(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double firstBuy, firstSell;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread  = ask - bid;
   double minStop = MinStopDistancePrice(_Symbol);

   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE)
     {
      ENUM_TIMEFRAMES tf = (Timeframe == 0) ? (ENUM_TIMEFRAMES)Period() : Timeframe;
      firstBuy  = AlignToTick(_Symbol, iHigh(_Symbol, tf, 1));
      firstSell = AlignToTick(_Symbol, iLow(_Symbol, tf, 1));
     }
   else
     {
      double halfGap = InpInitialGap / 2.0;
      firstBuy  = AlignToTick(_Symbol, price + halfGap);
      firstSell = AlignToTick(_Symbol, price - halfGap);
     }

   // range means "prev-bar high-low" only in ANCHOR_PREV_BAR_RANGE mode.
   // In ANCHOR_CURRENT_PRICE mode, firstBuy - firstSell is just InpInitialGap,
   // not a volatility measure — FIRST_SL_RANGE_FRAC falls back to 0 (no SL)
   // there rather than silently using a meaningless number.
   double range = 0.0;
   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE)
      range = firstBuy - firstSell;
   else if(InpFirstLevelSLMode == FIRST_SL_RANGE_FRAC)
      LogDebug("[BuildGrid] FIRST_SL_RANGE_FRAC has no meaningful range in ANCHOR_CURRENT_PRICE mode — SL skipped.");

   double slDist = GetFirstLevelSLDistance(range, spread, minStop);

   int maxLevels = GetMaxLevels(lotMode);
   for(int level = 1; level <= maxLevels; level++)
     {
      double bp  = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
      double sp  = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
      double lot = GetLot(level, lotMode);

      double bsl = (level == 1 && slDist > 0) ? AlignToTick(_Symbol, bp - slDist) : 0;
      double ssl = (level == 1 && slDist > 0) ? AlignToTick(_Symbol, sp + slDist) : 0;

      PlaceOrderPair(bp, lot, sp, lot, state.magicNumber, bsl, ssl);
     }

   state.anchorBuy       = firstBuy;
   state.anchorSell      = firstSell;
   state.gridPlaced      = true;
   state.cycleActive     = false;
   state.currentBlockLot = GetLot(1, lotMode);
   state.farthestHitBuy  = 0.0;
   state.farthestHitSell = 0.0;
   LogGridBuilt(firstBuy, firstSell, lotMode==LOT_FULL?"FULL":"HALF");
   state.gridPlaced             = true;
   state.needsGridVerification  = true;   // verified on next OnTick
}


/*
void BuildGrid(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double firstBuy, firstSell;
      
   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double spread  = ask - bid;
      double minStop = MinStopDistancePrice(_Symbol);
      ENUM_TIMEFRAMES tf = (Timeframe == 0) ? (ENUM_TIMEFRAMES)Period() : Timeframe;
      firstBuy  = AlignToTick(_Symbol, iHigh(_Symbol, tf, 1));
      firstSell = AlignToTick(_Symbol, iLow(_Symbol, tf, 1));
      int maxLevels = GetMaxLevels(lotMode);
      for(int level = 1; level <= maxLevels; level++)
        {
         double bp  = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
         double sp  = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
         double lot = GetLot(level, lotMode);
         double ssl = (level == 1) ? sp + (spread + minStop) : 0;
         double bsl = (level == 1) ? bp - (spread + minStop) : 0;
         //double ssl = (level == 1) ? bp + (spread + minStop) : 0;
         //double bsl = (level == 1) ? sp - (spread + minStop) : 0;
         PlaceOrderPair(bp, lot, sp, lot, state.magicNumber, bsl, ssl);
        }
     }
   else
     {
      double halfGap = InpInitialGap / 2.0;
      firstBuy  = AlignToTick(_Symbol, price + halfGap);
      firstSell = AlignToTick(_Symbol, price - halfGap);
      int maxLevels = GetMaxLevels(lotMode);
      for(int level = 1; level <= maxLevels; level++)
        {
         double bp  = AlignToTick(_Symbol, firstBuy  + InpGridSpacing * (level-1));
         double sp  = AlignToTick(_Symbol, firstSell - InpGridSpacing * (level-1));
         double lot = GetLot(level, lotMode);
         double ssl = 0;
         double bsl = 0;
         PlaceOrderPair(bp, lot, sp, lot, state.magicNumber, bsl, ssl);
        }
     }

   state.anchorBuy       = firstBuy;
   state.anchorSell      = firstSell;
   state.gridPlaced      = true;
   state.cycleActive     = false;
   state.currentBlockLot = GetLot(1, lotMode);
   state.farthestHitBuy  = 0.0;
   state.farthestHitSell = 0.0;

   LogGridBuilt(firstBuy, firstSell, lotMode==LOT_FULL?"FULL":"HALF");
}*/

//+------------------------------------------------------------------+
//| Computes the first-level SL distance from a given entry price,   |
//| per InpFirstLevelSLMode. 'entry' is bp for the buy side, sp for   |
//| the sell side — each side's SL is always relative to its OWN     |
//| entry, never to current bid/ask or to the other side's entry.    |
//| Returns 0.0 for FIRST_SL_NONE, meaning "no SL."                   |
//+------------------------------------------------------------------+
double GetFirstLevelSLDistance(double range, double spread, double minStop)
{
   switch(InpFirstLevelSLMode)
     {
      case FIRST_SL_TIGHT:        return spread + minStop;
      case FIRST_SL_GRID_SPACING: return InpGridSpacing * InpFirstSLRangeFraction;
      case FIRST_SL_GAP_FRAC:     return InpInitialGap * InpFirstSLRangeFraction;
      case FIRST_SL_RANGE_FRAC:   return range * InpFirstSLRangeFraction;
      default:                    return 0.0;   // FIRST_SL_NONE
     }
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
   if(InpOutsideRefillStyle == OUTSIDE_NONE) return;

   OutsideRefillSnapshot snap;
   BuildOutsideRefillSnapshot(state.magicNumber, snap);

   //Print(__FILE__, " Line: ", __LINE__, " sellOrderCount=", snap.sellOrderCount, " buyOrderCount=", snap.buyOrderCount);

   if(snap.sellOrderCount + snap.buyOrderCount == 0 && snap.positionCount == 0) return;

   // ---- SELL side ----
   if(snap.sellOrderCount < InpMinGridLevels)
     {
      double anchor = snap.lowestSellOrderPrice;
      double anchorLot = snap.lowestSellOrderLot;
      if(anchor <= 0)
        {
         anchor    = snap.lowestSellPositionPrice;
         anchorLot = snap.lowestSellPositionLot;
        }
      if(anchor > 0)
        /*{
         int needed = InpMaxGridLevels - snap.sellOrderCount;
         for(int step = 1; step <= needed; step++)
           {
            int    level = snap.sellOrderCount + snap.sellpositionCount + step;
            //Print (__FILE__,__LINE__," level: ", level);
            double lot   = GetOutsideRefillLot(level, state.lotMode, anchorLot);
            //Print (__FILE__,__LINE__," lot: ", lot);
            lot = MathMax(lot, snap.lowestSellOrderLot);
            //Print (__FILE__,__LINE__," lot: ", lot);
            double price = AlignToTick(_Symbol, anchor - InpGridSpacing * step);
            PlaceSellStop(price, lot, state.magicNumber);
           }
        }*/
         {
         // Logic Fix: Place exactly ONE outer order per transaction pulse event
         int    level = snap.sellOrderCount + snap.sellpositionCount + 1;
         double lot   = GetOutsideRefillLot(level, state.lotMode, anchorLot);
         lot = MathMax(lot, snap.lowestSellOrderLot);
         
         double price = AlignToTick(_Symbol, anchor - InpGridSpacing);
         PlaceSellStop(price, lot, state.magicNumber);
         return; // Exit immediately, let the next trade transaction pulse handle the next level
        }
     }

   // ---- BUY side ----
   if(snap.buyOrderCount < InpMinGridLevels)
     {
      double anchor = snap.highestBuyOrderPrice;
      double anchorLot = snap.highestBuyOrderLot;
      if(anchor <= 0)
        {
         anchor    = snap.highestBuyPositionPrice;
         anchorLot = snap.highestBuyPositionLot;
        }
      if(anchor > 0)
        /*{
         int needed = InpMaxGridLevels - snap.buyOrderCount;
         for(int step = 1; step <= needed; step++)
           {
            int    level = snap.buyOrderCount + snap.buypositionCount + step;
            //Print (__FILE__,__LINE__," level: ", level);
            double lot   = GetOutsideRefillLot(level, state.lotMode, anchorLot);
            //Print (__FILE__,__LINE__," lot: ", lot);
            lot = MathMax(lot, snap.highestBuyOrderLot);
            //Print (__FILE__,__LINE__," lot: ", lot);
            double price = AlignToTick(_Symbol, anchor + InpGridSpacing * step);
            PlaceBuyStop(price, lot, state.magicNumber);
           }
        }*/
         {
         // Logic Fix: Place exactly ONE outer order per transaction pulse event
         int    level = snap.buyOrderCount + snap.buypositionCount + 1;
         double lot   = GetOutsideRefillLot(level, state.lotMode, anchorLot);
         lot = MathMax(lot, snap.highestBuyOrderLot);
         
         double price = AlignToTick(_Symbol, anchor + InpGridSpacing);
         PlaceBuyStop(price, lot, state.magicNumber);
         return; // Exit immediately
        }
     }
}

double GetOutsideRefillLot(int level, ENUM_LOT_MODE lotMode, double anchorLot)
{
   switch(InpOutsideRefillStyle)
     {
      case OUTSIDE_FIXED:    return InpFixedLot;
      case OUTSIDE_LAST_LOT: return (anchorLot > 0) ? anchorLot : InpFixedLot;
      case OUTSIDE_LADDER:   return GetLot_Ladder(level, lotMode);
      case OUTSIDE_EXP:      return GetLot_EXP(level, lotMode);
      default:               return InpFixedLot;
     }
}
//+------------------------------------------------------------------+
//| BRICK 7 — place an opposite pending stop at the exact price of   |
//| the level that just filled, sized via level-increment. This is   |
//| what makes a Sell able to "revisit" a level a Buy filled at:     |
//| the pending order didn't exist until this fill created it.       |
//| Skips if an opposite order already sits at that price.           |
//+------------------------------------------------------------------+
void PlaceRevisitOrder(GridState &state)
{
   if(state.prevHitPrice <= 0.0) return;   // no predecessor yet — first fill of the cycle

   double level = AlignToTick(_Symbol, state.prevHitPrice);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopsBuffer = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   ENUM_ORDER_TYPE oppositeType;
   if(level < bid - stopsBuffer)
      oppositeType = ORDER_TYPE_SELL_STOP;
   else if(level > ask + stopsBuffer)
      oppositeType = ORDER_TYPE_BUY_STOP;
   else
      return;   // too close to current price for a valid stop

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

void ProcessInsideMaintenance(GridState &state)
{
   switch(InpInsideMaintenanceStyle)
     {
      case MAINTENANCE_THRESHOLD:
         FillOneSideInside(ORDER_TYPE_BUY_STOP,  state);
         FillOneSideInside(ORDER_TYPE_SELL_STOP, state);
         break;
      case MAINTENANCE_FOLLOW_PRICE:
         RefillFollowPriceInside(state);
         break;
      default:
         break;   // MAINTENANCE_NONE
     }
}

void ProcessInsideStrategy(GridState &state)
{
   switch(InpInsideStrategyStyle)
     {
      case STRATEGY_REVISIT:
         PlaceRevisitOrder(state);
         break;
      case STRATEGY_PASS_REFILL:
         ProcessPassRefill(state, state.lastHitPrice,
                            state.lastHitDirection == ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
         break;
      default:
         break;   // STRATEGY_NONE
     }
}
//+------------------------------------------------------------------+
//| Checked once, on the tick immediately after a fresh grid build.  |
//| Confirms every expected level has a pending order within one     |
//| InpGridSpacing of its correct price. Any order missing entirely, |
//| or drifted by a full InpGridSpacing or more (widening artifact), |
//| fails the whole grid — no per-order repair, reset only.          |
//+------------------------------------------------------------------+
bool VerifyFreshGrid(GridState &state, ENUM_LOT_MODE lotMode)
{
   int maxLevels = GetMaxLevels(lotMode);

   for(int level = 1; level <= maxLevels; level++)
     {
      double expectedBuy  = AlignToTick(_Symbol, state.anchorBuy  + InpGridSpacing * (level-1));
      double expectedSell = AlignToTick(_Symbol, state.anchorSell - InpGridSpacing * (level-1));

      bool buyFound = false, sellFound = false;

      for(int i = 0; i < OrdersTotal(); i++)
        {
         ulong t = OrderGetTicket(i);
         if(!OrderSelect(t)) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)           continue;
         if(OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;

         ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         double price = OrderGetDouble(ORDER_PRICE_OPEN);

         if(type == ORDER_TYPE_BUY_STOP && MathAbs(price - expectedBuy) < InpGridSpacing)
            buyFound = true;
         else if(type == ORDER_TYPE_SELL_STOP && MathAbs(price - expectedSell) < InpGridSpacing)
            sellFound = true;
        }

      if(!buyFound || !sellFound)
        {
         LogDebug(StringFormat("[VerifyFreshGrid] Level %d failed: buyFound=%s sellFound=%s (expected buy=%.5f sell=%.5f)",
                               level, buyFound?"YES":"NO", sellFound?"YES":"NO", expectedBuy, expectedSell));
         return false;
        }
     }
   return true;
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
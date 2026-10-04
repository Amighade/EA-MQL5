#ifndef STRATEGY_GRID_MQH
#define STRATEGY_GRID_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/TradeBook.mqh"
#include "../Utils/SessionFilter.mqh"

// Strategy requests describe desired state. ProcessPendingActions() is the
// only code that sends them; reconciliation confirms the resulting live state.
double StrategyAlignPrice(double price)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   return NormalizeDouble(MathRound(price / tick) * tick, _Digits);
  }

double StrategyAlignVolume(double volume)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0.0) volume = MathCeil(volume / step - 1.0e-9) * step;
   return MathMax(minv, MathMin(maxv, volume));
  }

double StrategyInitialLot(int level)
  {
   double lot = InpFixedLot;
   if(InpInitialSizing == SIZING_LADDER)
      lot = MathMin(InpInitialLotCap, InpFixedLot + InpInitialLotStep * (level - 1));
   else if(InpInitialSizing == SIZING_EXP)
      lot = MathMin(InpInitialLotCap, InpFixedLot + InpInitialLotStep * MathPow(level - 1, 1.5));
   return StrategyAlignVolume(lot);
  }

bool StrategyIsBuyOrder(ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT ||
           type == ORDER_TYPE_BUY_STOP_LIMIT);
  }

bool StrategyPlanExists(GridState &state, ENUM_ORDER_TYPE type, double price)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_ORDER || item.orderType != type) continue;
      if(MathAbs(item.targetPrice - price) <= tick * 0.5) return true;
     }
   return false;
  }

uint StrategyQueuePending(GridState &state, ENUM_ORDER_TYPE type,
                          double price, double lot, double sl=0.0, int level=-1)
  {
   price = StrategyAlignPrice(price);
   if(sl > 0.0) sl = StrategyAlignPrice(sl);
   lot = StrategyAlignVolume(lot);
   return RequestPlacePending(state, type, price, lot, sl, 0.0, level);
  }

double StrategyFirstLevelSLDistance(double range, double spread, double minStop)
  {
   switch(InpFirstLevelSLMode)
     {
      case FIRST_SL_TIGHT:        return spread + minStop;
      case FIRST_SL_GRID_SPACING: return InpGridSpacing * InpFirstSLRangeFraction;
      case FIRST_SL_GAP_FRAC:     return InpInitialGap * InpFirstSLRangeFraction;
      case FIRST_SL_RANGE_FRAC:   return range * InpFirstSLRangeFraction;
      default:                    return 0.0;
     }
  }

void StrategyQueueGridPair(GridState &state, int level, double buyPrice,
                           double sellPrice, double lot, double buySL, double sellSL)
  {
   ENUM_TIMEFRAMES tf = (Timeframe == 0) ? (ENUM_TIMEFRAMES)Period() : Timeframe;
   bool bullish = (iClose(_Symbol, tf, 1) > iOpen(_Symbol, tf, 1));

   // Actions are sent in reverse item order, so append the pair backwards.
   if(bullish)
     {
      StrategyQueuePending(state, ORDER_TYPE_BUY_STOP, buyPrice, lot, buySL, level);
      StrategyQueuePending(state, ORDER_TYPE_SELL_STOP, sellPrice, lot, sellSL, level);
     }
   else
     {
      StrategyQueuePending(state, ORDER_TYPE_SELL_STOP, sellPrice, lot, sellSL, level);
      StrategyQueuePending(state, ORDER_TYPE_BUY_STOP, buyPrice, lot, buySL, level);
     }
  }

void StrategyBuildGrid(GridState &state)
  {
   if(state.lifecycle != GRID_IDLE || !state.sessionAllowed ||
      state.safetyStopPending || state.mode != MODE_RUNNING) return;

   MqlTick tick = {};
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0) return;

   double firstBuy = tick.bid + InpInitialGap * 0.5;
   double firstSell = tick.bid - InpInitialGap * 0.5;
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double spread = tick.ask - tick.bid;
   double range = 0.0;

   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE)
     {
      ENUM_TIMEFRAMES tf = (Timeframe == 0) ? (ENUM_TIMEFRAMES)Period() : Timeframe;
      double high = iHigh(_Symbol, tf, 1);
      double low = iLow(_Symbol, tf, 1);
      if(high <= low || tick.bid < low || tick.ask > high ||
         high - tick.ask < minStop || tick.bid - low < minStop) return;
      firstBuy = high;
      firstSell = low;
      range = high - low;
     }

   if(state.marginWarning && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
      return;

   firstBuy = StrategyAlignPrice(firstBuy);
   firstSell = StrategyAlignPrice(firstSell);
   double slDistance = StrategyFirstLevelSLDistance(range, spread, minStop);
   state.anchorBuy = firstBuy;
   state.anchorSell = firstSell;
   state.currentBlockLot = StrategyInitialLot(1);
   state.farthestHitBuy = 0.0;
   state.farthestHitSell = 0.0;

   // Append outer levels first. The action processor walks backwards, placing
   // the nearest pair first and moving outward as in Rev22.2.
   for(int level = InpInitialGridLevels; level >= 1; level--)
     {
      double buy = firstBuy + InpGridSpacing * (level - 1);
      double sell = firstSell - InpGridSpacing * (level - 1);
      double lot = StrategyInitialLot(level);
      double buySL = (level == 1 && slDistance > 0.0) ? firstBuy - slDistance : 0.0;
      double sellSL = (level == 1 && slDistance > 0.0) ? firstSell + slDistance : 0.0;
      StrategyQueueGridPair(state, level, buy, sell, lot, buySL, sellSL);
     }

   if(state.lifecycle == GRID_BUILDING)
     {
      state.needsGridVerification = true;
      if(InpEnableDebugLog)
         PrintFormat("[REV31.00] Grid planned: buy=%.5f sell=%.5f levels=%d.",
                     firstBuy, firstSell, InpInitialGridLevels);
     }
  }

double StrategyNearestBuy(GridState &state)
  {
   double price = 0.0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_ORDER || !StrategyIsBuyOrder(item.orderType) || item.action == ACTION_DELETE) continue;
      double p = item.brokerPresent ? item.openPrice : item.targetPrice;
      if(p > 0.0 && (price == 0.0 || p < price)) price = p;
     }
   return price;
  }

double StrategyNearestSell(GridState &state)
  {
   double price = 0.0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_ORDER || item.orderType != ORDER_TYPE_SELL_STOP || item.action == ACTION_DELETE) continue;
      double p = item.brokerPresent ? item.openPrice : item.targetPrice;
      if(p > 0.0 && (price == 0.0 || p > price)) price = p;
     }
   return price;
  }

void StrategyFillOneSideInside(GridState &state, ENUM_ORDER_TYPE type)
  {
   bool buySide = (type == ORDER_TYPE_BUY_STOP);
   double nearestBuy = StrategyNearestBuy(state);
   double nearestSell = StrategyNearestSell(state);
   if(nearestBuy <= 0.0 || nearestSell <= 0.0) return;

   double start = buySide ? nearestSell + InpInitialGap : nearestBuy - InpInitialGap;
   double end = buySide ? nearestBuy - InpGridSpacing : nearestSell + InpGridSpacing;
   double step = buySide ? InpGridSpacing : -InpGridSpacing;
   for(double p = start; buySide ? p <= end : p >= end; p += step)
     {
      double price = StrategyAlignPrice(p);
      if(StrategyPlanExists(state, type, price)) continue;
      StrategyQueuePending(state, type, price, InpFixedLot);
     }
  }

void StrategyRefillFollowPrice(GridState &state)
  {
   MqlTick tick = {};
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double nearestBuy = StrategyNearestBuy(state);
   double nearestSell = StrategyNearestSell(state);
   if(nearestBuy <= 0.0 && nearestSell <= 0.0) return;

   if(nearestSell <= 0.0)
     {
      for(double p = nearestBuy - InpGridSpacing; p > tick.ask + InpInitialGap * 0.5; p -= InpGridSpacing)
         if(!StrategyPlanExists(state, ORDER_TYPE_BUY_STOP, StrategyAlignPrice(p)))
            StrategyQueuePending(state, ORDER_TYPE_BUY_STOP, p, InpFixedLot);
      nearestBuy = StrategyNearestBuy(state);
      for(int n = 1; n <= InpMaxGridLevels; n++)
        {
         double p = nearestBuy - InpInitialGap - InpGridSpacing * (n - 1);
         StrategyQueuePending(state, ORDER_TYPE_SELL_STOP, p, InpFixedLot);
        }
      return;
     }

   if(nearestBuy <= 0.0)
     {
      for(double p = nearestSell + InpGridSpacing; p < tick.bid - InpInitialGap * 0.5; p += InpGridSpacing)
         if(!StrategyPlanExists(state, ORDER_TYPE_SELL_STOP, StrategyAlignPrice(p)))
            StrategyQueuePending(state, ORDER_TYPE_SELL_STOP, p, InpFixedLot);
      nearestSell = StrategyNearestSell(state);
      for(int n = 1; n <= InpMaxGridLevels; n++)
        {
         double p = nearestSell + InpInitialGap + InpGridSpacing * (n - 1);
         StrategyQueuePending(state, ORDER_TYPE_BUY_STOP, p, InpFixedLot);
        }
      return;
     }

   if(tick.bid - nearestSell > InpInitialGap * 0.5)
      for(double p = nearestSell + InpGridSpacing; p < tick.bid - InpInitialGap * 0.5; p += InpGridSpacing)
         if(!StrategyPlanExists(state, ORDER_TYPE_SELL_STOP, StrategyAlignPrice(p)))
            StrategyQueuePending(state, ORDER_TYPE_SELL_STOP, p, InpFixedLot);
   if(nearestBuy - tick.ask > InpInitialGap * 0.5)
      for(double p = nearestBuy - InpGridSpacing; p > tick.ask + InpInitialGap * 0.5; p -= InpGridSpacing)
         if(!StrategyPlanExists(state, ORDER_TYPE_BUY_STOP, StrategyAlignPrice(p)))
            StrategyQueuePending(state, ORDER_TYPE_BUY_STOP, p, InpFixedLot);
  }

int StrategyFindLevel(GridState &state, double price)
  {
   for(int i = 0; i < ArraySize(state.levelPrices); i++)
      if(MathAbs(state.levelPrices[i] - price) < InpGridSpacing * 0.5) return i;
   return -1;
  }

int StrategyLevelVisits(GridState &state, double price)
  {
   int i = StrategyFindLevel(state, price);
   return (i < 0) ? 0 : state.levelVisitCount[i];
  }

void StrategyRegisterVisit(GridState &state, double price, int side, double lot)
  {
   int i = StrategyFindLevel(state, price);
   if(i < 0)
     {
      int n = ArraySize(state.levelPrices);
      ArrayResize(state.levelPrices, n + 1);
      ArrayResize(state.levelVisitCount, n + 1);
      ArrayResize(state.levelLastSide, n + 1);
      ArrayResize(state.levelBaseLot, n + 1);
      state.levelPrices[n] = price;
      state.levelVisitCount[n] = 1;
      state.levelLastSide[n] = side;
      state.levelBaseLot[n] = lot;
      return;
     }
   state.levelVisitCount[i]++;
   state.levelLastSide[i] = side;
  }

double StrategyRevisitLot(GridState &state, double price, double baseLot)
  {
   int visits = StrategyLevelVisits(state, price);
   double lot = baseLot;
   if(InpRevisitLotStyle == REVISIT_LINEAR) lot *= visits + 1;
   else if(InpRevisitLotStyle == REVISIT_STEP) lot *= 1.0 + InpRevisitLotStep * visits;
   else if(InpRevisitLotStyle == REVISIT_FIBONACCI)
     {
      double a = 1.0, b = 1.0;
      for(int n = 3; n <= visits + 1; n++) { double c = a + b; a = b; b = c; }
      lot *= (visits + 1 <= 2) ? 1.0 : b;
     }
   if(InpRevisitLotStyle == REVISIT_FIXED) lot = baseLot;
   return StrategyAlignVolume(MathMin(lot, InpRevisitLotMax));
  }

double StrategyLevelBaseLot(GridState &state, double price)
  {
   int i = StrategyFindLevel(state, price);
   return (i < 0) ? 0.0 : state.levelBaseLot[i];
  }

void StrategyProcessInsideFill(GridState &state)
  {
   if(InpInsideStrategyStyle == STRATEGY_REVISIT && state.prevHitPrice > 0.0)
     {
      double price = StrategyAlignPrice(state.prevHitPrice);
      MqlTick tick = {};
      if(!SymbolInfoTick(_Symbol, tick)) return;
      double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      ENUM_ORDER_TYPE type;
      if(price < tick.bid - minStop) type = ORDER_TYPE_SELL_STOP;
      else if(price > tick.ask + minStop) type = ORDER_TYPE_BUY_STOP;
      else return;
      if(!StrategyPlanExists(state, type, price))
         StrategyQueuePending(state, type, price, StrategyRevisitLot(state, price, InpFixedLot));
     }
   else if(InpInsideStrategyStyle == STRATEGY_PASS_REFILL)
     {
      int side = (state.lastHitDirection == ORDER_TYPE_BUY) ? 1 : 2;
      if(state.runSide == 0 || side == state.runSide)
        {
         int n = ArraySize(state.runLevels);
         ArrayResize(state.runLevels, n + 1);
         state.runLevels[n] = state.lastHitPrice;
         state.runSide = side;
         return;
        }
      state.passCounter++;
      ENUM_ORDER_TYPE type = (state.runSide == 1) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
      for(int i = 0; i < ArraySize(state.runLevels); i++)
        {
         double price = StrategyAlignPrice(state.runLevels[i]);
         if(StrategyPlanExists(state, type, price)) continue;
         double base = StrategyLevelBaseLot(state, price);
         StrategyQueuePending(state, type, price, StrategyAlignVolume(base + InpPassRefillLotAdd));
        }
      state.runSide = side;
      ArrayResize(state.runLevels, 1);
      state.runLevels[0] = state.lastHitPrice;
     }
  }

void StrategyIncreaseOppositeLots(GridState &state)
  {
   if(InpLotIncreaseMode != LOT_INC_A || state.lastHitLot <= 0.0) return;
   double newLot = StrategyAlignVolume(state.lastHitLot * 2.0);
   ENUM_ORDER_TYPE opposite = (state.lastHitDirection == ORDER_TYPE_BUY)
                              ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
   bool updated = false;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_ORDER || item.orderType != opposite || item.action == ACTION_DELETE) continue;
      double oldLot = item.brokerPresent ? item.volume : item.targetLot;
      if(oldLot >= newLot) continue;
      if(item.orderTicket > 0 &&
         RequestReplaceOrder(state, item.orderTicket, item.targetPrice, newLot,
                             item.currentSL, item.currentTP)) updated = true;
     }
   if(updated) state.currentBlockLot = newLot;
  }

void StrategyQueueOutsideRefill(GridState &state)
  {
   if(InpOutsideRefillStyle == OUTSIDE_NONE) return;
   int buyCount = 0, sellCount = 0, buyPositions = 0, sellPositions = 0;
   double highBuy = 0.0, highBuyLot = 0.0, lowSell = 0.0, lowSellLot = 0.0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind == ITEM_ORDER && item.action != ACTION_DELETE)
        {
         double p = item.brokerPresent ? item.openPrice : item.targetPrice;
         double lot = item.brokerPresent ? item.volume : item.targetLot;
         if(StrategyIsBuyOrder(item.orderType)) { buyCount++; if(p > highBuy) { highBuy=p; highBuyLot=lot; } }
         else if(item.orderType == ORDER_TYPE_SELL_STOP) { sellCount++; if(lowSell == 0.0 || p < lowSell) { lowSell=p; lowSellLot=lot; } }
        }
      else if(item.kind == ITEM_POSITION && item.brokerPresent)
        {
         if(item.side == POSITION_TYPE_BUY) { buyPositions++; if(item.openPrice > highBuy) { highBuy=item.openPrice; highBuyLot=item.volume; } }
         else { sellPositions++; if(lowSell == 0.0 || item.openPrice < lowSell) { lowSell=item.openPrice; lowSellLot=item.volume; } }
        }
     }
   if(buyCount + sellCount + buyPositions + sellPositions == 0) return;

   for(int side = 0; side < 2; side++)
     {
      bool buy = (side == 0);
      int count = buy ? buyCount : sellCount;
      if(count >= InpMinGridLevels) continue;
      double anchor = buy ? highBuy : lowSell;
      double anchorLot = buy ? highBuyLot : lowSellLot;
      if(anchor <= 0.0) continue;
      int positionCount = buy ? buyPositions : sellPositions;
      for(int step = 1; step <= InpMaxGridLevels - count; step++)
        {
         int level = count + positionCount + step;
         double lot = InpFixedLot;
         if(InpOutsideRefillStyle == OUTSIDE_LAST_LOT && anchorLot > 0.0) lot = anchorLot;
         else if(InpOutsideRefillStyle == OUTSIDE_LADDER)
            lot = MathMin(InpInitialLotCap, InpFixedLot + InpInitialLotStep * (level - 1));
         else if(InpOutsideRefillStyle == OUTSIDE_EXP)
            lot = MathMin(InpInitialLotCap, InpFixedLot + InpInitialLotStep * MathPow(level - 1, 1.5));
         if(anchorLot > 0.0) lot = MathMax(lot, anchorLot);
         double price = buy ? anchor + InpGridSpacing * step : anchor - InpGridSpacing * step;
         StrategyQueuePending(state, buy ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP,
                              price, lot, 0.0, level);
        }
     }
  }

void StrategyProcessInsideMaintenance(GridState &state)
  {
   if(InpInsideMaintenanceStyle == MAINTENANCE_THRESHOLD)
     {
      StrategyFillOneSideInside(state, ORDER_TYPE_BUY_STOP);
      StrategyFillOneSideInside(state, ORDER_TYPE_SELL_STOP);
     }
   else if(InpInsideMaintenanceStyle == MAINTENANCE_FOLLOW_PRICE)
      StrategyRefillFollowPrice(state);
  }

void StrategyVerifyInitialGrid(GridState &state)
  {
   if((state.lifecycle != GRID_READY && state.lifecycle != GRID_ACTIVE) ||
      state.anchorBuy <= 0.0 || state.anchorSell <= 0.0) return;
   int buyLevel[];
   int sellLevel[];
   ArrayResize(buyLevel, InpInitialGridLevels + 1);
   ArrayResize(sellLevel, InpInitialGridLevels + 1);
   ArrayInitialize(buyLevel, 0);
   ArrayInitialize(sellLevel, 0);
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.action == ACTION_PLACE && item.actionStatus != ACTION_FAILED) return;
      if(item.action == ACTION_DELETE && item.replaceAfterDelete) return;
      if(item.level < 1 || item.level > InpInitialGridLevels) continue;
      if(item.kind == ITEM_ORDER && item.brokerPresent)
        {
         if(item.orderType == ORDER_TYPE_BUY_STOP) buyLevel[item.level] = 1;
         if(item.orderType == ORDER_TYPE_SELL_STOP) sellLevel[item.level] = 1;
        }
      else if(item.kind == ITEM_POSITION && item.brokerPresent)
        {
         if(item.side == POSITION_TYPE_BUY) buyLevel[item.level] = 1;
         else sellLevel[item.level] = 1;
        }
     }
   for(int level = 1; level <= InpInitialGridLevels; level++)
      if(buyLevel[level] == 0 || sellLevel[level] == 0)
        {
         state.safetyStopPending = true;
         state.safetyStopReason = "INITIAL_GRID_INCOMPLETE";
         return;
        }
  }

void StrategyUpdateSession(GridState &state)
  {
   static ulong lastCheckMs = 0;
   ulong now = GetTickCount64();
   if(lastCheckMs != 0 && now - lastCheckMs < (ulong)MathMax(1, InpSessionCheckIntervalMs)) return;
   lastCheckMs = now;
   state.sessionAllowed = IsSessionAllowed();
  }

void Strategy_MediumGrid(GridState &state)
  {
   StrategyUpdateSession(state);
   StrategyBuildGrid(state);
   if(state.lifecycle == GRID_ACTIVE && state.lastHitTicket > 0)
      StrategyIncreaseOppositeLots(state);
   StrategyVerifyInitialGrid(state);
   if(state.outsideRefillPending && state.lifecycle != GRID_CLEANUP)
     {
      StrategyQueueOutsideRefill(state);
      state.outsideRefillPending = false;
     }
   if(state.refillNeeded && state.lifecycle != GRID_CLEANUP)
     {
      StrategyProcessInsideMaintenance(state);
      state.refillNeeded = false;
     }
  }

#endif

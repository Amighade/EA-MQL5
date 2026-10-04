#ifndef STRATEGY_PROTECTION_MQH
#define STRATEGY_PROTECTION_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"
#include "../Utils/AsyncTrade.mqh"
#include "../Utils/TradeBook.mqh"
#include "StrategyGrid.mqh"

void StartCleanup(GridState &state, string reason);
void StrategyRequestWinnerSL(GridState &state, ENUM_POSITION_TYPE winner, double target);

bool StrategyDirectionSwitch(ENUM_ORDER_TYPE direction, GridState &state)
  {
   if(state.lastHitTicket == 0) return false;
   return ((state.lastHitDirection == ORDER_TYPE_BUY) != (direction == ORDER_TYPE_BUY));
  }

void StrategyRecordEntry(GridState &state, int itemIndex, TransactionItem &tx)
  {
   if(itemIndex < 0 || itemIndex >= ArraySize(state.items)) return;
   TradeItem item = state.items[itemIndex];
   ENUM_ORDER_TYPE direction = (item.side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(StrategyDirectionSwitch(direction, state)) state.passCounter++;

   state.prevHitPrice = state.lastHitPrice;
   state.prevHitDirection = state.lastHitDirection;
   state.lastHitDirection = direction;
   state.lastHitLot = item.volume;
   state.lastHitPrice = (item.openPrice > 0.0) ? item.openPrice : tx.price;
   state.lastHitTime = TimeCurrent();
   state.lastHitTicket = item.positionTicket;
   if(item.side == POSITION_TYPE_BUY)
     {
      if(state.farthestHitBuy == 0.0 || state.lastHitPrice > state.farthestHitBuy)
         state.farthestHitBuy = state.lastHitPrice;
     }
   else if(state.farthestHitSell == 0.0 || state.lastHitPrice < state.farthestHitSell)
      state.farthestHitSell = state.lastHitPrice;

   StrategyRegisterVisit(state, state.lastHitPrice,
                         item.side == POSITION_TYPE_BUY ? 1 : 0, item.volume);
   StrategyIncreaseOppositeLots(state);
   StrategyProcessInsideFill(state);
   if(state.slWallArmed)
      StrategyRequestWinnerSL(state, (ENUM_POSITION_TYPE)state.slWinnerSide, state.slLevel);
   state.outsideRefillPending = true;
  }

void StrategyRefreshBasket(GridState &state)
  {
   MqlTick tick = {};
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0) return;
   double moneyPerPrice = tickValue / tickSize;
   state.buyVolume = 0.0;
   state.sellVolume = 0.0;
   double buyCost = 0.0, sellCost = 0.0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_POSITION || !item.brokerPresent) continue;
      if(item.side == POSITION_TYPE_BUY)
        { state.buyVolume += item.volume; buyCost += item.openPrice * item.volume; }
      else
        { state.sellVolume += item.volume; sellCost += item.openPrice * item.volume; }
     }
   state.buyAvgEntry = (state.buyVolume > 0.0) ? buyCost / state.buyVolume : 0.0;
   state.sellAvgEntry = (state.sellVolume > 0.0) ? sellCost / state.sellVolume : 0.0;
   state.basketBuyProfit = (tick.bid - state.buyAvgEntry) * moneyPerPrice * state.buyVolume;
   state.basketSellProfit = (state.sellAvgEntry - tick.ask) * moneyPerPrice * state.sellVolume;
   state.basketProfit = state.basketBuyProfit + state.basketSellProfit;
   state.basketNetProfit = state.basketProfit -
                           InpCommissionPerLot * (state.buyVolume + state.sellVolume);
  }

double StrategySideProfit(ENUM_POSITION_TYPE side, double price, GridState &state)
  {
   double volume = (side == POSITION_TYPE_BUY) ? state.buyVolume : state.sellVolume;
   double entry = (side == POSITION_TYPE_BUY) ? state.buyAvgEntry : state.sellAvgEntry;
   if(volume <= 0.0) return 0.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0) return -1.0;
   double change = (side == POSITION_TYPE_BUY) ? price - entry : entry - price;
   return change * tickValue / tickSize * volume - InpCommissionPerLot * volume;
  }

double StrategyNetAtSL(ENUM_POSITION_TYPE winner, double candidate, GridState &state)
  {
   ENUM_POSITION_TYPE loser = (winner == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   double net = StrategySideProfit(winner, candidate, state);
   if((loser == POSITION_TYPE_BUY && state.buyVolume > 0.0) ||
      (loser == POSITION_TYPE_SELL && state.sellVolume > 0.0))
     {
      double exitPrice = (loser == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      net += StrategySideProfit(loser, exitPrice, state);
     }
   return net;
  }

double StrategySLAnchor(ENUM_POSITION_TYPE winner, GridState &state)
  {
   double last = state.lastHitPrice;
   MqlTick tick = {};
   if(!SymbolInfoTick(_Symbol, tick)) return last;
   double price = (winner == POSITION_TYPE_BUY) ? tick.bid : tick.ask;
   if(last <= 0.0) return price;
   double diff = price - last;
   if(winner == POSITION_TYPE_BUY && diff > InpGridSpacing) return price - InpGridSpacing;
   if(winner == POSITION_TYPE_SELL && diff < -InpGridSpacing) return price + InpGridSpacing;
   return last;
  }

bool StrategySLIsProgress(ENUM_POSITION_TYPE winner, double candidate, double oldSL)
  {
   if(oldSL <= 0.0) return true;
   return (winner == POSITION_TYPE_BUY) ? candidate > oldSL : candidate < oldSL;
  }

bool StrategySLBrokerOK(ENUM_POSITION_TYPE winner, double candidate)
  {
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(winner == POSITION_TYPE_BUY)
      return candidate <= SymbolInfoDouble(_Symbol, SYMBOL_BID) - minStop;
   return candidate >= SymbolInfoDouble(_Symbol, SYMBOL_ASK) + minStop;
  }

double StrategySLCandidate(GridState &state, ENUM_POSITION_TYPE winner, ENUM_SL_MODE mode)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double anchor = StrategySLAnchor(winner, state);
   double currentSL = state.slLevel;
   int nBack = MathMax(1, InpSLNBack);
   if(mode == SL_P_LEVEL)
     {
      double candidate = (winner == POSITION_TYPE_BUY) ? bid - minStop : ask + minStop;
      if(!StrategySLIsProgress(winner, candidate, currentSL) || !StrategySLBrokerOK(winner, candidate) ||
         StrategyNetAtSL(winner, candidate, state) < 0.0) return 0.0;
      return StrategyAlignPrice(candidate);
     }
   int start = (mode == SL_FAREST_P_GRID) ? nBack : 1;
   int stop = (mode == SL_FAREST_P_GRID) ? 1 : nBack;
   int step = (mode == SL_FAREST_P_GRID) ? -1 : 1;
   if(mode == SL_FIRST_GRID) stop = 1;
   for(int n = start; (step > 0) ? n <= stop : n >= stop; n += step)
     {
      double candidate = (winner == POSITION_TYPE_BUY)
                         ? anchor - InpGridSpacing * (n - 1)
                         : anchor + InpGridSpacing * (n - 1);
      candidate = StrategyAlignPrice(candidate);
      if(!StrategySLIsProgress(winner, candidate, currentSL) || !StrategySLBrokerOK(winner, candidate)) continue;
      if(StrategyNetAtSL(winner, candidate, state) >= 0.0)
         return candidate;
     }
   return 0.0;
  }

bool StrategyWinnerSLConfirmed(GridState &state, ENUM_POSITION_TYPE winner, double target)
  {
   int winners = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_POSITION || !item.brokerPresent || item.side != winner) continue;
      winners++;
      if(item.actionStatus == ACTION_FAILED)
        {
         state.safetyStopPending = true;
         state.safetyStopReason = "SL_MODIFY_FAILED";
         return false;
        }
      if(item.currentSL <= 0.0 ||
         (winner == POSITION_TYPE_BUY ? item.currentSL < target : item.currentSL > target)) return false;
      if(item.action == ACTION_MODIFY_SL && item.actionStatus != ACTION_IDLE) return false;
     }
   return (winners > 0);
  }

void StrategyRequestWinnerSL(GridState &state, ENUM_POSITION_TYPE winner, double target)
  {
   for(int i = 0; i < ArraySize(state.items); i++)
     {
      TradeItem item = state.items[i];
      if(item.kind != ITEM_POSITION || !item.brokerPresent || item.side != winner) continue;
      if(item.actionStatus == ACTION_FAILED)
        {
         state.safetyStopPending = true;
         state.safetyStopReason = "SL_MODIFY_FAILED";
         continue;
        }
      bool needsChange = (item.currentSL <= 0.0 ||
                          (winner == POSITION_TYPE_BUY ? item.currentSL < target : item.currentSL > target));
      if(needsChange && item.actionStatus != ACTION_WAIT_RESULT &&
         item.actionStatus != ACTION_WAIT_CONFIRM)
         RequestModifySL(state, item.positionTicket, target);
     }
  }

void StrategyProcessSL(GridState &state)
  {
   StrategyRefreshBasket(state);
   if(state.slWallArmed)
     {
      ENUM_POSITION_TYPE winner = (ENUM_POSITION_TYPE)state.slWinnerSide;
      StrategyRequestWinnerSL(state, winner, state.slLevel);
      StrategyWinnerSLConfirmed(state, winner, state.slLevel);
      if(state.safetyStopPending || InpSLTrailMode == SL_NONE) return;
      double candidate = StrategySLCandidate(state, winner, InpSLTrailMode);
      if(candidate > 0.0 && StrategySLIsProgress(winner, candidate, state.slLevel))
        {
         StrategyRequestWinnerSL(state, winner, candidate);
         state.slLevel = candidate;
        }
      return;
     }

   if(InpSLArmMode == SL_NONE || state.basketProfit <= 0.0) return;
   ENUM_POSITION_TYPE winner = (state.lastHitDirection == ORDER_TYPE_BUY)
                               ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   if(state.slApplied)
     {
      StrategyRequestWinnerSL(state, winner, state.slLevel);
      if(StrategyWinnerSLConfirmed(state, winner, state.slLevel))
        {
         state.slWallArmed = true;
         state.slWinnerSide = (int)winner;
        }
      return;
     }
   double candidate = StrategySLCandidate(state, winner, InpSLArmMode);
   if(candidate <= 0.0) return;
   state.slLevel = candidate;
   state.slWinnerSide = (int)winner;
   state.slApplied = true; // pending until live broker data confirms every winner
   StrategyRequestWinnerSL(state, winner, candidate);
   if(StrategyWinnerSLConfirmed(state, winner, candidate))
      state.slWallArmed = true;
  }

int StrategyLiveWinnerCount(GridState &state)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(state.items); i++)
      if(state.items[i].kind == ITEM_POSITION && state.items[i].brokerPresent &&
         (int)state.items[i].side == state.slWinnerSide) count++;
   return count;
  }

void Strategy_OnExit(GridState &state, int itemIndex, TransactionItem &tx)
  {
   if(!state.slWallArmed || StrategyLiveWinnerCount(state) == 0)
     {
      StartCleanup(state, "Rev22.2 strategy: position exit");
      return;
     }
   state.slAllWinnersClosed = false;
  }

#endif

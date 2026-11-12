

#ifndef SL_GRID_FEASIBILITY_MQH
#define SL_GRID_FEASIBILITY_MQH

#include "../Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/TradeUtils.mqh"
//====================================================
// NET BASKET AT A CANDIDATE SL PRICE
// Winner side is evaluated AT the candidate (the real hypothetical:
// "if the winner's SL got hit right here"). Loser side, if still open
// (InpCloseLosersAtArm=false), is evaluated at ITS OWN live market
// price, not at the winner's candidate -- the old SL_CalcNetBasket
// applied one price to every position regardless of side, which was
// wrong for the loser side (it doesn't close at the winner's SL).
//====================================================
void NetBasketAtCandidate(GridState &state, ENUM_POSITION_TYPE winnerSide, double candidate,
                           double &profit, double &netProfit)
{
   ENUM_POSITION_TYPE loserSide = (winnerSide == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   double winVol   = (winnerSide == POSITION_TYPE_BUY) ? state.buyVolume   : state.sellVolume;
   double winEntry = (winnerSide == POSITION_TYPE_BUY) ? state.buyAvgEntry : state.sellAvgEntry;
   double loseVol   = (loserSide == POSITION_TYPE_BUY) ? state.buyVolume   : state.sellVolume;
   double loseEntry = (loserSide == POSITION_TYPE_BUY) ? state.buyAvgEntry : state.sellAvgEntry;

   double winnerProfit = SideProfitAtPrice(winnerSide, winVol, winEntry, candidate);
   double loserProfit  = 0.0;

   if(loseVol > 0)
     {
      double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      - SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double loserPrice = (loserSide == POSITION_TYPE_BUY)
                          ? candidate - spread
                          : candidate + spread;

      loserProfit = SideProfitAtPrice(loserSide, loseVol, loseEntry, loserPrice);
     }

   profit = winnerProfit + loserProfit;
   netProfit = profit - InpCommissionPerLot * (winVol + loseVol);
}

double SideProfitAtPrice(ENUM_POSITION_TYPE side, double volume, double avgEntry, double candidate)
{
   if(volume <= 0) return 0.0;

   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSz <= 0) return -1;
   double moneyPerPrice = tickVal / tickSz;

   double diff = (side == POSITION_TYPE_BUY) ? (candidate - avgEntry) : (avgEntry - candidate);
   return diff * moneyPerPrice * volume;
}

void NetBasketAtPrice(GridState &state)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   state.basketBuyProfit =
      SideProfitAtPrice(POSITION_TYPE_BUY,
                        state.buyVolume, state.buyAvgEntry, bid);

   state.basketSellProfit =
      SideProfitAtPrice(POSITION_TYPE_SELL,
                        state.sellVolume, state.sellAvgEntry, ask);

   state.basketProfit = state.basketBuyProfit + state.basketSellProfit;

   state.basketNetProfit = state.basketProfit
                          - InpCommissionPerLot
                            * (state.buyVolume + state.sellVolume);
}
//====================================================
// GRID ANCHOR RESOLUTION (handles gaps)
//====================================================
double SL_GetAnchorPrice(GridState &state, ENUM_POSITION_TYPE winnerSide, int magicNumber)
{
   double last = state.lastHitPrice;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = MinStopDistancePrice(_Symbol);
   double price = (winnerSide == POSITION_TYPE_BUY ? bid : ask);
   double grid = InpGridSpacing;
   double distance = (winnerSide == POSITION_TYPE_BUY)
                     ? price - last
                     : last - price;
   
   if(distance > grid || last <= 0.0)
      return (winnerSide == POSITION_TYPE_BUY)
             ? bid - grid
             : ask + grid;
             
   if(distance < 1.1 * minStop)
      return (winnerSide == POSITION_TYPE_BUY)
             ? last - grid
             : last + grid;

   return last;
}
//====================================================
// Shared grid-level search, used by both SL_NEAREST_P_GRID and
// SL_FAREST_P_GRID -- only the scan direction differs (nearFirst).
//====================================================
double SL_SearchGridLevels(GridState &state, double anchor, ENUM_POSITION_TYPE winnerSide,
                           double currentSL, bool nearFirst)
{
   int start = nearFirst ? 1 : InpSLNBack;
   int stop  = nearFirst ? InpSLNBack : 1;
   int step  = nearFirst ? 1 : -1;

   for(int n = start; nearFirst ? (n <= stop) : (n >= stop); n += step)
     {
      double candidate = SL_GetGridLevel(anchor, n, winnerSide);
//      if(!SL_IsProgress(winnerSide, candidate, currentSL)) continue;
//      if(!SL_BrokerOK(winnerSide, candidate)) continue;
      
      double profit = 0;
      double netProfit = 0;
      NetBasketAtCandidate(state, winnerSide, candidate, profit, netProfit);
      if(netProfit >= 0.0) return candidate;
     }
   return 0;
}
//====================================================
// GRID LEVEL GENERATOR
//====================================================
double SL_GetGridLevel(double anchor, int n, ENUM_POSITION_TYPE winnerSide)
{
   // [REV-2026-09-15-CPU-VOLATILITY] why: the previous implementation
   // walked n grid steps with a loop for every candidate. In farthest-first
   // mode that repeated arithmetic inside an already hot search. Grid levels
   // are linear, so compute the same result directly in O(1).
   double direction = (winnerSide == POSITION_TYPE_BUY) ? -1.0 : 1.0;
   double level = anchor + direction * InpGridSpacing * (n - 1);
   return AlignToTick(_Symbol, level);
}

//====================================================
// MAIN GRID FEASIBILITY ENGINE
//====================================================
double SL_FindCandidate(GridState &state, ENUM_POSITION_TYPE winnerSide,
                        int magicNumber, ENUM_SL_MODE mode)
{
   double anchor     = SL_GetAnchorPrice(state, winnerSide, magicNumber);
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop    = MinStopDistancePrice(_Symbol);
   double currentSL  = state.slLevel;

   //====================================================
   // MODE 1: no grid — nearest broker-legal level
   //====================================================
   if(mode == SL_P_LEVEL)
     {
      double candidate = (winnerSide == POSITION_TYPE_BUY) ? (bid - minStop) : (ask + minStop);

      double profit = 0;
      double netProfit = 0;
      NetBasketAtCandidate(state, winnerSide, candidate, profit, netProfit);

      if(netProfit <= 0) return 0;
      return candidate;
     }

   //====================================================
   // MODE 2: nearest grid line
   //====================================================
   if(mode == SL_FIRST_GRID)
     {
      return anchor;
     }
     
   //====================================================
   // MODE 3: nearest grid line
   //====================================================
   if(mode == SL_N_GRID)
     {
      return (winnerSide == POSITION_TYPE_BUY) ? (anchor - N_GRID * InpGridSpacing) 
      : (anchor + N_GRID * InpGridSpacing);
     }

   //====================================================
   // MODE 4: N GRID AUTO SEARCH (nearest-first valid wins)
   //====================================================
   if(mode == SL_NEAREST_P_GRID)
      return SL_SearchGridLevels(state, anchor, winnerSide, currentSL, true);

   //====================================================
   // MODE 5: N GRID AUTO SEARCH (farthest-first valid wins)
   //====================================================
   if(mode == SL_FAREST_P_GRID)
      return SL_SearchGridLevels(state, anchor, winnerSide, currentSL, false);
      
   //====================================================
   // MODE 6: no grid — nearest price
   //====================================================
   if(mode == SL_F_PRICE_LEVEL)
     {
      double candidate = (winnerSide == POSITION_TYPE_BUY) ? (bid) : (ask);
      return candidate;
     }

   //====================================================
   // MODE 7: no grid — nearest broaker level
   //====================================================
   if(mode == SL_F_BROAKER_LEVEL)
     {
      double candidate = (winnerSide == POSITION_TYPE_BUY) ? (bid - minStop) : (ask + minStop);
      return candidate;
     }
   return 0;
}
#endif
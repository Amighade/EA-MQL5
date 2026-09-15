

#ifndef SL_GRID_FEASIBILITY_MQH
#define SL_GRID_FEASIBILITY_MQH

#include "../Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/TradeUtils.mqh"

//====================================================
// [REV-2026-09-12-BACKBONE]
// Full rewrite. What changed and why:
//  - SLPos/SL_CalcNetBasket (looped every position, every call) removed.
//    Replaced by NetBasketAtCandidate() below, which uses the O(1)
//    incremental {volume, avgEntry} aggregate on GridState instead --
//    same idea as SideProfitAtPrice in MathUtils.mqh.
//  - The net>=0 check was present on 3 of 4 modes and silently missing
//    on SL_FIRST_GRID -- now consistent across all 4.
//  - The "don't move SL backward" (isProgress) guard was present on
//    SL_NEAREST_P_GRID/SL_FAREST_P_GRID but missing on SL_P_LEVEL and
//    SL_FIRST_GRID -- a real gap (those two modes could have trailed a
//    live SL backward). Now consistent across all 4.
//  - SL_NEAREST_P_GRID and SL_FAREST_P_GRID were near-identical blocks
//    (same candidate/isProgress/net/broker checks, only loop direction
//    differed) -- merged into one shared search, direction as a param.
//  - Position array / count params dropped from the public signature
//    entirely -- nothing here needs per-position data anymore.
//====================================================

//====================================================
// NET BASKET AT A CANDIDATE SL PRICE
// Winner side is evaluated AT the candidate (the real hypothetical:
// "if the winner's SL got hit right here"). Loser side, if still open
// (InpCloseLosersAtArm=false), is evaluated at ITS OWN live market
// price, not at the winner's candidate -- the old SL_CalcNetBasket
// applied one price to every position regardless of side, which was
// wrong for the loser side (it doesn't close at the winner's SL).
//====================================================
double NetBasketAtCandidate(GridState &state, ENUM_POSITION_TYPE winnerSide, double candidate)
{
   ENUM_POSITION_TYPE loserSide = (winnerSide == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   double winVol   = (winnerSide == POSITION_TYPE_BUY) ? state.buyVolume   : state.sellVolume;
   double winEntry = (winnerSide == POSITION_TYPE_BUY) ? state.buyAvgEntry : state.sellAvgEntry;
   double loseVol   = (loserSide == POSITION_TYPE_BUY) ? state.buyVolume   : state.sellVolume;
   double loseEntry = (loserSide == POSITION_TYPE_BUY) ? state.buyAvgEntry : state.sellAvgEntry;

   double net = SideProfitAtPrice(winnerSide, winVol, winEntry, candidate);

   if(loseVol > 0)
     {
      double loserPrice = (loserSide == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      net += SideProfitAtPrice(loserSide, loseVol, loseEntry, loserPrice);
     }
   return net;
}

//====================================================
// GRID ANCHOR RESOLUTION (handles gaps)
//====================================================
double SL_GetAnchorPrice(GridState &state, ENUM_POSITION_TYPE winnerSide, int magicNumber)
{
   double last = state.lastHitPrice;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double price = (winnerSide == POSITION_TYPE_BUY ? bid : ask);

   double grid = InpGridSpacing;

   if(last <= 0)
      return price;

   double diff = price - last;

   // gap correction
   if(winnerSide == POSITION_TYPE_BUY)
   {
      if(diff > grid)
         return (price - grid);
   }
   else
   {
      if(diff < -grid)
         return (price + grid);
   }

   return last;
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
// BROKER VALIDATION
//====================================================
bool SL_BrokerOK(int winnerSide, double candidate)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double minStop = MinStopDistancePrice(_Symbol);

   if(winnerSide == POSITION_TYPE_BUY)
      return (candidate <= bid - minStop);

   return (candidate >= ask + minStop);
}

//====================================================
// Shared progress guard -- never accept a candidate that moves the SL
// backward relative to what's already applied. Consistent across every
// mode now (previously only 2 of 4 modes had this).
//====================================================
bool SL_IsProgress(ENUM_POSITION_TYPE winnerSide, double candidate, double currentSL)
{
   if(currentSL <= 0) return true; // nothing applied yet -- anything is progress
   return (winnerSide == POSITION_TYPE_BUY) ? (candidate > currentSL) : (candidate < currentSL);
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
      if(!SL_IsProgress(winnerSide, candidate, currentSL)) continue;
      if(!SL_BrokerOK(winnerSide, candidate)) continue;
      double net = NetBasketAtCandidate(state, winnerSide, candidate);
      if(net >= 0.0) return candidate;
     }
   return 0;
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
      if(!SL_IsProgress(winnerSide, candidate, currentSL)) return 0;
      if(!SL_BrokerOK(winnerSide, candidate)) return 0;
      if(NetBasketAtCandidate(state, winnerSide, candidate) < 0.0) return 0;
      return candidate;
     }

   //====================================================
   // MODE 2: nearest grid line
   //====================================================
   if(mode == SL_FIRST_GRID)
     {
      double candidate = SL_GetGridLevel(anchor, 1, winnerSide);
      if(!SL_IsProgress(winnerSide, candidate, currentSL)) return 0;
      if(!SL_BrokerOK(winnerSide, candidate)) return 0;
      if(NetBasketAtCandidate(state, winnerSide, candidate) < 0.0) return 0;
      return candidate;
     }

   //====================================================
   // MODE 3: N GRID AUTO SEARCH (nearest-first valid wins)
   //====================================================
   if(mode == SL_NEAREST_P_GRID)
      return SL_SearchGridLevels(state, anchor, winnerSide, currentSL, true);

   //====================================================
   // MODE 4: N GRID AUTO SEARCH (farthest-first valid wins)
   //====================================================
   if(mode == SL_FAREST_P_GRID)
      return SL_SearchGridLevels(state, anchor, winnerSide, currentSL, false);

   return 0;
}

#endif

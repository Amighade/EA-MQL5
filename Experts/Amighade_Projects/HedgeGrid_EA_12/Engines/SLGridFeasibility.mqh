

#ifndef SL_GRID_FEASIBILITY_MQH
#define SL_GRID_FEASIBILITY_MQH

#include "../Inputs.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/TradeUtils.mqh"

//====================================================
// POSITION STRUCT
//====================================================
struct SLPos
{
   ulong  ticket;
   double entry;
   double lot;
   int    type;
};

//====================================================
// GRID MODE (expected external enum)
//====================================================
// SL_AUTO    -> scan until first valid
// SL_FIXED_N -> only test N-back level

//====================================================
// NET BASKET CALCULATION AT SL
//====================================================
double SL_CalcNetBasket(SLPos &pos[], int n, double candidateSL)
{
   double net = 0.0;

   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickVal <= 0 || tickSz <= 0)
      return -1;

   double moneyPerPrice = tickVal / tickSz;

   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                 - SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 0; i < n; i++)
   {
      double diff = 0.0;

      if(pos[i].type == POSITION_TYPE_BUY)
         diff = candidateSL - pos[i].entry;
      else
         diff = pos[i].entry - (candidateSL + spread);

      net += diff * moneyPerPrice * pos[i].lot;
      net -= InpCommissionPerLot * pos[i].lot;
   }

   return net;
}

//====================================================
// GRID ANCHOR RESOLUTION (handles gaps)
//====================================================
double SL_GetAnchorPrice(ENUM_POSITION_TYPE winnerSide, int magicNumber)
{
   double last = GetLastEntryPrice(winnerSide, magicNumber);

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
   double level = anchor;

   for(int i = 1; i < n; i++)
   {
      if(winnerSide == POSITION_TYPE_BUY)
         level -= InpGridSpacing;
      else
         level += InpGridSpacing;
   }

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
// MAIN GRID FEASIBILITY ENGINE
//====================================================
double SL_FindCandidate(GridState &state, SLPos &pos[], int count, ENUM_POSITION_TYPE winnerSide,
                        int magicNumber, ENUM_SL_MODE mode)
{
   if(count <= 0)
      return 0;

   double anchor = SL_GetAnchorPrice(winnerSide, magicNumber);
   int maxN = 2;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = MinStopDistancePrice(_Symbol);
   
   //====================================================
   // MODE 1: no grid — nearest level                
   //====================================================
   if(mode == SL_P_LEVEL)
     {
      if(winnerSide == POSITION_TYPE_BUY)
         {
         double candidate = bid - minStop;
         double net = state.basketNetProfit;
         if(net >= 0.0 && SL_BrokerOK(winnerSide, candidate))
         return candidate;
         }
      else if(winnerSide == POSITION_TYPE_SELL)
         {
         double candidate = ask + minStop;
         double net = state.basketNetProfit;
         if(net >= 0.0 && SL_BrokerOK(winnerSide, candidate))
         return candidate;
         }
      //if(winnerSide == POSITION_TYPE_BUY)
      //return (bid - minStop);
      //return (ask + minStop);
     }

   //====================================================
   // MODE 2: last grid — nearest grid, no net check.             
   //====================================================
   if(mode == SL_NO_GRID)
     {
      double candidate = SL_GetGridLevel(anchor, 1, winnerSide);
      if(SL_BrokerOK(winnerSide, candidate))
         return candidate;
      return 0;
     }

   //====================================================
   // MODE 3: N GRID AUTO SEARCH (nearest-first valid wins)
   //====================================================
   if(mode == SL_LAST_HIT_GRID)
     {
      for(int n = 1; n <= maxN; n++)
        {
         double candidate = SL_GetGridLevel(anchor, n, winnerSide);
         double net = SL_CalcNetBasket(pos, count, candidate);
         if(net >= 0.0 && SL_BrokerOK(winnerSide, candidate))
            return candidate;
        }
     }
   //====================================================
   // MODE 4: N GRID AUTO SEARCH (farthest-first valid wins)
   //====================================================
   if(mode == SL_N_BACK_GRID)
     {
      for(int n = InpSLNBack; n >= 1; n--)
        {
         double candidate = SL_GetGridLevel(anchor, n, winnerSide);
         double net = SL_CalcNetBasket(pos, count, candidate);
         if(net >= 0.0 && SL_BrokerOK(winnerSide, candidate))
            return candidate;
        }
     }

   return 0;
}

#endif
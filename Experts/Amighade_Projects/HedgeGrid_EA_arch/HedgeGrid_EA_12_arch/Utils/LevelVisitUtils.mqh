#ifndef LEVEL_VISIT_UTILS_MQH
#define LEVEL_VISIT_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"

// Find the index of the level nearest 'price' within half a grid spacing.
// Returns -1 if this level has never been touched before.
int FindLevelIndex(GridState &state, double price)
{
   int n = ArraySize(state.levelPrices);
   for(int i = 0; i < n; i++)
      if(MathAbs(state.levelPrices[i] - price) < InpGridSpacing * 0.5)
         return i;
   return -1;
}

// How many times has this level already been touched? (0 if new)
int GetLevelVisitCount(GridState &state, double price)
{
   int idx = FindLevelIndex(state, price);
   return (idx < 0) ? 0 : state.levelVisitCount[idx];
}

// Call this from OrderMonitor.ProcessOrderFill — records that a fill
// just happened at 'price'. Increments the counter for that level.
void RegisterLevelVisit(GridState &state, double price, int side, double lot)
{
   int idx = FindLevelIndex(state, price);
   if(idx < 0)
     {
      int n = ArraySize(state.levelPrices);
      ArrayResize(state.levelPrices, n + 1);
      ArrayResize(state.levelVisitCount, n + 1);
      ArrayResize(state.levelLastSide, n + 1);
      ArrayResize(state.levelBaseLot, n + 1);
      state.levelPrices[n]     = price;
      state.levelVisitCount[n] = 1;
      state.levelLastSide[n]   = side;
      state.levelBaseLot[n]    = lot;      // captured once — never touched again
      return;
     }
   state.levelVisitCount[idx]++;
   state.levelLastSide[idx] = side;
   // levelBaseLot[idx] deliberately left alone here
}

double GetLevelBaseLot(GridState &state, double price)
{
   int idx = FindLevelIndex(state, price);
   return (idx < 0) ? 0.0 : state.levelBaseLot[idx];
}

double GetPassRefillLot(GridState &state, double price)
{
   return GetLevelBaseLot(state, price) + InpPassRefillLotAdd;
}

//+------------------------------------------------------------------+
//| Lot size for a new order about to be placed at 'price', based on |
//| how many times this exact grid level has already been touched   |
//| (levelVisitCount, tracked in RegisterLevelVisit — increments on  |
//| every fill at this level, either side, called from               |
//| OrderMonitor.mqh). 'visits' is the count BEFORE this new order;  |
//| the formulas below add 1 so a level's first-ever order still     |
//| gets baseLot, and each later touch grows from there.             |
//|                                                                    |
//| Growth formula is selectable via InpRevisitLotStyle:              |
//|   REVISIT_FIXED     - always baseLot, visit count ignored         |
//|   REVISIT_LINEAR    - baseLot x (visits+1)                        |
//|   REVISIT_STEP      - baseLot x (1 + InpRevisitLotStep x visits), |
//|                        same shape as LINEAR but with a tunable    |
//|                        growth rate instead of a fixed +1/visit    |
//|   REVISIT_FIBONACCI - baseLot x fib(visits+1), faster than        |
//|                        LINEAR, far slower than an exponential     |
//|                        growth pattern                             |
//|                                                                    |
//| Whichever formula runs, the result is always capped at            |
//| InpRevisitLotMax before broker volume-step alignment — unbounded  |
//| growth (e.g. martingale-style doubling) is not offered as a style |
//| here on purpose: tested in simulation, it produced exposure many  |
//| orders of magnitude beyond any live-account-safe size, especially |
//| in choppy/whipsaw price action. See FibonacciAt() just above for  |
//| the sequence used by REVISIT_FIBONACCI.                           |
//+------------------------------------------------------------------+

double GetLevelIncrementLot(GridState &state, double price, double baseLot)
{
   int visits = GetLevelVisitCount(state, price);
   double lot;

   switch(InpRevisitLotStyle)
     {
      case REVISIT_FIXED:
         lot = baseLot;
         break;
      case REVISIT_STEP:
         lot = baseLot * (1.0 + InpRevisitLotStep * visits);
         break;
      case REVISIT_FIBONACCI:
         lot = baseLot * FibonacciAt(visits + 1);
         break;
      case REVISIT_LINEAR:
      default:
         lot = baseLot * (visits + 1);
         break;
     }

   lot = MathMin(lot, InpRevisitLotMax);
   return AlignVolume(_Symbol, lot);
}

// Standard Fibonacci sequence, 1-indexed (n=1 -> 1, n=2 -> 1, n=3 -> 2, n=4 -> 3, n=5 -> 5, ...)
double FibonacciAt(int n)
{
   if(n <= 2) return 1.0;
   double a = 1.0, b = 1.0, c = 0.0;
   for(int i = 3; i <= n; i++)
     {
      c = a + b;
      a = b;
      b = c;
     }
   return b;
}

#endif

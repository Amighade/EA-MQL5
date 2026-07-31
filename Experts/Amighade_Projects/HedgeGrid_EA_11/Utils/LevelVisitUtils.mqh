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

// Lot for a NEW order about to sit at 'price': base lot times
// (visits so far + 1) — i.e. the 1st touch is base lot, the 2nd
// touch (a reversal re-entry, by definition) is 2x, etc.
double GetLevelIncrementLot(GridState &state, double price, double baseLot)
{
   int visits = GetLevelVisitCount(state, price);
   double lot = baseLot * (visits + 1);
   return AlignVolume(_Symbol, lot);
}

#endif

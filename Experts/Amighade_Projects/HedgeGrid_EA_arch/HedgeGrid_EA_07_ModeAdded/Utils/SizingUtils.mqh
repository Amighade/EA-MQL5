//+------------------------------------------------------------------+
//| SizingUtils.mqh                                                   |
//| Initial grid lot sizing (independent of any "style" — selected   |
//| via InpInitialSizing: SIZING_FIXED or SIZING_LADDER).             |
//| Lives in Utils (not Engines) because it is a shared, stateless    |
//| calculation used by three different engines (GridBuilder,        |
//| ShiftingEngine, MarginCheck) — engines never cross each other,    |
//| but all may depend on Utils.                                      |
//| This is separate from Brick 1 (Engines/GridUpdater.mqh), which    |
//| governs lot changes on an OPPOSITE-side hit, not initial build.  |
//+------------------------------------------------------------------+
#ifndef SIZING_UTILS_MQH
#define SIZING_UTILS_MQH

#include "../Inputs.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| Get max levels for current lot mode (margin fallback halves it)  |
//+------------------------------------------------------------------+
int GetMaxLevels(ENUM_LOT_MODE lotMode)
  {
   return (lotMode == LOT_FULL) ? InpInitialGridLevels : InpInitialGridLevels / 2;
  }

//+------------------------------------------------------------------+
//| Ladder lot sizing                                                 |
//| level: 1-based grid level (1 = nearest to price)                 |
//+------------------------------------------------------------------+
double GetLot_Ladder(int level, ENUM_LOT_MODE lotMode)
  {
   int maxLevel = GetMaxLevels(lotMode);
   level = MathMin(level, maxLevel); // Clamp to max level

   double lot = InpInitialLotStep * level;
   lot = MathMin(lot, InpInitialLotCap); // Cap at maximum
   return AlignVolume(_Symbol, lot);
  }

//+------------------------------------------------------------------+
//| Fixed lot sizing — all levels use the same lot                   |
//+------------------------------------------------------------------+
double GetLot_Fixed(int level, ENUM_LOT_MODE lotMode)
  {
   return AlignVolume(_Symbol, InpFixedLot);
  }

//+------------------------------------------------------------------+
//| Master function — the ONLY function engines should call for      |
//| initial-build lot sizing. Mode selected via InpInitialSizing.    |
//+------------------------------------------------------------------+
double GetLot(int level, ENUM_LOT_MODE lotMode)
  {
   switch(InpInitialSizing)
     {
      case SIZING_LADDER: return GetLot_Ladder(level, lotMode);
      case SIZING_FIXED:  return GetLot_Fixed(level, lotMode);
      default:             return GetLot_Fixed(level, lotMode);
     }
  }

#endif

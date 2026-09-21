//+------------------------------------------------------------------+
//| SizingEngine.mqh                                                  |
//| Pluggable lot size calculation per grid level                    |
//| Style A: Ladder (0.01 × level, capped at InpInitialLotCap)      |
//| Style B: Fixed lot for all levels (InpFixedLot)                  |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| Style A — Ladder lot sizing                                       |
//| level: 1-based grid level (1 = nearest to price)                 |
//| lotMode: FULL (20 levels) or HALF (10 levels)                    |
//+------------------------------------------------------------------+
double GetLot_A(int level, ENUM_LOT_MODE lotMode)
  {
   int maxLevel = (lotMode == LOT_FULL) ? InpGridLevels : InpGridLevels / 2;
   level = MathMin(level, maxLevel); // Clamp to max level

   double lot = InpInitialLotStep * level;
   lot = MathMin(lot, InpInitialLotCap); // Cap at maximum
   return RoundLot(lot);
  }

//+------------------------------------------------------------------+
//| Style B — Fixed lot sizing                                        |
//| All levels use the same lot regardless of level number           |
//+------------------------------------------------------------------+
double GetLot_B(int level, ENUM_LOT_MODE lotMode)
  {
   return RoundLot(InpFixedLot);
  }

//+------------------------------------------------------------------+
//| Master function — calls correct style based on InpStrategyStyle  |
//| This is the ONLY function engines should call for lot sizing      |
//+------------------------------------------------------------------+
double GetLot(int level, ENUM_LOT_MODE lotMode)
  {
   switch(InpStrategyStyle)
     {
      case STYLE_A: return GetLot_A(level, lotMode);
      case STYLE_B: return GetLot_B(level, lotMode);
      default:      return GetLot_A(level, lotMode);
     }
  }

//+------------------------------------------------------------------+
//| Get max levels for current lot mode                               |
//+------------------------------------------------------------------+
int GetMaxLevels(ENUM_LOT_MODE lotMode)
  {
   return (lotMode == LOT_FULL) ? InpGridLevels : InpGridLevels / 2;
  }

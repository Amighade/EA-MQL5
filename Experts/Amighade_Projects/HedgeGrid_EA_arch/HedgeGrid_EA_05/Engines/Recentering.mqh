//+------------------------------------------------------------------+
//| Recentering.mqh                                                   |
//| Keep fresh grid centered around current price                    |
//| Only active when no positions open (fresh grid state)            |
//+------------------------------------------------------------------+
#ifndef RECENTERING_MQH
#define RECENTERING_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

// Track last candle processed to run only once per candle
datetime g_lastRecenterCandle = 0;

//+------------------------------------------------------------------+
//| Check if recentering is needed                                   |
//| Formula:                                                         |
//|   recenter_threshold = InitialGap / ThresholdFactor             |
//|   x = (InitialGap - recenter_threshold) / 2                     |
//|   valid zone: anchorSell - x < price < anchorSell + x           |
//+------------------------------------------------------------------+
bool CheckRecenterNeeded(double currentPrice, const GridState &state)
{
   if(!InpEnableRecentering) return false;
   if(state.cycleActive)     return false; // Fresh grid only
   if(!state.gridPlaced)     return false;

   // Only once per candle
   datetime currentCandle = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentCandle == g_lastRecenterCandle) return false;

   double threshold = InpInitialGap / InpThresholdFactor;
   double x         = (InpInitialGap - threshold) / 2.0;

   double zoneLow  = state.anchorSell - x;
   double zoneHigh = state.anchorSell + x;

   bool outside = (currentPrice < zoneLow || currentPrice > zoneHigh);

   if(outside)
      LogDebug(StringFormat("Recenter: price=%.2f outside zone [%.2f, %.2f]",
                            currentPrice, zoneLow, zoneHigh));

   return outside;
}

//+------------------------------------------------------------------+
//| Execute recentering — delete all orders, signal grid rebuild     |
//+------------------------------------------------------------------+
void RecenterGrid(double currentPrice, GridState &state)
{
   double oldAnchor = state.anchorSell;

   g_lastRecenterCandle = iTime(_Symbol, PERIOD_CURRENT, 0);

   DeleteAllOrders(state.magicNumber);
   state.gridPlaced = false; // Signal coordinator to rebuild

   LogRecentering(oldAnchor, currentPrice);
}

//+------------------------------------------------------------------+
//| Master recentering check — call from OnTick                     |
//| Style C: always returns false — persistent grid never recenters  |
//+------------------------------------------------------------------+
bool ProcessRecentering(GridState &state)
{
   // Style C grid persists through SL hits — no recentering ever
   if(InpStrategyStyle == STYLE_C) return false;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!CheckRecenterNeeded(currentPrice, state)) return false;

   RecenterGrid(currentPrice, state);
   return true;
}

#endif

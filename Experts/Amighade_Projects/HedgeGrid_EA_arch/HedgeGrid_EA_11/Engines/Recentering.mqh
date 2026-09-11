//+------------------------------------------------------------------+
//| Recentering.mqh                                                   |
//| BRICK 3: keep a fresh grid centered around current price.        |
//| Gated purely by InpEnableRecentering — independent of any other   |
//| brick (shifting/refill do NOT auto-force this off; that's a      |
//| manual user responsibility, matching the refill/shifting rule).  |
//| Only active when no positions open (fresh grid state).           |
//+------------------------------------------------------------------+
#ifndef RECENTERING_MQH
#define RECENTERING_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/BarUtils.mqh"

//+------------------------------------------------------------------+
//| Check if recentering is needed                                   |
//| Formula:                                                         |
//|   recenter_threshold = InitialGap / ThresholdFactor             |
//|   x = (InitialGap - recenter_threshold) / 2                     |
//|   valid zone: anchorSell - x < price < anchorSell + x           |
//+------------------------------------------------------------------+
bool CheckRecenterNeeded(double currentPrice, GridState &state)
{
   if(!InpEnableRecentering) return false;
   if(state.cycleActive)     return false; // Fresh grid only
   if(!state.gridPlaced)     return false;

   // Only once per candle (shared bar tracker, owned by this engine's state field)
   if(!IsNewBar(state.lastBarRecenter)) return false;

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

   DeleteAllOrders(state.magicNumber);
   state.gridPlaced = false; // Signal coordinator to rebuild

   LogRecentering(oldAnchor, currentPrice);
}

//+------------------------------------------------------------------+
//| Master recentering check — call from OnTick                     |
//+------------------------------------------------------------------+
bool ProcessRecentering(GridState &state)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!CheckRecenterNeeded(currentPrice, state)) return false;

   RecenterGrid(currentPrice, state);
   return true;
}

#endif

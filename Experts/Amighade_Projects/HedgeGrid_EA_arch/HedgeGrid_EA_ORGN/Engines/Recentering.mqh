//+------------------------------------------------------------------+
//| Recentering.mqh                                                   |
//| Keep fresh grid centered around current price                    |
//| Only active when no positions are open (fresh grid state)        |
//| Disabled permanently once first order is filled                  |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/DebugLogger.mqh"

// Track last candle time to only check once per candle
datetime g_lastRecenterCandle = 0;

//+------------------------------------------------------------------+
//| Check if recentering is needed                                   |
//| Formula:                                                         |
//|   recenter_threshold = InitialGap / ThresholdFactor             |
//|   x = (InitialGap - recenter_threshold) / 2                     |
//|   valid zone: anchorSell - x < price < anchorSell + x           |
//| Returns true if price is outside valid zone                      |
//+------------------------------------------------------------------+
bool CheckRecenterNeeded(double currentPrice, const GridState &state)
  {
   if(!InpEnableRecentering)  return false;
   if(state.cycleActive)      return false; // Only for fresh grid
   if(!state.gridPlaced)      return false; // No grid to recenter

   // Only check once per candle
   datetime currentCandle = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentCandle == g_lastRecenterCandle) return false;

   // Calculate valid zone
   double threshold = InpInitialGap / InpThresholdFactor;
   double x         = (InpInitialGap - threshold) / 2.0;

   double zoneLow  = state.anchorSell - x;
   double zoneHigh = state.anchorSell + x;

   bool outsideZone = (currentPrice < zoneLow || currentPrice > zoneHigh);

   if(outsideZone)
      LogDebug(StringFormat("Recenter check: price=%.2f zone=[%.2f,%.2f] OUTSIDE",
                            currentPrice, zoneLow, zoneHigh));

   return outsideZone;
  }

//+------------------------------------------------------------------+
//| Execute grid recentering                                         |
//| Delete all orders, rebuild grid around current price             |
//+------------------------------------------------------------------+
void RecenterGrid(double currentPrice, GridState &state)
  {
   double oldAnchor = state.anchorSell;

   // Mark candle as processed
   g_lastRecenterCandle = iTime(_Symbol, PERIOD_CURRENT, 0);

   // Delete all existing orders
   DeleteAllOrders(state.magicNumber);

   // Rebuild grid around current price
   // Note: GridBuilder is called from coordinator (HedgeGrid.mq5)
   // We just flag that rebuild is needed and reset anchor
   state.gridPlaced = false;

   LogRecentering(oldAnchor, currentPrice);
  }

//+------------------------------------------------------------------+
//| Master recentering check — call from OnTick                      |
//| Returns true if recentering was executed (grid needs rebuild)    |
//+------------------------------------------------------------------+
bool ProcessRecentering(GridState &state)
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!CheckRecenterNeeded(currentPrice, state)) return false;

   RecenterGrid(currentPrice, state);
   return true; // Signal to coordinator to call BuildGrid
  }

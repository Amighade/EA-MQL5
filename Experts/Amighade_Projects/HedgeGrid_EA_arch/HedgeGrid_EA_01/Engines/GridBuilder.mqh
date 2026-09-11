//+------------------------------------------------------------------+
//| GridBuilder.mqh                                                   |
//| Pluggable grid builder                                           |
//| Style A: Asymmetric ladder — lots increase per level             |
//| Style B: Symmetric fixed — all orders same lot size              |
//| Placement is always symmetric by candle direction                |
//+------------------------------------------------------------------+
#ifndef GRID_BUILDER_MQH
#define GRID_BUILDER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "SizingEngine.mqh"

//+------------------------------------------------------------------+
//| Place one pair of orders symmetrically                           |
//| If bullish candle: SELL first then BUY                           |
//| If bearish candle: BUY first then SELL                           |
//+------------------------------------------------------------------+
void PlaceOrderPair(double buyPrice, double buyLot, double sellPrice, double sellLot)
  {
   if(IsBullishCandle())
     {
      // Bullish: SELL stop first, then BUY stop
      PlaceSellStop(sellPrice, sellLot);
      PlaceBuyStop(buyPrice,   buyLot);
     }
   else
     {
      // Bearish: BUY stop first, then SELL stop
      PlaceBuyStop(buyPrice,   buyLot);
      PlaceSellStop(sellPrice, sellLot);
     }
  }

//+------------------------------------------------------------------+
//| Style A — Asymmetric ladder grid                                  |
//| BUY side: starts at price + InitialGap/2, lots increase per level|
//| SELL side: starts at price - InitialGap/2, lots increase per level|
//+------------------------------------------------------------------+
void BuildGrid_A(double price, ENUM_LOT_MODE lotMode, GridState &state)
  {
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);

   double firstBuyPrice  = NormalizeDouble(price + halfGap, _Digits);
   double firstSellPrice = NormalizeDouble(price - halfGap, _Digits);

   for(int level = 1; level <= maxLevels; level++)
     {
      double buyPrice  = NormalizeDouble(firstBuyPrice  + InpGridSpacing * (level - 1), _Digits);
      double sellPrice = NormalizeDouble(firstSellPrice - InpGridSpacing * (level - 1), _Digits);
      double lot       = GetLot(level, lotMode);

      PlaceOrderPair(buyPrice, lot, sellPrice, lot);
     }

   state.anchorBuy  = firstBuyPrice;
   state.anchorSell = firstSellPrice;
   state.gridPlaced = true;
   state.cycleActive = false;

   LogGridBuilt(firstBuyPrice, firstSellPrice, lotMode == LOT_FULL ? "FULL" : "HALF");
  }

//+------------------------------------------------------------------+
//| Style B — Symmetric fixed lot grid                                |
//| Both sides use InpFixedLot for all levels                        |
//+------------------------------------------------------------------+
void BuildGrid_B(double price, ENUM_LOT_MODE lotMode, GridState &state)
  {
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);
   double lot       = GetLot(1, lotMode); // Fixed lot same for all levels

   double firstBuyPrice  = NormalizeDouble(price + halfGap, _Digits);
   double firstSellPrice = NormalizeDouble(price - halfGap, _Digits);

   for(int level = 1; level <= maxLevels; level++)
     {
      double buyPrice  = NormalizeDouble(firstBuyPrice  + InpGridSpacing * (level - 1), _Digits);
      double sellPrice = NormalizeDouble(firstSellPrice - InpGridSpacing * (level - 1), _Digits);

      PlaceOrderPair(buyPrice, lot, sellPrice, lot);
     }

   state.anchorBuy  = firstBuyPrice;
   state.anchorSell = firstSellPrice;
   state.gridPlaced = true;
   state.cycleActive = false;

   LogGridBuilt(firstBuyPrice, firstSellPrice, lotMode == LOT_FULL ? "FULL" : "HALF");
  }

//+------------------------------------------------------------------+
//| Master function — calls correct style based on InpStrategyStyle  |
//+------------------------------------------------------------------+
void BuildGrid(double price, ENUM_LOT_MODE lotMode, GridState &state)
  {
   switch(InpStrategyStyle)
     {
      case STYLE_A: BuildGrid_A(price, lotMode, state); break;
      case STYLE_B: BuildGrid_B(price, lotMode, state); break;
      default:      BuildGrid_A(price, lotMode, state); break;
     }
  }


#endif
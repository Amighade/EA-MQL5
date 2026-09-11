//+------------------------------------------------------------------+
//| GridBuilder.mqh                                                   |
//| Pluggable grid builder                                           |
//| Style A: Asymmetric ladder — lots increase per level             |
//| Style B: Symmetric fixed — all orders same lot size              |
//| Placement always symmetric by current candle direction           |
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
//| Place one symmetric pair of orders                               |
//| Bullish candle: SELL first → BUY                                 |
//| Bearish candle: BUY first → SELL                                 |
//+------------------------------------------------------------------+
void PlaceOrderPair(double buyPrice, double buyLot,
                    double sellPrice, double sellLot,
                    int magicNumber)
{
   if(IsBullishCandle())
     {
      PlaceSellStop(sellPrice, sellLot, magicNumber);
      PlaceBuyStop(buyPrice,   buyLot,  magicNumber);
     }
   else
     {
      PlaceBuyStop(buyPrice,   buyLot,  magicNumber);
      PlaceSellStop(sellPrice, sellLot, magicNumber);
     }
}

//+------------------------------------------------------------------+
//| Style A — Asymmetric ladder                                      |
//| BUY side: starts at price + halfGap, lots increase per level     |
//| SELL side: starts at price - halfGap, lots increase per level    |
//+------------------------------------------------------------------+
void BuildGrid_A(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);

   double firstBuyPrice  = AlignToTick(_Symbol, price + halfGap);
   double firstSellPrice = AlignToTick(_Symbol, price - halfGap);

   for(int level = 1; level <= maxLevels; level++)
     {
      double buyPrice  = AlignToTick(_Symbol, firstBuyPrice  + InpGridSpacing * (level - 1));
      double sellPrice = AlignToTick(_Symbol, firstSellPrice - InpGridSpacing * (level - 1));
      double lot       = GetLot(level, lotMode);

      PlaceOrderPair(buyPrice, lot, sellPrice, lot, state.magicNumber);
     }

   state.anchorBuy  = firstBuyPrice;
   state.anchorSell = firstSellPrice;
   state.gridPlaced  = true;
   state.cycleActive = false;

   LogGridBuilt(firstBuyPrice, firstSellPrice, lotMode == LOT_FULL ? "FULL" : "HALF");
}

//+------------------------------------------------------------------+
//| Style B — Symmetric fixed lot                                    |
//| Both sides use InpFixedLot for all levels                        |
//+------------------------------------------------------------------+
void BuildGrid_B(double price, ENUM_LOT_MODE lotMode, GridState &state)
{
   double halfGap   = InpInitialGap / 2.0;
   int    maxLevels = GetMaxLevels(lotMode);
   double lot       = GetLot(1, lotMode); // Fixed — same for all levels

   double firstBuyPrice  = AlignToTick(_Symbol, price + halfGap);
   double firstSellPrice = AlignToTick(_Symbol, price - halfGap);

   for(int level = 1; level <= maxLevels; level++)
     {
      double buyPrice  = AlignToTick(_Symbol, firstBuyPrice  + InpGridSpacing * (level - 1));
      double sellPrice = AlignToTick(_Symbol, firstSellPrice - InpGridSpacing * (level - 1));

      PlaceOrderPair(buyPrice, lot, sellPrice, lot, state.magicNumber);
     }

   state.anchorBuy  = firstBuyPrice;
   state.anchorSell = firstSellPrice;
   state.gridPlaced  = true;
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

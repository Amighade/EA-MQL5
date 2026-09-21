//+------------------------------------------------------------------+
//| ShiftingEngine.mqh                                                |
//| Pluggable grid shifting after an order is hit                    |
//| Style A: Shift based on hit+2$ rule (delete all, rebuild)        |
//| Style B: Append new order at grid distance (no full rebuild)      |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "SizingEngine.mqh"

//+------------------------------------------------------------------+
//| Calculate new grid anchor for opposite side                      |
//| Rule: MAX of ($InitialGap/2 from price, $InitialGap from lastHit)|
//| The more conservative (further) distance always wins             |
//+------------------------------------------------------------------+
double CalculateNewAnchor(ENUM_ORDER_TYPE hitDirection, double currentPrice, double lastHitPrice)
  {
   double halfGap = InpInitialGap / 2.0;

   if(hitDirection == ORDER_TYPE_BUY)
     {
      // BUY was hit → shift SELL grid upward (closer to new price)
      double anchorByPrice   = currentPrice - halfGap;
      double anchorByLastHit = lastHitPrice - InpInitialGap;
      // Take the lower of the two (more conservative = further from price)
      return NormalizeDouble(MathMin(anchorByPrice, anchorByLastHit), _Digits);
     }
   else
     {
      // SELL was hit → shift BUY grid downward (closer to new price)
      double anchorByPrice   = currentPrice + halfGap;
      double anchorByLastHit = lastHitPrice + InpInitialGap;
      // Take the higher of the two (more conservative = further from price)
      return NormalizeDouble(MathMax(anchorByPrice, anchorByLastHit), _Digits);
     }
  }

//+------------------------------------------------------------------+
//| Delete all pending orders on the opposite side                   |
//+------------------------------------------------------------------+
void DeleteOppositeOrders(ENUM_ORDER_TYPE hitDirection, int magicNumber)
  {
   ENUM_ORDER_TYPE oppositeType = (hitDirection == ORDER_TYPE_BUY) ?
                                   ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != oppositeType) continue;
      DeleteOrder(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Rebuild opposite grid from new anchor                            |
//| Uses current block lot for all levels                            |
//| Uses symmetric placement by candle direction                     |
//+------------------------------------------------------------------+
void RebuildOppositeGrid(ENUM_ORDER_TYPE hitDirection, double newAnchor,
                         double blockLot, ENUM_LOT_MODE lotMode, GridState &state)
  {
   int maxLevels = GetMaxLevels(lotMode);
   bool isBullish = IsBullishCandle();

   if(hitDirection == ORDER_TYPE_BUY)
     {
      // Rebuilding SELL side — anchor is first (nearest) SELL STOP
      state.anchorSell = newAnchor;
      for(int level = 1; level <= maxLevels; level++)
        {
         double sellPrice = NormalizeDouble(newAnchor - InpGridSpacing * (level - 1), _Digits);
         PlaceSellStop(sellPrice, blockLot);
        }
     }
   else
     {
      // Rebuilding BUY side — anchor is first (nearest) BUY STOP
      state.anchorBuy = newAnchor;
      for(int level = 1; level <= maxLevels; level++)
        {
         double buyPrice = NormalizeDouble(newAnchor + InpGridSpacing * (level - 1), _Digits);
         PlaceBuyStop(buyPrice, blockLot);
        }
     }
  }

//+------------------------------------------------------------------+
//| Style A — Full delete and rebuild with 2$ constraint             |
//+------------------------------------------------------------------+
void ShiftGrid_A(GridState &state)
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double oldAnchor    = (state.lastHitDirection == ORDER_TYPE_BUY) ?
                          state.anchorSell : state.anchorBuy;

   double newAnchor = CalculateNewAnchor(state.lastHitDirection,
                                         currentPrice,
                                         state.lastHitPrice);

   DeleteOppositeOrders(state.lastHitDirection, state.magicNumber);
   RebuildOppositeGrid(state.lastHitDirection, newAnchor,
                       state.currentBlockLot, state.lotMode, state);

   LogGridShifted(state.lastHitDirection == ORDER_TYPE_BUY ? "SELL" : "BUY",
                  oldAnchor, newAnchor, state.currentBlockLot);
  }

//+------------------------------------------------------------------+
//| Style B — Append one new order at grid distance, no full rebuild  |
//+------------------------------------------------------------------+
void ShiftGrid_B(GridState &state)
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(state.lastHitDirection == ORDER_TYPE_BUY)
     {
      // BUY hit → add one more SELL STOP below current anchor
      double newSellPrice = NormalizeDouble(state.anchorSell - InpGridSpacing, _Digits);
      PlaceSellStop(newSellPrice, state.currentBlockLot);
      state.anchorSell = newSellPrice;
      LogGridShifted("SELL_APPEND", state.anchorSell, newSellPrice, state.currentBlockLot);
     }
   else
     {
      // SELL hit → add one more BUY STOP above current anchor
      double newBuyPrice = NormalizeDouble(state.anchorBuy + InpGridSpacing, _Digits);
      PlaceBuyStop(newBuyPrice, state.currentBlockLot);
      state.anchorBuy = newBuyPrice;
      LogGridShifted("BUY_APPEND", state.anchorBuy, newBuyPrice, state.currentBlockLot);
     }
  }

//+------------------------------------------------------------------+
//| Master function — calls correct style based on InpStrategyStyle  |
//+------------------------------------------------------------------+
void ShiftGrid(GridState &state)
  {
   switch(InpStrategyStyle)
     {
      case STYLE_A: ShiftGrid_A(state); break;
      case STYLE_B: ShiftGrid_B(state); break;
      default:      ShiftGrid_A(state); break;
     }
  }

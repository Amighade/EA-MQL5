//+------------------------------------------------------------------+
//| ShiftingEngine.mqh                                                |
//| Pluggable grid shifting after an order is hit                    |
//| Style A: Delete all opposite orders, rebuild at new anchor       |
//| Style B: Append one new order at grid distance (no full rebuild) |
//+------------------------------------------------------------------+
#ifndef SHIFTING_ENGINE_MQH
#define SHIFTING_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "SizingEngine.mqh"

//+------------------------------------------------------------------+
//| Calculate new anchor for opposite grid                           |
//| Rule: ALWAYS apply BOTH constraints, take more conservative      |
//|   Constraint 1: $InitialGap/2 from current price                |
//|   Constraint 2: $InitialGap from last hit order price           |
//+------------------------------------------------------------------+
double CalculateNewAnchor(ENUM_ORDER_TYPE hitDirection,
                          double currentPrice,
                          double lastHitPrice)
{
   double halfGap = InpInitialGap / 2.0;

   if(hitDirection == ORDER_TYPE_BUY)
     {
      // BUY hit → shift SELL grid: anchor is nearest SELL price
      double anchorByPrice   = currentPrice  - halfGap;
      double anchorByLastHit = lastHitPrice  - InpInitialGap;
      // Take lower (more conservative = further from price = safer gap)
      return AlignToTick(_Symbol, MathMin(anchorByPrice, anchorByLastHit));
     }
   else
     {
      // SELL hit → shift BUY grid: anchor is nearest BUY price
      double anchorByPrice   = currentPrice  + halfGap;
      double anchorByLastHit = lastHitPrice  + InpInitialGap;
      // Take higher (more conservative)
      return AlignToTick(_Symbol, MathMax(anchorByPrice, anchorByLastHit));
     }
}

//+------------------------------------------------------------------+
//| Delete all pending orders on the opposite side                   |
//+------------------------------------------------------------------+
void DeleteOppositeOrders(ENUM_ORDER_TYPE hitDirection, int magicNumber)
{
   ENUM_ORDER_TYPE oppositeType = (hitDirection == ORDER_TYPE_BUY) ?
                                   ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;

   for(int i = OrdersTotal()-1; i >= 0; i--)
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
//| Uses currentBlockLot for all levels                              |
//| Symmetric placement by candle direction                          |
//+------------------------------------------------------------------+
void RebuildOppositeGrid(ENUM_ORDER_TYPE hitDirection,
                         double newAnchor,
                         double blockLot,
                         ENUM_LOT_MODE lotMode,
                         GridState &state)
{
   int maxLevels = GetMaxLevels(lotMode);

   if(hitDirection == ORDER_TYPE_BUY)
     {
      // Rebuilding SELL side — anchor is nearest SELL STOP
      state.anchorSell = newAnchor;
      for(int level = 1; level <= maxLevels; level++)
        {
         double sellPrice = AlignToTick(_Symbol, newAnchor - InpGridSpacing * (level - 1));
         PlaceSellStop(sellPrice, blockLot, state.magicNumber);
        }
     }
   else
     {
      // Rebuilding BUY side — anchor is nearest BUY STOP
      state.anchorBuy = newAnchor;
      for(int level = 1; level <= maxLevels; level++)
        {
         double buyPrice = AlignToTick(_Symbol, newAnchor + InpGridSpacing * (level - 1));
         PlaceBuyStop(buyPrice, blockLot, state.magicNumber);
        }
     }
}

//+------------------------------------------------------------------+
//| Style A — Full delete and rebuild with 2-distance constraint     |
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
//| Style B — Append one new order, no full rebuild                  |
//+------------------------------------------------------------------+
void ShiftGrid_B(GridState &state)
{
   if(state.lastHitDirection == ORDER_TYPE_BUY)
     {
      // BUY hit → append one more SELL STOP below current anchor
      double newSellPrice = AlignToTick(_Symbol, state.anchorSell - InpGridSpacing);
      PlaceSellStop(newSellPrice, state.currentBlockLot, state.magicNumber);
      double oldAnchor    = state.anchorSell;
      state.anchorSell    = newSellPrice;
      LogGridShifted("SELL_APPEND", oldAnchor, newSellPrice, state.currentBlockLot);
     }
   else
     {
      // SELL hit → append one more BUY STOP above current anchor
      double newBuyPrice = AlignToTick(_Symbol, state.anchorBuy + InpGridSpacing);
      PlaceBuyStop(newBuyPrice, state.currentBlockLot, state.magicNumber);
      double oldAnchor   = state.anchorBuy;
      state.anchorBuy    = newBuyPrice;
      LogGridShifted("BUY_APPEND", oldAnchor, newBuyPrice, state.currentBlockLot);
     }
}

//+------------------------------------------------------------------+
//| Master function — calls correct style based on InpStrategyStyle  |
//| Style C: skips entirely — no grid shifting in persistent grid    |
//+------------------------------------------------------------------+
void ShiftGrid(GridState &state)
{
   // Style C grid is persistent — no shifting ever
   if(InpStrategyStyle == STYLE_C) return;

   switch(InpStrategyStyle)
     {
      case STYLE_A: ShiftGrid_A(state); break;
      case STYLE_B: ShiftGrid_B(state); break;
      default:      ShiftGrid_A(state); break;
     }
}

#endif

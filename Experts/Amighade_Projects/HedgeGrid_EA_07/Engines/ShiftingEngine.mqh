//+------------------------------------------------------------------+
//| ShiftingEngine.mqh                                                |
//| BRICK 2: shift the opposite-side grid after a hit leaves a gap.  |
//| Gated by InpEnableShifting. Anchor computed by InpShiftAnchor —  |
//| exactly one of the three modes, no more "take the more            |
//| conservative of two" hybrid (that behavior has been retired).    |
//| NOTE: keep InpEnableShifting = false when either refill brick is |
//| enabled — not auto-enforced, user's responsibility.               |
//+------------------------------------------------------------------+
#ifndef SHIFTING_ENGINE_MQH
#define SHIFTING_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/SizingUtils.mqh"

//+------------------------------------------------------------------+
//| Calculate new anchor for the opposite (gapped) side, using        |
//| exactly one anchor rule per InpShiftAnchor.                      |
//+------------------------------------------------------------------+
double CalculateNewAnchor(ENUM_ORDER_TYPE hitDirection,
                          double currentPrice,
                          GridState &state)
{
   double halfGap = InpInitialGap / 2.0;
   bool   buyHit  = (hitDirection == ORDER_TYPE_BUY);

   double anchor;

   switch(InpShiftAnchor)
     {
      case SHIFT_LAST_HIT:
         anchor = buyHit ? (state.lastHitPrice - InpInitialGap)
                          : (state.lastHitPrice + InpInitialGap);
         break;

      case SHIFT_FARTHEST_HIT:
         anchor = buyHit ? (state.farthestHitBuy  - InpInitialGap)
                          : (state.farthestHitSell + InpInitialGap);
         break;

      case SHIFT_PRICE:
      default:
         anchor = buyHit ? (currentPrice - halfGap)
                          : (currentPrice + halfGap);
         break;
     }

   return AlignToTick(_Symbol, anchor);
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
//| Rebuild opposite grid from new anchor, price-outward in order    |
//| (single-side placement — pairing happens at the initial build,   |
//| a shift only ever touches one side by definition).               |
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
//| Master entry point. No-op unless InpEnableShifting is true.      |
//+------------------------------------------------------------------+
void ShiftGrid(GridState &state)
{
   if(!InpEnableShifting) return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double oldAnchor     = (state.lastHitDirection == ORDER_TYPE_BUY) ?
                          state.anchorSell : state.anchorBuy;

   double newAnchor = CalculateNewAnchor(state.lastHitDirection, currentPrice, state);

   DeleteOppositeOrders(state.lastHitDirection, state.magicNumber);
   RebuildOppositeGrid(state.lastHitDirection, newAnchor,
                       state.currentBlockLot, state.lotMode, state);

   LogGridShifted(state.lastHitDirection == ORDER_TYPE_BUY ? "SELL" : "BUY",
                  oldAnchor, newAnchor, state.currentBlockLot);
}

#endif

//+------------------------------------------------------------------+
//| SafetyNet.mqh                                                      |
//| Universal broker-fault / risk response, used by every engine and |
//| by the manual emergency-close button.                             |
//|                                                                    |
//| Lives in Utils (not an engine) so any engine can call it without  |
//| crossing into another engine's file. Depends only on Utils-level  |
//| helpers (TradeUtils, CloseOrderUtils, TelegramUtils, DebugLogger).|
//|                                                                    |
//| Triggers (per design discussion):                                 |
//|   - A trade-modifying call exhausts its retries (see TradeUtils)  |
//|   - A gap-fault is detected (price skipped a level without a fill)|
//|   - An SL modification fails outright (Bug 4/6 extension)         |
//|   - The user presses the dashboard Emergency Close button         |
//|                                                                    |
//| Behavior is always identical regardless of trigger: close every   |
//| position (zigzag profit order), delete every pending order        |
//| (proximity order), reset all cycle state, alert via Telegram.     |
//| The next candle-open check (Engines/GridLifecycle.mqh) rebuilds   |
//| the grid automatically — no special-casing needed here.           |
//+------------------------------------------------------------------+
#ifndef SAFETY_NET_MQH
#define SAFETY_NET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "DebugLogger.mqh"
#include "TradeUtils.mqh"
#include "CloseOrderUtils.mqh"
#include "TelegramUtils.mqh"

//+------------------------------------------------------------------+
//| Universal safety stop. Call from anywhere a critical trade         |
//| operation has definitively failed, or on manual emergency close. |
//+------------------------------------------------------------------+
void TriggerSafetyStop(GridState &state, string reason)
  {
   LogDebug(StringFormat("[SafetyNet] TRIGGERED. Reason=%s. Closing everything.", reason));

   // --- Close positions first (closing always outranks opening/modifying) ---
   ulong posOrder[];
   BuildAbsProfitPositionOrder(state.magicNumber, posOrder);   // was BuildZigzagPositionOrder
   int closedCount = 0, closeFailCount = 0;
   for(int i = 0; i < ArraySize(posOrder); i++)
     {
      if(ClosePosition(posOrder[i])) closedCount++;
      else                           closeFailCount++;
     }

   // --- Delete all pending orders ---
   ulong ordOrder[];
   BuildProximityOrderOrder(state.magicNumber, ordOrder);
   int deletedCount = 0, deleteFailCount = 0;
   for(int i = 0; i < ArraySize(ordOrder); i++)
     {
      if(DeleteOrder(ordOrder[i])) deletedCount++;
      else                         deleteFailCount++;
     }

   string summary = StringFormat(
      "HedgeGrid SAFETY STOP\nSymbol: %s\nReason: %s\nPositions closed: %d (failed: %d)\nOrders deleted: %d (failed: %d)\nTime: %s",
      _Symbol, reason, closedCount, closeFailCount, deletedCount, deleteFailCount,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));

   LogDebug("[SafetyNet] " + summary);
   //Alert(summary);
   SendTelegramMessage(summary);

   // --- Reset all cycle state so the next candle-open check rebuilds fresh ---
   int savedMagic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = savedMagic;
   state.gridPlaced  = false; // explicit: next new-bar check builds a fresh grid
  }

#endif

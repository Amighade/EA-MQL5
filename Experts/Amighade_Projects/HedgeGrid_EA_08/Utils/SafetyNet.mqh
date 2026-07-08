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
//| Close-everything mechanics only — no alert, no state reset.      |
//| Returns true once nothing was left to close/delete this pass     |
//| (does NOT guarantee flat if a close/delete failed — caller       |
//| checks CountPositions/CountOrders itself if it needs certainty). |
//| Used both by TriggerSafetyStop (below) and by MODE_SHUTDOWN's    |
//| per-tick retry loop, which must NOT alert on every single tick.  |
//+------------------------------------------------------------------+
bool SilentCloseAll(int magicNumber, int &closedCount, int &closeFailCount,
                    int &deletedCount, int &deleteFailCount)
  {
   closedCount = closeFailCount = deletedCount = deleteFailCount = 0;

   ulong posOrder[];
   BuildZigzagPositionOrder(magicNumber, posOrder);
   for(int i = 0; i < ArraySize(posOrder); i++)
     {
      if(ClosePosition(posOrder[i])) closedCount++;
      else                           closeFailCount++;
     }

   ulong ordOrder[];
   BuildProximityOrderOrder(magicNumber, ordOrder);
   for(int i = 0; i < ArraySize(ordOrder); i++)
     {
      if(DeleteOrder(ordOrder[i])) deletedCount++;
      else                         deleteFailCount++;
     }

   return (ArraySize(posOrder) == 0 && ArraySize(ordOrder) == 0);
  }

//+------------------------------------------------------------------+
//| Universal safety stop — the LOUD path (alerts + Telegram + full  |
//| state reset). Call from anywhere a critical trade operation has  |
//| definitively failed, or on manual/mode-switch emergency close.   |
//| Do NOT call this from a per-tick retry loop — use SilentCloseAll |
//| for repeated attempts once the first alert has already fired.    |
//+------------------------------------------------------------------+
void TriggerSafetyStop(GridState &state, string reason)
  {
   LogDebug(StringFormat("[SafetyNet] TRIGGERED. Reason=%s. Closing everything.", reason));

   int closedCount, closeFailCount, deletedCount, deleteFailCount;
   SilentCloseAll(state.magicNumber, closedCount, closeFailCount, deletedCount, deleteFailCount);

   string summary = StringFormat(
      "HedgeGrid SAFETY STOP\nSymbol: %s\nReason: %s\nPositions closed: %d (failed: %d)\nOrders deleted: %d (failed: %d)\nTime: %s",
      _Symbol, reason, closedCount, closeFailCount, deletedCount, deleteFailCount,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));

   LogDebug("[SafetyNet] " + summary);
   Alert(summary);
   SendTelegramMessage(summary);

   // --- Reset all cycle state so the next candle-open check rebuilds fresh ---
   // NOTE: mode / shutdownFlat are NOT touched by ResetGridState (by design —
   // see Models/GridState.mqh) so a Shutdown-triggered close can never bounce
   // the mode back to Running.
   int savedMagic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = savedMagic;
   state.gridPlaced  = false; // explicit: next new-bar check builds a fresh grid
  }

#endif

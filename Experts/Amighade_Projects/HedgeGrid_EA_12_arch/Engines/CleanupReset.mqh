//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                  |
//| BRICK 7: what "cleanup" means once SL hits (all winners closed)  |
//| or a broker fault/manual emergency fires.                        |
//|                                                                    |
//| Manual/broker-fault emergency close is now fully unified — it     |
//| just calls Utils/SafetyNet's TriggerSafetyStop, which always      |
//| closes everything and lets the next candle-open check rebuild.   |
//| No more per-style branching (see HedgeGrid_Info.md changelog).   |
//|                                                                    |
//| Normal SL-triggered cleanup respects InpCleanupMode:               |
//|   CLEANUP_CLOSE_ALL       — delete all orders, close all          |
//|                              remaining positions, full reset.     |
//|   CLEANUP_CLOSE_POSITIONS — close remaining positions only,       |
//|                              leave pending orders in place.       |
//| Both close positions in the zigzag profit order (most positive,   |
//| most negative, alternating — ticket order tie-break), one         |
//| position per OnTradeTransaction confirmation (Closing always      |
//| outranks opening/modifying — cleanupInProgress gates every other  |
//| brick off until this completes).                                  |
//+------------------------------------------------------------------+
#ifndef CLEANUP_RESET_MQH
#define CLEANUP_RESET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/CloseOrderUtils.mqh"
#include "../Utils/SafetyNet.mqh"
#include "../Utils/PositionOrderSnapshot.mqh"

//+------------------------------------------------------------------+
//| Full state reset, preserving the magic number.                   |
//| NOTE: does not touch SLManager's armed-winner set — that is      |
//| SLManager's own state. The coordinator calls ResetSLManager()    |
//| itself alongside this (no engine reaches into another engine).   |
//+------------------------------------------------------------------+
void ResetCycle(GridState &state)
{
   int magic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = magic;
}

//+------------------------------------------------------------------+
//| Universal emergency close — manual button or any broker-fault    |
//| safety trigger. Always closes everything, no branching.          |
//| NOTE: coordinator also calls ResetSLManager() alongside this.    |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose(GridState &state)
{
   TriggerSafetyStop(state, "EMERGENCY_CLOSE");
}

//+------------------------------------------------------------------+
//| Begin the confirmation-based cleanup sequence after an SL hit.    |
//+------------------------------------------------------------------+
void StartCleanupSequence(GridState &state)
{
   LogCleanupStarted(EnumToString(InpCleanupMode));

   // Order deletion moved to ExecuteNextCloseStep's completion branch —
   // positions must finish closing first. See there for CLEANUP_CLOSE_ALL handling.

   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
   state.closeIndex = 0;

   state.cleanupType        = InpCleanupMode;
   state.cleanupInProgress  = true;
   state.cleanupStep        = 0;
}

//+------------------------------------------------------------------+
//| Close exactly one position per call, in zigzag profit order.     |
//| Returns true once the whole cleanup sequence is complete.        |
//+------------------------------------------------------------------+
bool ExecuteNextCloseStep(GridState &state)
{
   if(!state.cleanupInProgress) return true;

   // Skip any ticket that closed externally (SL/TP/manual) since the array was built
   while(state.closeIndex < ArraySize(state.closeSequence) &&
         !PositionSelectByTicket(state.closeSequence[state.closeIndex]))
      state.closeIndex++;

   if(state.closeIndex >= ArraySize(state.closeSequence))
     {
      // Array drained — rescan for anything left before declaring done
      BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
      state.closeIndex = 0;

      if(ArraySize(state.closeSequence) == 0)
        {
         // Genuinely empty now — orders close after positions, same as you asked
         if(state.cleanupType == CLEANUP_CLOSE_ALL)
            DeleteAllOrders(state.magicNumber);   // unchanged function, unchanged internal order

         state.cleanupInProgress = false;
         state.cleanupStep       = 0;

         if(state.cleanupType == CLEANUP_CLOSE_ALL)
           {
            ResetCycle(state);
            state.gridPlaced = false; // next candle-open check rebuilds
           }
         else // CLEANUP_CLOSE_POSITIONS — orders survive, grid stays "placed"
           {
            state.cycleActive = false;
            if(InpInsideMaintenanceStyle != MAINTENANCE_NONE)
              {
               state.refillNeeded = true;
               ProcessInsideMaintenance(state);
               state.refillNeeded = false;
              }
           }

         LogCleanupComplete();
         return true;
        }
      // rescan found something — fall through, close from the refreshed array below
     }

   ClosePosition(state.closeSequence[state.closeIndex]);
   RefreshPositionSnapshot(state);
   state.closeIndex++;
   state.cleanupStep++;
   return false;
}

#endif

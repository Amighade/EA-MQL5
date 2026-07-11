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

   if(InpCleanupMode == CLEANUP_CLOSE_ALL)
      DeleteAllOrders(state.magicNumber);
   // CLEANUP_CLOSE_POSITIONS: orders are intentionally left in place

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

   ulong sequence[];
   BuildZigzagPositionOrder(state.magicNumber, sequence);

   if(ArraySize(sequence) == 0)
     {
      // Cleanup complete
      state.cleanupInProgress = false;
      state.cleanupStep       = 0;
      // NOTE: coordinator calls ResetSLManager() right after this returns true.refillNeeded = true

      if(state.cleanupType == CLEANUP_CLOSE_ALL)
        {
         ResetCycle(state);
         state.gridPlaced = false; // next candle-open check rebuilds
        }
      else // CLEANUP_CLOSE_POSITIONS — orders survive, grid stays "placed"
        {
         state.cycleActive = false;
         if(InpEnableRefillInside || InpEnableRefillOutside)
            state.refillNeeded = true;
        }

      LogCleanupComplete();
      return true;
     }

   ClosePosition(sequence[0]);
   state.cleanupStep++;
   return false;
}

#endif

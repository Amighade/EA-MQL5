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

   // 1. Force a real-time rescan of the terminal instead of trusting an internal index counter
   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
   
   // 2. If the array is completely empty, positions are gone!
   if(ArraySize(state.closeSequence) == 0)
     {
      if(state.cleanupType == CLEANUP_CLOSE_ALL)
        {
         // Cross-verify that pending limit orders are truly gone before releasing the lock
         int orderCount = 0;
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            if(OrderGetTicket(i) > 0 && OrderGetInteger(ORDER_MAGIC) == state.magicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol)
               orderCount++;
           }
           
         if(orderCount > 0)
           {
            DeleteAllOrders(state.magicNumber); // Keep sending delete calls
            return false; // STAY LOCKED. Do not let cleanupInProgress become false yet!
           }
           
         ResetCycle(state);
         state.gridPlaced = false;
        }
      else
        {
         state.cycleActive = false;
         if(InpInsideMaintenanceStyle != MAINTENANCE_NONE)
           {
            state.refillNeeded = true;
            ProcessInsideMaintenance(state);
            state.refillNeeded = false;
           }
        }

      // ONLY turn off the cleanup shield when both positions AND pending orders are verified 0
      state.cleanupInProgress = false;
      state.cleanupStep       = 0;
      LogCleanupComplete();
      return true;
     }
     
   // 3. LOGIC FIX: Always attack the first item at index 0.
   // If a pending order executes meanwhile, BuildAbsProfitPositionOrder will add it 
   // to this array on the next pulse, forcing the EA to close it before exiting cleanup.
   if(PositionSelectByTicket(state.closeSequence[0]))
     {
      ClosePosition(state.closeSequence[0]);
      state.cleanupStep++;
     }
   return false;
}

#endif

//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                  |
//| BRICK 7: what "cleanup" means once SL hits (all winners closed)  |
//| or a broker fault/manual emergency fires.                        |
//|                                                                    |
//| Manual/broker-fault emergency close is now fully unified — it     |
//| just calls Utils/SafetyNet's TriggerSafetyStop, which always      |
//| closes everything and lets the medium timer check rebuild.   |
//| No more per-style branching (see HedgeGrid_Info.md changelog).   |
//|                                                                    |
//| Both close positions in the zigzag profit order (most positive,   |
//| most negative, alternating — ticket order tie-break), one         |
//| position per broker confirmation (Closing always                  |
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
void StartCleanupSequence_old(GridState &state)
{
   g_cleanupAdvancePending = false;

   // Order deletion moved to ExecuteNextCloseStep's completion branch —
   // positions must finish closing first. See there for CLEANUP_CLOSE_ALL handling.

   //BuildAbsProfitPositionOrder(state, state.closeSequence);ongoing
   BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
   state.closeIndex = 0;

   state.cleanupInProgress  = true;
   state.cleanupStep        = 0;
}

void StartCleanupSequence(GridState &state)
{
   if(state.cleanupInProgress)
      return;

   state.closeIndex = ArraySize(state.positionItems) - 1;
   state.cleanupInProgress = true;
   state.cleanupStep = 0;
   g_cleanupAdvancePending = true;
}
//+------------------------------------------------------------------+
//| Close exactly one position per call, in zigzag profit order.     |
//| Returns true once the whole cleanup sequence is complete.        |
//+------------------------------------------------------------------+
bool ExecuteNextCloseStep(GridState &state)
{
   if(!state.cleanupInProgress)
      return true;

   g_cleanupAdvancePending = false;


   // Send at most one position-close request per call.
   if(state.closeIndex >= 0)
     {
      ulong ticket = state.positionItems[state.closeIndex].ticket;

      ClosePosition(ticket);

      // Advance only after this position is actually gone.
      if(!PositionSelectByTicket(ticket))
        {
         state.closeIndex--;
         state.cleanupStep++;
        }

      return false;
     }

   // Stored positions are exhausted. Remove pending orders.
   DeleteAllOrders(state.magicNumber);
   bool ordersRemain = (CountOrders(state.magicNumber) > 0);

   // Final live scan: collect any positions missed by the stored list,
   // including pending orders that filled during cleanup.
   int total = PositionsTotal();

   if(ArrayResize(state.positionItems, total, 16) != total)
      return false;

   int count = 0;

   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber)
         continue;

      state.positionItems[count].identifier =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      state.positionItems[count].ticket = ticket;
      state.positionItems[count].side =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      state.positionItems[count].entryPrice =
         PositionGetDouble(POSITION_PRICE_OPEN);
      state.positionItems[count].volume =
         PositionGetDouble(POSITION_VOLUME);

      count++;
     }

   ArrayResize(state.positionItems, count);
   state.closeIndex = count - 1;

   // Continue cleanup if either broker collection was nonempty.
   if(count > 0 || ordersRemain)
      return false;

   if(CountPositions(state.magicNumber) > 0 ||
   CountOrders(state.magicNumber) > 0)
   return false;
   
   g_cleanupAdvancePending = false;
   ResetCycle(state);
   LogCleanupComplete();
   return true;
}

bool ExecuteNextCloseStep_old(GridState &state)
{
   if(!state.cleanupInProgress) return true;

   // Skip any ticket that closed externally (SL/TP/manual) since the array was built
   while(state.closeIndex < ArraySize(state.closeSequence) &&
         !PositionSelectByTicket(state.closeSequence[state.closeIndex]))
      state.closeIndex++;

   if(state.closeIndex >= ArraySize(state.closeSequence))
     {
      // Array drained — rescan for anything left before declaring done
      //BuildAbsProfitPositionOrder(state, state.closeSequence); ongoing
      BuildAbsProfitPositionOrder(state.magicNumber, state.closeSequence);
      state.closeIndex = 0;

      if(ArraySize(state.closeSequence) == 0)
        {
         // Genuinely empty now — orders close after positions, same as you asked
         DeleteAllOrders(state.magicNumber);        
         /*if(CountOrders(state.magicNumber) > 0)
            return false; // wait for broker confirmation or a failed-send retry*/
//         
         if(CountPositions(state.magicNumber) > 0 ||
            CountOrders(state.magicNumber) > 0)
            return false;
//  
         g_cleanupAdvancePending = false;
         state.cleanupInProgress = false;
         state.cleanupStep       = 0;
         ResetCycle(state);
         state.gridPlaced = false; // medium timer check may rebuild

         LogCleanupComplete();
         return true;
        }
      // rescan found something — fall through, close from the refreshed array below
     }

   ulong ticket = state.closeSequence[state.closeIndex];
   if(!ClosePosition(ticket) && PositionSelectByTicket(ticket))
     {
      if(!g_lastCloseRequestAccepted)
         g_cleanupAdvancePending = true;
      return false;
     }

   state.closeIndex++;
   state.cleanupStep++;
   return false;
}

#endif

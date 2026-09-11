//+------------------------------------------------------------------+
//| CleanupReset_C.mqh                                               |
//| Style C: SL hit handler                                          |
//|                                                                  |
//| On SL hit:                                                       |
//|   1. Close remaining positions (confirmation-based)              |
//|   2. Keep ALL pending orders                                     |
//|   3. Check refill condition → trigger GridFiller_C if needed    |
//|   4. Reset SL manager state                                      |
//+------------------------------------------------------------------+
#ifndef CLEANUP_RESET_C_MQH
#define CLEANUP_RESET_C_MQH

#include "../../Inputs.mqh"
#include "../../Models/GridState.mqh"
#include "../../Utils/TradeUtils.mqh"
#include "../../Utils/DebugLogger.mqh"
#include "SLManager_C.mqh"
#include "GridFiller_C.mqh"

//+------------------------------------------------------------------+
//| Close all open positions only — do NOT touch pending orders      |
//| Uses confirmation-based sequence (one per OnTradeTransaction)    |
//+------------------------------------------------------------------+
void ClosePositionsOnly_C(GridState &state)
{
   LogDebug("[CleanupReset_C] Closing positions only — keeping pending orders.");

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)              continue;
      if(PositionGetInteger(POSITION_MAGIC)  != state.magicNumber)    continue;
      ClosePosition(ticket);
     }
}

//+------------------------------------------------------------------+
//| Execute next confirmation-based close step for Style C           |
//| Returns true when all positions closed                           |
//+------------------------------------------------------------------+
bool ExecuteNextCloseStep_C(GridState &state)
{
   if(!state.cleanupInProgress) return true;

   // Check if any positions remain
   int remaining = CountPositions(state.magicNumber);

   if(remaining == 0)
     {
      // All positions closed — run refill check
      LogDebug("[CleanupReset_C] All positions closed. Checking refill...");
      CheckAndRefill(state);

      // Reset cleanup state
      state.cleanupInProgress = false;
      state.cleanupStep       = 0;
      state.slApplied         = false;

      // Reset SL manager for next cycle
      ResetSLManager_C();

      LogCleanupComplete();
      return true;
     }

   // Close next position (sorted: biggest positive first)
   double biggestProfit  = -DBL_MAX;
   ulong  targetTicket   = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)           continue;
      if(PositionGetInteger(POSITION_MAGIC)  != state.magicNumber) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit > biggestProfit)
        {
         biggestProfit = profit;
         targetTicket  = ticket;
        }
     }

   if(targetTicket > 0)
     {
      ClosePosition(targetTicket);
      state.cleanupStep++;
     }

   return false;
}

//+------------------------------------------------------------------+
//| Start Style C cleanup — triggered when SL hit detected           |
//+------------------------------------------------------------------+
void StartCleanup_C(GridState &state)
{
   LogCleanupStarted("STYLE_C_SL_HIT");

   // Do NOT delete pending orders — this is Style C key difference
   state.cleanupInProgress = true;
   state.cleanupStep       = 0;

   // Close all positions immediately (fire all at once, confirmations handled in OnTradeTransaction)
   ClosePositionsOnly_C(state);
}

//+------------------------------------------------------------------+
//| Emergency close for Style C (manual button only)                 |
//| Closes everything including orders                               |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose_C(GridState &state)
{
   LogCleanupStarted("STYLE_C_EMERGENCY");

   // Emergency: close positions AND delete orders
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)           continue;
      if(PositionGetInteger(POSITION_MAGIC)  != state.magicNumber) continue;
      ClosePosition(ticket);
     }

   DeleteAllOrders(state.magicNumber);
   ResetSLManager_C();

   state.cleanupInProgress = false;
   state.cleanupStep       = 0;
   state.slApplied         = false;

   LogCleanupComplete();
}

#endif

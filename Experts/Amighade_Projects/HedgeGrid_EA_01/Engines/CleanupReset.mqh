//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                  |
//| Close all positions and orders, reset cycle state                |
//| Uses confirmation-based close sequence (one close per call)      |
//| Called repeatedly by OnTradeTransaction until all closed         |
//+------------------------------------------------------------------+
#ifndef CLEANUP_RESET_MQH
#define CLEANUP_RESET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| EMERGENCY CLOSE — close everything immediately, no sequence      |
//| Use for: manual button, gap fault, critical margin               |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose(GridState &state)
  {
   LogCleanupStarted("EMERGENCY");

   // Delete all pending orders first
   DeleteAllOrders(state.magicNumber);

   // Close all positions immediately (no sequence)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;
      ClosePosition(ticket);
     }

   state.cleanupInProgress = false;
   LogCleanupComplete();
  }

//+------------------------------------------------------------------+
//| Build sorted close list for confirmation-based sequence          |
//| Sort: biggest positive profit first, then biggest negative       |
//| Alternating: +profit, -profit, +profit, -profit ...             |
//| Returns total count of positions to close                        |
//+------------------------------------------------------------------+
int BuildCloseSequence(int magicNumber, ulong &sequence[])
  {
   // Collect all positions
   ulong   tickets[];
   double  profits[];
   int     count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;

      ArrayResize(tickets, count + 1);
      ArrayResize(profits, count + 1);
      tickets[count] = ticket;
      profits[count] = PositionGetDouble(POSITION_PROFIT);
      count++;
     }

   // Separate positives and negatives, sort each descending by absolute value
   ulong  posTickets[];  double posProfit[];  int posCount = 0;
   ulong  negTickets[];  double negProfit[];  int negCount = 0;

   for(int i = 0; i < count; i++)
     {
      if(profits[i] >= 0)
        {
         ArrayResize(posTickets, posCount + 1);
         ArrayResize(posProfit,  posCount + 1);
         posTickets[posCount] = tickets[i];
         posProfit[posCount]  = profits[i];
         posCount++;
        }
      else
        {
         ArrayResize(negTickets, negCount + 1);
         ArrayResize(negProfit,  negCount + 1);
         negTickets[negCount] = tickets[i];
         negProfit[negCount]  = profits[i];
         negCount++;
        }
     }

   // Simple bubble sort positives descending
   for(int i = 0; i < posCount - 1; i++)
      for(int j = 0; j < posCount - i - 1; j++)
         if(posProfit[j] < posProfit[j+1])
           {
            double tmpP = posProfit[j];  posProfit[j]  = posProfit[j+1];  posProfit[j+1]  = tmpP;
            ulong  tmpT = posTickets[j]; posTickets[j] = posTickets[j+1]; posTickets[j+1] = tmpT;
           }

   // Simple bubble sort negatives ascending (biggest loss first)
   for(int i = 0; i < negCount - 1; i++)
      for(int j = 0; j < negCount - i - 1; j++)
         if(negProfit[j] > negProfit[j+1])
           {
            double tmpP = negProfit[j];  negProfit[j]  = negProfit[j+1];  negProfit[j+1]  = tmpP;
            ulong  tmpT = negTickets[j]; negTickets[j] = negTickets[j+1]; negTickets[j+1] = tmpT;
           }

   // Interleave: biggest positive, biggest negative, next positive, next negative...
   ArrayResize(sequence, count);
   int seqIdx = 0;
   int p = 0, n = 0;
   while(p < posCount || n < negCount)
     {
      if(p < posCount) sequence[seqIdx++] = posTickets[p++];
      if(n < negCount) sequence[seqIdx++] = negTickets[n++];
     }

   return count;
  }

//+------------------------------------------------------------------+
//| Start confirmation-based cleanup sequence                        |
//| Sets up state for step-by-step closing via OnTradeTransaction    |
//+------------------------------------------------------------------+
void StartCleanupSequence(ENUM_CLEANUP_TYPE cleanupType, GridState &state)
  {
   LogCleanupStarted(EnumToString(cleanupType));

   // Delete all pending orders immediately
   DeleteAllOrders(state.magicNumber);

   state.cleanupInProgress = true;
   state.cleanupStep       = 0;
   state.cleanupType       = cleanupType;
  }

//+------------------------------------------------------------------+
//| Execute next step in confirmation-based close sequence           |
//| Call this from OnTradeTransaction after each confirmed close     |
//| Returns true if cleanup is complete                              |
//+------------------------------------------------------------------+
bool ExecuteNextCloseStep(GridState &state)
  {
   if(!state.cleanupInProgress) return true;

   // Build current close sequence (re-built each step as positions reduce)
   ulong sequence[];
   int   remaining = BuildCloseSequence(state.magicNumber, sequence);

   if(remaining == 0)
     {
      // All positions closed
      state.cleanupInProgress = false;
      state.cleanupStep       = 0;
      LogCleanupComplete();
      return true;
     }

   // Close the next position in sequence
   ClosePosition(sequence[0]);
   state.cleanupStep++;

   return false; // Not done yet
  }

//+------------------------------------------------------------------+
//| Full state reset after cleanup complete                          |
//| Call this after ExecuteNextCloseStep returns true                |
//+------------------------------------------------------------------+
void ResetCycle(GridState &state)
  {
   bool keepMagic = true;
   int  magic     = state.magicNumber; // Preserve magic number across cycles

   ResetGridState(state);

   if(keepMagic)
      state.magicNumber = magic;
  }


#endif
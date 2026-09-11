//+------------------------------------------------------------------+
//| CleanupReset.mqh                                                  |
//| Close all positions/orders and reset cycle state                 |
//| Confirmation-based: one close per OnTradeTransaction call        |
//+------------------------------------------------------------------+
#ifndef CLEANUP_RESET_MQH
#define CLEANUP_RESET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
// Style C cleanup — included here so CleanupReset master functions can route to it
#include "StyleC/CleanupReset_C.mqh"

//+------------------------------------------------------------------+
//| EMERGENCY CLOSE — close everything immediately, no sequence      |
//| Style C: also closes all pending orders (full reset)            |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose(GridState &state)
{
   // Style C emergency: delegate to CleanupReset_C which handles it correctly
   if(InpStrategyStyle == STYLE_C)
     {
      ExecuteEmergencyClose_C(state);
      return;
     }

   LogCleanupStarted("EMERGENCY");

   DeleteAllOrders(state.magicNumber);

   for(int i = PositionsTotal()-1; i >= 0; i--)
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
//| Build alternating close sequence                                 |
//| Order: biggest positive → biggest negative → next positive...   |
//+------------------------------------------------------------------+
int BuildCloseSequence(int magicNumber, ulong &sequence[])
{
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

   // Separate into positive and negative profit arrays
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

   // Sort positives descending (biggest profit first)
   for(int i = 0; i < posCount-1; i++)
      for(int j = 0; j < posCount-i-1; j++)
         if(posProfit[j] < posProfit[j+1])
           {
            double tp = posProfit[j];  posProfit[j]  = posProfit[j+1];  posProfit[j+1]  = tp;
            ulong  tt = posTickets[j]; posTickets[j] = posTickets[j+1]; posTickets[j+1] = tt;
           }

   // Sort negatives ascending (biggest loss first)
   for(int i = 0; i < negCount-1; i++)
      for(int j = 0; j < negCount-i-1; j++)
         if(negProfit[j] > negProfit[j+1])
           {
            double tp = negProfit[j];  negProfit[j]  = negProfit[j+1];  negProfit[j+1]  = tp;
            ulong  tt = negTickets[j]; negTickets[j] = negTickets[j+1]; negTickets[j+1] = tt;
           }

   // Interleave: positive, negative, positive, negative...
   ArrayResize(sequence, count);
   int seqIdx = 0, p = 0, n = 0;
   while(p < posCount || n < negCount)
     {
      if(p < posCount) sequence[seqIdx++] = posTickets[p++];
      if(n < negCount) sequence[seqIdx++] = negTickets[n++];
     }

   return count;
}

//+------------------------------------------------------------------+
//| Start confirmation-based cleanup sequence                        |
//| Deletes all pending orders immediately                           |
//| Positions closed one-by-one via ExecuteNextCloseStep()           |
//+------------------------------------------------------------------+
void StartCleanupSequence(ENUM_CLEANUP_TYPE cleanupType, GridState &state)
{
   LogCleanupStarted(EnumToString(cleanupType));
   DeleteAllOrders(state.magicNumber);
   state.cleanupInProgress = true;
   state.cleanupStep       = 0;
   state.cleanupType       = cleanupType;
}

//+------------------------------------------------------------------+
//| Execute next step in confirmation-based close sequence           |
//| Style C: delegates to ExecuteNextCloseStep_C                    |
//+------------------------------------------------------------------+
bool ExecuteNextCloseStep(GridState &state)
{
   // Style C: close positions only, keep orders, then refill
   if(InpStrategyStyle == STYLE_C)
      return ExecuteNextCloseStep_C(state);

   if(!state.cleanupInProgress) return true;

   ulong sequence[];
   int   remaining = BuildCloseSequence(state.magicNumber, sequence);

   if(remaining == 0)
     {
      state.cleanupInProgress = false;
      state.cleanupStep       = 0;
      LogCleanupComplete();
      return true;
     }

   ClosePosition(sequence[0]);
   state.cleanupStep++;
   return false;
}

//+------------------------------------------------------------------+
//| Full state reset after cleanup                                   |
//| Preserves magic number across cycles                             |
//+------------------------------------------------------------------+
void ResetCycle(GridState &state)
{
   int magic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = magic;
}

#endif

#ifndef CLEANUP_RESET_MQH
#define CLEANUP_RESET_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| SHARED HELPERS                                                   |
//+------------------------------------------------------------------+

int BuildCloseSequence(int magicNumber, ulong &sequence[])
{
   ulong  tickets[]; double profits[]; int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      ArrayResize(tickets, count+1); ArrayResize(profits, count+1);
      tickets[count] = t; profits[count] = PositionGetDouble(POSITION_PROFIT); count++;
     }

   ulong posT[]; double posP[]; int posN=0;
   ulong negT[]; double negP[]; int negN=0;
   for(int i=0;i<count;i++)
     {
      if(profits[i]>=0) { ArrayResize(posT,posN+1); ArrayResize(posP,posN+1); posT[posN]=tickets[i]; posP[posN]=profits[i]; posN++; }
      else              { ArrayResize(negT,negN+1); ArrayResize(negP,negN+1); negT[negN]=tickets[i]; negP[negN]=profits[i]; negN++; }
     }
   // Sort positives desc, negatives asc
   for(int i=0;i<posN-1;i++) for(int j=0;j<posN-i-1;j++) if(posP[j]<posP[j+1]){double tp=posP[j];posP[j]=posP[j+1];posP[j+1]=tp;ulong tt=posT[j];posT[j]=posT[j+1];posT[j+1]=tt;}
   for(int i=0;i<negN-1;i++) for(int j=0;j<negN-i-1;j++) if(negP[j]>negP[j+1]){double tp=negP[j];negP[j]=negP[j+1];negP[j+1]=tp;ulong tt=negT[j];negT[j]=negT[j+1];negT[j+1]=tt;}

   ArrayResize(sequence, count);
   int idx=0, p=0, n=0;
   while(p<posN||n<negN)
     { if(p<posN) sequence[idx++]=posT[p++]; if(n<negN) sequence[idx++]=negT[n++]; }
   return count;
}

void ResetCycle(GridState &state)
{
   int magic = state.magicNumber;
   ResetGridState(state);
   state.magicNumber = magic;
}

//+------------------------------------------------------------------+
//| STYLE A/B — Emergency close (positions + orders)                 |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose_AB(GridState &state)
{
   LogCleanupStarted("EMERGENCY");
   DeleteAllOrders(state.magicNumber);
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=state.magicNumber) continue;
      ClosePosition(t);
     }
   state.cleanupInProgress=false;
   LogCleanupComplete();
}

//+------------------------------------------------------------------+
//| STYLE A/B — Confirmation-based sequence close                    |
//+------------------------------------------------------------------+
void StartCleanupSequence(ENUM_CLEANUP_TYPE cleanupType, GridState &state)
{
   LogCleanupStarted(EnumToString(cleanupType));
   DeleteAllOrders(state.magicNumber);
   state.cleanupInProgress = true;
   state.cleanupStep       = 0;
   state.cleanupType       = cleanupType;
}

bool ExecuteNextCloseStep_AB(GridState &state)
{
   if(!state.cleanupInProgress) return true;
   ulong sequence[]; int remaining = BuildCloseSequence(state.magicNumber, sequence);
   if(remaining==0)
     { state.cleanupInProgress=false; state.cleanupStep=0; LogCleanupComplete(); return true; }
   ClosePosition(sequence[0]);
   state.cleanupStep++;
   return false;
}

//+------------------------------------------------------------------+
//| STYLE C — Close positions only, keep orders, then refill         |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose_C(GridState &state)
{
   LogCleanupStarted("STYLE_C_EMERGENCY");
   // Emergency for Style C also removes orders (full reset)
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=state.magicNumber) continue;
      ClosePosition(t);
     }
   DeleteAllOrders(state.magicNumber);
   ResetSLManager_C();
   state.cleanupInProgress=false;
   state.cleanupStep=0;
   state.slApplied=false;
   LogCleanupComplete();
}

bool ExecuteNextCloseStep_C(GridState &state)
{
   if(!state.cleanupInProgress) return true;
   int remaining = CountPositions(state.magicNumber);
   if(remaining==0)
     {
      // All positions closed — run refill check (from GridBuilder)
      CheckAndRefill(state);
      state.cleanupInProgress=false;
      state.cleanupStep=0;
      state.slApplied=false;
      ResetSLManager_C();
      LogCleanupComplete();
      return true;
     }
   // Close biggest positive first
   double best=-DBL_MAX; ulong target=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=state.magicNumber) continue;
      double p=PositionGetDouble(POSITION_PROFIT);
      if(p>best){best=p;target=t;}
     }
   if(target>0){ClosePosition(target);state.cleanupStep++;}
   return false;
}

//+------------------------------------------------------------------+
//| MASTER functions — route by style                                |
//+------------------------------------------------------------------+
void ExecuteEmergencyClose(GridState &state)
{
   if(InpStrategyStyle==STYLE_C) ExecuteEmergencyClose_C(state);
   else                          ExecuteEmergencyClose_AB(state);
}

bool ExecuteNextCloseStep(GridState &state)
{
   if(InpStrategyStyle==STYLE_C) return ExecuteNextCloseStep_C(state);
   else                          return ExecuteNextCloseStep_AB(state);
}

#endif

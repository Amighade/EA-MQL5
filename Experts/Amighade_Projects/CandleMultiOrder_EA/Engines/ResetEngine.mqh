//+------------------------------------------------------------------+
//| ResetEngine.mqh                                                   |
//| All reset functions: ABWCL core, anchors, budget, compression   |
//+------------------------------------------------------------------+
#ifndef CMO_RESET_ENGINE_MQH
#define CMO_RESET_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Models/RangeState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| Reset ABWCL core and epoch bookkeeping only                      |
//| Does NOT touch range/anchors unless resetEpochCounter=true       |
//+------------------------------------------------------------------+
void ResetABWCLCore(bool resetEpochCounter = false)
{
   gABWCLArmed      = false;
   gABWCL_SL_winner = 0.0;
   gABWCL_SL_loser  = 0.0;
   gABWCLWinnerSide = -1;
   gArmedSL         = 0.0;

   ArrayResize(gEpochWinnerTickets, 0);
   ArrayResize(gEpochLoserTickets,  0);

   gArmTime        = 0;
   gEpochStartTime = 0;

   if(resetEpochCounter) gArmEpoch = 0;

   if(EnableDebugLogs) Print("[ResetEngine] ABWCL core reset.");
}

//+------------------------------------------------------------------+
//| Reset anchors, range cluster and placement state                 |
//+------------------------------------------------------------------+
void ResetAnchorAndRange()
{
   gbuyEntry_range  = 0.0;
   gsellEntry_range = 0.0;
   grange           = 0.0;
   ClearRangeState();
   gbuyEntry        = 0.0;
   gsellEntry       = 0.0;
   gLastPlaceBar    = 0;

   gMarginUsedBufferLevel = MarginUsedBufferLevel;
   if(gMarginUsedBufferLevel == 0.0)
     {
      gMarginUsedBufferLevel =
         (AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_MARGIN)) /
         (LotSizeInput / gMinLot);
     }

   if(EnableDebugLogs) Print("[ResetEngine] Anchor/range reset.");
}

//+------------------------------------------------------------------+
//| Reset budget exhaustion flag                                     |
//+------------------------------------------------------------------+
void ResetBudgetExhausted()
{
   if(!gBudgetExhausted) return;
   gBudgetExhausted = false;
   if(EnableDebugLogs) Print("[ResetEngine] Budget exhaustion reset.");
}

//+------------------------------------------------------------------+
//| Reset compression state                                          |
//+------------------------------------------------------------------+
void ResetCompression()
{
   gCompressionActive        = false;
   gCompressionKeepTarget    = 0;
   gCompressionProtectedSide = -1;
   gFirstNonEpochSideType    = -1;
   ArrayResize(gEpochToCloseArray, 0);
   ArrayResize(gEpochWallToArray,  0);
}

//+------------------------------------------------------------------+
//| Close non-epoch positions only (current range, not epoch)        |
//+------------------------------------------------------------------+
void CloseCurrentRangeNonEpoch()
{
   ulong tickets[];
   int   n = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(IsEpochTicket(t)) continue;

      ArrayResize(tickets, n+1);
      tickets[n++] = t;
     }

   if(n > 0)
     {
      CloseAll(tickets);
      if(EnableDebugLogs)
         PrintFormat("[ResetEngine] Closed %d non-epoch positions.", n);
     }
}

//+------------------------------------------------------------------+
//| Close all epoch positions and perform appropriate reset          |
//+------------------------------------------------------------------+
void CloseAllEpochPositions()
{
   int closed   = 0;
   int canceled = 0;

   if(gABWCLArmed)
     {
      // ARMED: close only epoch tickets, keep pending + newcomers
      ulong tickets[];
      int   n = 0;

      for(int i = PositionsTotal()-1; i >= 0; --i)
        {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(!IsEpochTicket(t)) continue;
         ArrayResize(tickets, n+1);
         tickets[n++] = t;
        }

      if(n > 0) closed = CloseAll(tickets);

      ResetABWCLCore(false);
      gABWCLWinnerSide = -1;
      ArrayResize(gEpochWinnerTickets, 0);
      ArrayResize(gEpochLoserTickets,  0);
      gArmTime        = 0;
      gEpochStartTime = 0;

      if(EnableDebugLogs)
         PrintFormat("[ResetEngine] ARMED epoch kill: closed %d, kept pending/newcomers.", closed);
      return;
     }

   // NOT ARMED: full flush — all positions + all pending
   ulong tickets[];
   int   n = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      ArrayResize(tickets, n+1);
      tickets[n++] = t;
     }

   if(n > 0) closed = CloseAll(tickets);
   canceled = CancelAllPending();

   ResetABWCLCore(false);
   ResetAnchorAndRange();

   if(EnableDebugLogs)
      PrintFormat("[ResetEngine] UNARMED epoch kill: closed %d, canceled %d.", closed, canceled);
}

#endif

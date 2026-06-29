//+------------------------------------------------------------------+
//| ABWCLEngine.mqh                                                   |
//| ABWCL: epoch snapshot, wall application, trailing, loser checks  |
//+------------------------------------------------------------------+
#ifndef CMO_ABWCL_ENGINE_MQH
#define CMO_ABWCL_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "ResetEngine.mqh"

//+------------------------------------------------------------------+
//| Snapshot current positions into winner/loser epoch arrays        |
//+------------------------------------------------------------------+
void SnapshotEpoch()
{
   ArrayResize(gEpochWinnerTickets, 0);
   ArrayResize(gEpochLoserTickets,  0);

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == gABWCLWinnerSide)
        {
         int sz = ArraySize(gEpochWinnerTickets);
         ArrayResize(gEpochWinnerTickets, sz+1);
         gEpochWinnerTickets[sz] = t;
        }
      else
        {
         int sz = ArraySize(gEpochLoserTickets);
         ArrayResize(gEpochLoserTickets, sz+1);
         gEpochLoserTickets[sz] = t;
        }
     }
}

//+------------------------------------------------------------------+
//| Apply shared SL wall to a ticket array                           |
//| If any position refuses the wall → kill entire epoch             |
//+------------------------------------------------------------------+
int ApplyWallToTickets(ulong &tickets[], double wallPrice)
{
   int  protectedCount = 0;
   bool anyFailed      = false;
   double wallNorm     = NormalizeDouble(wallPrice, _Digits);

   for(int i = 0; i < ArraySize(tickets); i++)
     {
      ulong t = tickets[i];
      if(!PositionSelectByTicket(t)) continue;

      double oldSL   = PositionGetDouble(POSITION_SL);
      double oldNorm = NormalizeDouble(oldSL, _Digits);

      if(oldNorm == wallNorm && wallNorm > 0.0)
        {
         protectedCount++;
         continue;
        }

      bool success = UpdateSL(t, wallPrice);

      if(success)
        {
         if(PositionSelectByTicket(t))
           {
            double gotNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
            if(gotNorm == wallNorm) protectedCount++;
           }
        }
      else
        {
         anyFailed = true;
        }
     }

   if(anyFailed)
     {
      CloseAllEpochPositions();
      protectedCount = 0;
     }

   return protectedCount;
}

//+------------------------------------------------------------------+
//| Apply trailing SL to all epoch positions of a given type         |
//+------------------------------------------------------------------+
void ApplyTrailingForType(int type, double refLevel, PosLists &poslists)
{
   double refNorm  = NormalizeDouble(refLevel, _Digits);
   bool   anyFailed= false;

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != type) continue;
      if(!IsEpochTicket(t)) continue;

      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(refNorm == oldNorm) continue;

      if(!UpdateSL(t, refLevel))
         anyFailed = true;
     }

   if(anyFailed)
     {
      CloseAllEpochPositions();
      return;
     }

   // Update global SL tracker after success
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_TYPE) != type) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(!IsEpochTicket(t)) continue;
      if(type == POSITION_TYPE_BUY)  gABWCLSLbuy  = PositionGetDouble(POSITION_SL);
      else                           gABWCLSLsell = PositionGetDouble(POSITION_SL);
      break;
     }
}

//+------------------------------------------------------------------+
//| Calculate projected profit of winner tickets at a wall level     |
//+------------------------------------------------------------------+
double CalcProfitAtWallForWinners(const ulong &winnerTickets[], double wall)
{
   double total = 0.0;
   for(int i = 0; i < ArraySize(winnerTickets); i++)
     {
      ulong t = winnerTickets[i];
      if(!PositionSelectByTicket(t)) continue;
      int    type = (int)PositionGetInteger(POSITION_TYPE);
      double lot  = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      total += (type == POSITION_TYPE_BUY) ? lot*(wall-open) : lot*(open-wall);
      if(gCommissionPerLot > 0.0) total -= gCommissionPerLot * lot;
     }
   return total;
}

//+------------------------------------------------------------------+
//| Calculate current closable profit of loser tickets               |
//+------------------------------------------------------------------+
double CalcClosableNowForLosers(const ulong &loserTickets[])
{
   double total = 0.0;
   for(int i = 0; i < ArraySize(loserTickets); i++)
     {
      ulong t = loserTickets[i];
      if(!PositionSelectByTicket(t)) continue;
      total += PositionGetDouble(POSITION_PROFIT);
      if(gCommissionPerLot > 0.0)
         total -= gCommissionPerLot * PositionGetDouble(POSITION_VOLUME);
     }
   return total;
}

//+------------------------------------------------------------------+
//| Check if closing losers now is safe against winner wall profit   |
//+------------------------------------------------------------------+
bool CanCloseLosersAgainstWinnerWall(double wall)
{
   double winnersAtWall = CalcProfitAtWallForWinners(gEpochWinnerTickets, wall);
   double losersNow     = CalcClosableNowForLosers(gEpochLoserTickets);
   return (winnersAtWall + losersNow > 0.0);
}

#endif

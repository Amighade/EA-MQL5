//+------------------------------------------------------------------+
//| CompressionEngine.mqh                                             |
//| Compression protection: enter, manage, handle deal compression   |
//+------------------------------------------------------------------+
#ifndef CMO_COMPRESSION_ENGINE_MQH
#define CMO_COMPRESSION_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "ResetEngine.mqh"

//+------------------------------------------------------------------+
//| Fast-close non-epoch positions from newest down to keepTarget    |
//+------------------------------------------------------------------+
void FastCloseNonEpochFromEndToTarget(PosLists &poslists, int keepTarget)
{
   if(!gCompressionActive) return;
   int n = ArraySize(poslists.lstAll);
   if(n <= keepTarget) return;

   for(int i = n-1; i >= keepTarget; --i)
     {
      ulong t = poslists.lstAll[i].ticket;
      FastClosePosition(t);
      Sleep(2);
     }
}

//+------------------------------------------------------------------+
//| Build compression epoch arrays: positions to close vs to wall   |
//+------------------------------------------------------------------+
void SetCompressionEpoch(PosLists &poslists, int keepTarget,
                         int ProtectedSide, int winnerSide)
{
   ArrayResize(gEpochToCloseArray, 0);
   ArrayResize(gEpochWallToArray,  0);

   int n = ArraySize(poslists.lstAll);
   for(int i = n-1; i >= keepTarget; i--)
     {
      PosSnap p = poslists.lstAll[i];
      if(!PositionSelectByTicket(p.ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(IsEpochTicket(p.ticket)) continue;

      if(p.type != ProtectedSide)
        {
         int sz = ArraySize(gEpochToCloseArray);
         ArrayResize(gEpochToCloseArray, sz+1);
         gEpochToCloseArray[sz] = p;
        }
      else
        {
         int sz = ArraySize(gEpochWallToArray);
         ArrayResize(gEpochWallToArray, sz+1);
         gEpochWallToArray[sz] = p;
        }
     }

   if(EnableDebugLogs)
      PrintFormat("[CompressionEngine] Total=%d Keep=%d ToClose=%d ToWall=%d",
                  n, keepTarget,
                  ArraySize(gEpochToCloseArray),
                  ArraySize(gEpochWallToArray));
}

//+------------------------------------------------------------------+
//| Execute compression: apply wall to winners, close others         |
//+------------------------------------------------------------------+
void HandleDealsCompression(PosLists &poslists, int keepTarget,
                            int ProtectedSide, int winnerSide)
{
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = MinStopDistancePrice(_Symbol);
   double wallBuy = AlignToTick(_Symbol, bid - minStop);
   double wallSell= AlignToTick(_Symbol, ask + minStop);
   int    nAll    = ArraySize(poslists.lstAll);
   if(nAll == 0) return;

   SetCompressionEpoch(poslists, keepTarget, ProtectedSide, winnerSide);

   int closeCount = ArraySize(gEpochToCloseArray);
   int wallCount  = ArraySize(gEpochWallToArray);
   int maxIter    = MathMax(closeCount, wallCount);
   bool anyFailed = false;

   // For small basket: apply wall first, then close
   // For large basket: close all directly (wall is too risky)
   bool applyWall = (nAll < 5);

   for(int idx = 0; idx < maxIter; idx++)
     {
      if(idx < wallCount)
        {
         ulong t = gEpochWallToArray[idx].ticket;
         if(PositionSelectByTicket(t))
           {
            if(applyWall)
              {
               int    type = (int)PositionGetInteger(POSITION_TYPE);
               double wall = (type==POSITION_TYPE_BUY ? wallBuy : wallSell);
               if(!UpdateSL(t, wall)) { anyFailed = true; break; }
              }
            else
               FastClosePosition(t);
           }
        }

      if(idx < closeCount)
        {
         ulong t = gEpochToCloseArray[idx].ticket;
         if(PositionSelectByTicket(t))
            FastClosePosition(t);
        }
     }

   CancelAllPending();

   if(anyFailed)
     {
      FastCloseNonEpochFromEndToTarget(poslists, keepTarget);
      CancelAllPending();
      ResetCompression();
      if(EnableDebugLogs) Print("[CompressionEngine] Wall failed → force-closed cohort.");
     }
}

//+------------------------------------------------------------------+
//| Enter compression protection when deal count reaches threshold   |
//+------------------------------------------------------------------+
void EnterCompressionProtect(PosLists &poslists)
{
   if(gCompressionActive)   return;
   if(!UseCompressionProtect) return;

   int n = ArraySize(poslists.lstAll);
   SortByOpenTimeAscending(poslists.lstAll);
   if(n < CompressionStartDeals) return;

   gCompressionActive     = true;
   gFirstNonEpochSideType = poslists.lstAll[0].type;

   double buyProfit = 0, sellProfit = 0;
   for(int i = 0; i < n; i++)
     {
      if(poslists.lstAll[i].type==POSITION_TYPE_BUY)  buyProfit  += poslists.lstAll[i].profit;
      if(poslists.lstAll[i].type==POSITION_TYPE_SELL) sellProfit += poslists.lstAll[i].profit;
     }
   gCompressionProtectedSide = (buyProfit >= sellProfit ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   bool favorFirst         = (gCompressionProtectedSide == gFirstNonEpochSideType);
   gCompressionKeepTarget  = (favorFirst ? DealsKeepToward : DealsKeepAgainst);

   if(EnableDebugLogs)
      PrintFormat("[CompressionEngine] ENTER: n=%d threshold=%d firstSide=%s keepTarget=%d",
                  n, CompressionStartDeals,
                  gFirstNonEpochSideType==POSITION_TYPE_BUY?"BUY":"SELL",
                  gCompressionKeepTarget);
}

//+------------------------------------------------------------------+
//| Manage active compression — runs every tick while active         |
//+------------------------------------------------------------------+
void ManageCompressionProtect(PosLists &poslists)
{
   if(!gCompressionActive) return;

   int nAll = ArraySize(poslists.lstAll);
   SortByOpenTimeAscending(poslists.lstAll);

   double floatingNet = 0.0;
   for(int i = 0; i < nAll; i++)
     {
      floatingNet += poslists.lstAll[i].profit;
      if(gCommissionPerLot > 0.0)
         floatingNet -= gCommissionPerLot * poslists.lstAll[i].lots;
     }

   if(floatingNet <= 0) return;

   // Re-evaluate winner side and keep target
   gFirstNonEpochSideType = poslists.lstAll[0].type;
   double buyP = 0, sellP = 0;
   for(int i = 0; i < nAll; i++)
     {
      if(poslists.lstAll[i].type==POSITION_TYPE_BUY)  buyP  += poslists.lstAll[i].profit;
      if(poslists.lstAll[i].type==POSITION_TYPE_SELL) sellP += poslists.lstAll[i].profit;
     }
   gCompressionProtectedSide = (buyP >= sellP ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double firstPrice = poslists.lstAll[0].openPrice;

   // Determine keep target by price direction + winner side
   if(firstPrice < bid)
     {
      if(gFirstNonEpochSideType==POSITION_TYPE_BUY && gCompressionProtectedSide==POSITION_TYPE_BUY)
         gCompressionKeepTarget = DealsKeepToward;
      else if(gFirstNonEpochSideType==POSITION_TYPE_BUY && gCompressionProtectedSide==POSITION_TYPE_SELL)
         gCompressionKeepTarget = DealsKeepToward;
      else if(gFirstNonEpochSideType==POSITION_TYPE_SELL && gCompressionProtectedSide==POSITION_TYPE_BUY)
         gCompressionKeepTarget = DealsKeepAgainst;
      else
         gCompressionKeepTarget = DealsKeepAgainst;
     }
   else if(firstPrice > ask)
     {
      if(gFirstNonEpochSideType==POSITION_TYPE_SELL && gCompressionProtectedSide==POSITION_TYPE_SELL)
         gCompressionKeepTarget = DealsKeepToward;
      else if(gFirstNonEpochSideType==POSITION_TYPE_SELL && gCompressionProtectedSide==POSITION_TYPE_BUY)
         gCompressionKeepTarget = DealsKeepToward;
      else if(gFirstNonEpochSideType==POSITION_TYPE_BUY && gCompressionProtectedSide==POSITION_TYPE_SELL)
         gCompressionKeepTarget = DealsKeepAgainst;
      else
         gCompressionKeepTarget = DealsKeepAgainst;
     }
   else
      gCompressionKeepTarget = (gFirstNonEpochSideType==gCompressionProtectedSide) ?
                                DealsKeepToward : DealsKeepAgainst;

   // Exit if already at target
   if(nAll <= gCompressionKeepTarget)
     { ResetCompression(); return; }

   // Verify closure profit is sufficient
   double closureProfit = 0;
   for(int i = nAll-1; i >= gCompressionKeepTarget; i--)
     {
      closureProfit += poslists.lstAll[i].profit;
      if(gCommissionPerLot > 0.0)
         closureProfit -= gCommissionPerLot * poslists.lstAll[i].lots;
     }
   if(closureProfit < 3 - nAll) return;

   HandleDealsCompression(poslists, gCompressionKeepTarget,
                          gCompressionProtectedSide, gCompressionProtectedSide);
   ResetCompression();
   BuildAllListsSorted(poslists);
}

#endif

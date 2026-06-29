//+------------------------------------------------------------------+
//| ArmingEngine.mqh                                                  |
//| ABWCL epoch state machine: ManageArming + ArmBreakeven           |
//+------------------------------------------------------------------+
#ifndef CMO_ARMING_ENGINE_MQH
#define CMO_ARMING_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Models/RangeState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/CandleUtils.mqh"
#include "ABWCLEngine.mqh"
#include "ResetEngine.mqh"

//+------------------------------------------------------------------+
//| Main ABWCL epoch state machine                                   |
//| MOP-0: idle  MOP-1: epoch ended  MOP-2: start epoch             |
//| MOP-3: Phase A trailing  MOP-4: A→B transition                  |
//| MOP-5: Phase B trailing                                          |
//+------------------------------------------------------------------+
void ManageArming(PosLists &poslists)
{
   int nWSL      = ArraySize(poslists.lstWNSL);
   int nAll      = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);

   double floatingNet = 0;
   for(int i = 0; i < nAll; i++) floatingNet += poslists.lstAll[i].profit;

   // [MOP-0] Idle maintenance
   if(!gABWCLArmed)
     {
      if(gABWCL_SL_winner!=0.0||gABWCL_SL_loser!=0.0||gABWCLWinnerSide!=-1||
         ArraySize(gEpochWinnerTickets)>0||ArraySize(gEpochLoserTickets)>0)
        {
         gABWCL_SL_winner=0.0; gABWCL_SL_loser=0.0; gABWCLWinnerSide=-1;
         ArrayResize(gEpochWinnerTickets,0); ArrayResize(gEpochLoserTickets,0);
        }
     }

   if(gABWCLArmed)
     {
      if((ArraySize(gEpochWinnerTickets)+ArraySize(gEpochLoserTickets) != nAllDeals-nAll) ||
         (nAllDeals > 2*(nAllDeals-nAll)))
         ResetABWCLCore(false);
     }

   // [MOP-1] Epoch ended — all tracked positions closed
   if(gABWCLArmed && AllClosed(gEpochWinnerTickets) && AllClosed(gEpochLoserTickets))
     {
      ResetABWCLCore(false);
      return;
     }

   // [MOP-2] Start new epoch when net profit turns positive
   if(!gABWCLArmed && gABWCL_SL_winner==0.0 && gABWCL_SL_loser==0.0 &&
      nAllDeals>0 && floatingNet>0)
     {
      ArmBreakevenWallCoverLoss(poslists);
      BuildAllListsSorted(poslists);
      return;
     }

   // [MOP-3] Phase A — winners trailing
   if(gABWCLArmed && gABWCL_SL_winner>0.0 && gABWCL_SL_loser==0.0 &&
      !AllClosed(gEpochWinnerTickets))
     {
      double rawRef = (gABWCLWinnerSide==POSITION_TYPE_BUY ? gLowBuf[1] : gHighBuf[1]);
      double ref    = (gABWCLWinnerSide==POSITION_TYPE_BUY) ?
                      MathMax(gABWCL_SL_winner, rawRef) :
                      MathMin(gABWCL_SL_winner, rawRef);
      gABWCL_SL_winner = ref;
      gABWCL_SL_loser  = 0;
      gArmedSL         = ref;
      ApplyTrailingForType(gABWCLWinnerSide, ref, poslists);
      if(CanCloseLosersAgainstWinnerWall(ref))
         FastCloseTickets(gEpochLoserTickets, true);
      BuildAllListsSorted(poslists);
      return;
     }

   // [MOP-4] Transition A→B — winners closed, losers remain
   if(gABWCLArmed && gABWCL_SL_winner>0.0 && gABWCL_SL_loser==0.0 &&
      AllClosed(gEpochWinnerTickets) && ArraySize(gEpochLoserTickets)>0)
     {
      double minStop = MinStopDistancePrice(_Symbol);
      double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double LoserSL;

      ArrayResize(gEpochWinnerTickets, 0);

      if(gABWCLWinnerSide == POSITION_TYPE_BUY)
         LoserSL = MathMax(gABWCL_SL_winner+minStop, ask+minStop);
      else
         LoserSL = MathMin(gABWCL_SL_winner-minStop, bid-minStop);
      LoserSL = AlignToTick(_Symbol, LoserSL);

      int prot = ApplyWallToTickets(gEpochLoserTickets, LoserSL);
      BuildAllListsSorted(poslists);

      if(prot > 0)
        {
         gABWCL_SL_winner = 0.0;
         gABWCL_SL_loser  = LoserSL;
         gArmedSL         = LoserSL;
        }
      return;
     }

   // [MOP-5] Phase B — losers trailing
   if(gABWCLArmed && gABWCL_SL_loser>0.0 && !AllClosed(gEpochLoserTickets))
     {
      int oppType = (gABWCLWinnerSide==POSITION_TYPE_BUY ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
      double rawRef = (oppType==POSITION_TYPE_BUY ? gLowBuf[1] : gHighBuf[1]);
      double ref    = (oppType==POSITION_TYPE_BUY) ?
                      MathMax(gABWCL_SL_loser, rawRef) :
                      MathMin(gABWCL_SL_loser, rawRef);
      gABWCL_SL_winner = 0;
      gABWCL_SL_loser  = ref;
      gArmedSL         = ref;

      // Add new positive position to losers if only one unprotected remains
      int nWSL2 = ArraySize(poslists.lstWNSL);
      if(nWSL2==1 && poslists.lstWNSL[0].profit>0)
        {
         ulong t = poslists.lstWNSL[0].ticket;
         int sz  = ArraySize(gEpochLoserTickets);
         ArrayResize(gEpochLoserTickets, sz+1);
         gEpochLoserTickets[sz] = t;
        }

      ApplyTrailingForType(oppType, ref, poslists);
      BuildAllListsSorted(poslists);
      return;
     }
}

//+------------------------------------------------------------------+
//| Arm ABWCL — compute equilibrium, snapshot epoch, apply wall      |
//+------------------------------------------------------------------+
void ArmBreakevenWallCoverLoss(PosLists &poslists)
{
   int nAll      = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   if(nAllDeals == 0) return;

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = MathMax(ask-bid, 0.0);

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize<=0.0||tickValue<=0.0) return;

   double moneyPerPricePerLot = tickValue / tickSize;
   double commPerLot          = gCommissionPerLot;

   // Net profit after commission
   double floatingNet = 0.0, allLots = 0.0;
   for(int i = 0; i < nAll; i++)
     {
      floatingNet += poslists.lstAll[i].profit;
      allLots     += poslists.lstAll[i].lots;
     }
   floatingNet -= commPerLot * allLots;
   if(floatingNet <= 0.0) return;

   double B  = DM_Lots(POSITION_TYPE_BUY);
   double S  = DM_Lots(POSITION_TYPE_SELL);
   double BE = B * DM_AvgEntry(POSITION_TYPE_BUY);
   double SE = S * DM_AvgEntry(POSITION_TYPE_SELL);

   double buyProfit  = DM_NetProfit(POSITION_TYPE_BUY)  - commPerLot*B;
   double sellProfit = DM_NetProfit(POSITION_TYPE_SELL) - commPerLot*S;
   double denomProfit= buyProfit - sellProfit;
   double totalComm  = commPerLot * (B+S);

   if(MathAbs(denomProfit) < 1e-12) return;
   gABWCLWinnerSide = (denomProfit > 0.0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   double denom = B - S;
   double Sstar = 0.0;
   bool   skipSstar = false;

   if(MathAbs(denom) < 1e-12)
     {
      if(buyProfit+sellProfit <= 0.0) return;
      skipSstar = true;
      Sstar = (gABWCLWinnerSide==POSITION_TYPE_BUY ? bid : ask);
     }
   else
      Sstar = (BE - SE + S*spread + totalComm/moneyPerPricePerLot) / denom;

   // Wall from previous candle
   double CandleRefHigh = gHighBuf[1], CandleRefLow = gLowBuf[1];
   switch(InpWinnerWallMode)
     {
      case PREV_CANDLE_BODY:
         CandleRefHigh = MathMax(gOpenBuf[1], gCloseBuf[1]);
         CandleRefLow  = MathMin(gOpenBuf[1], gCloseBuf[1]);
         break;
      case PREV_CANDLE_AVRG:
         CandleRefHigh = (gHighBuf[1]+MathMax(gOpenBuf[1],gCloseBuf[1]))*0.5;
         CandleRefLow  = (gLowBuf[1] +MathMin(gOpenBuf[1],gCloseBuf[1]))*0.5;
         break;
      default: break;
     }

   double S_HA        = (gABWCLWinnerSide==POSITION_TYPE_BUY ? CandleRefLow : CandleRefHigh);
   S_HA               = AlignToTick(_Symbol, S_HA);
   double wallBidMath = (gABWCLWinnerSide==POSITION_TYPE_BUY ? S_HA : S_HA-spread);

   // Safety checks
   if(!skipSstar)
     {
      bool stratOK = (denom>0.0 ? wallBidMath>=Sstar : wallBidMath<=Sstar);
      bool mktOK   = (denom>0.0 ? bid>Sstar : ask<Sstar);
      if(!stratOK||!mktOK) return;
     }

   double minStop = MinStopDistancePrice(_Symbol);
   bool brokerOK  = (gABWCLWinnerSide==POSITION_TYPE_BUY ?
                     S_HA<=bid-minStop : S_HA>=ask+minStop);
   if(!brokerOK) return;

   // Snapshot and apply wall
   gArmEpoch++;
   ResetAnchorAndRange();
   gArmTime        = TimeCurrent();
   SnapshotEpoch();
   gEpochStartTime = TimeCurrent();

   int protectedCount = ApplyWallToTickets(gEpochWinnerTickets, S_HA);
   if(protectedCount > 0)
     {
      if(CanCloseLosersAgainstWinnerWall(S_HA))
         FastCloseTickets(gEpochLoserTickets, true);

      gABWCLArmed      = true;
      gABWCL_SL_winner = S_HA;
      gABWCL_SL_loser  = 0.0;
      gArmedSL         = S_HA;
      CancelAllPending();

      if(EnableDebugLogs)
         PrintFormat("[ArmingEngine] Epoch %d ARMED | Side=%s | Wall=%.5f | Prot=%d",
                     gArmEpoch,
                     gABWCLWinnerSide==POSITION_TYPE_BUY?"BUY":"SELL",
                     S_HA, protectedCount);
     }
}

#endif

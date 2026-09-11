#ifndef SL_MANAGER_MQH
#define SL_MANAGER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| STYLE C ABWCL STATE                                              |
//+------------------------------------------------------------------+
bool   gC_ABWCLArmed  = false;
int    gC_WinnerSide  = -1;
double gC_SL_winner   = 0.0;
double gC_SL_loser    = 0.0;
ulong  gC_WinnerTickets[];
ulong  gC_LoserTickets[];

void ResetSLManager_C()
{
   gC_ABWCLArmed = false;
   gC_WinnerSide = -1;
   gC_SL_winner  = 0.0;
   gC_SL_loser   = 0.0;
   ArrayResize(gC_WinnerTickets, 0);
   ArrayResize(gC_LoserTickets,  0);
}

//+------------------------------------------------------------------+
//| SHARED HELPERS — used by Style A/B and Style C                   |
//+------------------------------------------------------------------+

ENUM_POSITION_TYPE GetWinningDirection(GridState &state)
{
   double buyProfit  = CalculateDirectionProfit(POSITION_TYPE_BUY,  state.magicNumber);
   double sellProfit = CalculateDirectionProfit(POSITION_TYPE_SELL, state.magicNumber);
   state.basketBuyProfit  = buyProfit;
   state.basketSellProfit = sellProfit;
   return (buyProfit >= sellProfit) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
}

bool CheckSLTrigger(GridState &state)
{
   if(state.slApplied) return false;
   bool triggered = false;
   if(InpSLTriggerByLot    && state.currentBlockLot >= InpSLTriggerLot) triggered = true;
   if(InpSLTriggerByProfit && state.basketProfit > 0)                   triggered = true;
   if(triggered) LogSLTriggered("TRIGGERED", 0);
   return triggered;
}

void ApplySLToPositions(ENUM_POSITION_TYPE winningDir, double slLevel, GridState &state)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    appliedCount = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != winningDir) continue;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      bool   qualifies  = (winningDir==POSITION_TYPE_BUY) ?
                          (currentPrice > entryPrice && slLevel < entryPrice) :
                          (currentPrice < entryPrice && slLevel > entryPrice);

      if(qualifies && ModifyPositionSL(ticket, slLevel)) appliedCount++;
     }

   if(appliedCount > 0)
     { state.slApplied = true; state.slLevel = slLevel;
       LogSLTriggered("SL_APPLIED", slLevel); }
}

//+------------------------------------------------------------------+
//| STYLE C — ABWCL snapshot, wall, trail, loser check              |
//+------------------------------------------------------------------+

void SnapshotEpoch_C(int magicNumber)
{
   ArrayResize(gC_WinnerTickets, 0);
   ArrayResize(gC_LoserTickets,  0);
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == gC_WinnerSide)
        { int sz=ArraySize(gC_WinnerTickets); ArrayResize(gC_WinnerTickets,sz+1); gC_WinnerTickets[sz]=t; }
      else
        { int sz=ArraySize(gC_LoserTickets);  ArrayResize(gC_LoserTickets, sz+1); gC_LoserTickets[sz]=t;  }
     }
}

bool AllClosed_C(ulong &tickets[])
{
   for(int i = 0; i < ArraySize(tickets); i++)
      if(PositionSelectByTicket(tickets[i])) return false;
   return true;
}

double CalcWinnersAtWall_C(double wall)
{
   double total = 0.0;
   for(int i = 0; i < ArraySize(gC_WinnerTickets); i++)
     {
      ulong t = gC_WinnerTickets[i];
      if(!PositionSelectByTicket(t)) continue;
      int    type = (int)PositionGetInteger(POSITION_TYPE);
      double lot  = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      total += (type==POSITION_TYPE_BUY) ? lot*(wall-open) : lot*(open-wall);
     }
   return total;
}

double CalcLosersNow_C()
{
   double total = 0.0;
   for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
     {
      ulong t = gC_LoserTickets[i];
      if(!PositionSelectByTicket(t)) continue;
      total += PositionGetDouble(POSITION_PROFIT);
     }
   return total;
}

bool CanCloseLosers_C(double wallLevel)
{
   return (CalcWinnersAtWall_C(wallLevel) + CalcLosersNow_C() > 0.0);
}

int ApplyWallToWinners_C(double wallPrice, int magicNumber)
{
   int    count    = 0;
   bool   anyFail  = false;
   double wallNorm = NormalizeDouble(wallPrice, _Digits);

   for(int i = 0; i < ArraySize(gC_WinnerTickets); i++)
     {
      ulong t = gC_WinnerTickets[i];
      if(!PositionSelectByTicket(t)) continue;
      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(oldNorm == wallNorm && wallNorm > 0.0) { count++; continue; }
      if(ModifyPositionSL(t, wallPrice)) count++;
      else anyFail = true;
     }

   if(anyFail)
     {
      for(int i = PositionsTotal()-1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
         if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
         ClosePosition(t);
        }
      ResetSLManager_C();
      return 0;
     }
   return count;
}

void ArmStyleC(GridState &state)
{
   double candleHigh = MathMax(iOpen(_Symbol,PERIOD_CURRENT,1), iClose(_Symbol,PERIOD_CURRENT,1));
   double candleLow  = MathMin(iOpen(_Symbol,PERIOD_CURRENT,1), iClose(_Symbol,PERIOD_CURRENT,1));

   double buyProfit  = CalculateDirectionProfit(POSITION_TYPE_BUY,  state.magicNumber);
   double sellProfit = CalculateDirectionProfit(POSITION_TYPE_SELL, state.magicNumber);
   if(buyProfit==0.0 && sellProfit==0.0) return;

   gC_WinnerSide    = (buyProfit >= sellProfit) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double wallLevel = (gC_WinnerSide==POSITION_TYPE_BUY) ? candleLow : candleHigh;
   wallLevel        = AlignToTick(_Symbol, wallLevel);

   double minStop = MinStopDistancePrice(_Symbol);
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool   brokerOK= (gC_WinnerSide==POSITION_TYPE_BUY) ?
                    wallLevel <= bid-minStop : wallLevel >= ask+minStop;
   if(!brokerOK) return;

   SnapshotEpoch_C(state.magicNumber);
   int prot = ApplyWallToWinners_C(wallLevel, state.magicNumber);
   if(prot == 0) return;

   if(CanCloseLosers_C(wallLevel))
      for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
         FastClosePosition(gC_LoserTickets[i]);

   gC_ABWCLArmed = true;
   gC_SL_winner  = wallLevel;
   gC_SL_loser   = 0.0;
   LogSLTriggered("STYLE_C_ARMED", wallLevel);
}

void TrailWall_C(GridState &state)
{
   if(!gC_ABWCLArmed || gC_SL_winner<=0.0) return;

   double candleHigh = MathMax(iOpen(_Symbol,PERIOD_CURRENT,1), iClose(_Symbol,PERIOD_CURRENT,1));
   double candleLow  = MathMin(iOpen(_Symbol,PERIOD_CURRENT,1), iClose(_Symbol,PERIOD_CURRENT,1));
   double rawRef     = (gC_WinnerSide==POSITION_TYPE_BUY) ? candleLow : candleHigh;
   double newWall    = (gC_WinnerSide==POSITION_TYPE_BUY) ?
                       MathMax(gC_SL_winner, rawRef) : MathMin(gC_SL_winner, rawRef);
   newWall = AlignToTick(_Symbol, newWall);

   // Check losers on every trail regardless of wall movement
   if(CanCloseLosers_C(newWall))
      for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
         FastClosePosition(gC_LoserTickets[i]);

   if(!NearlyEqualPrice(newWall, gC_SL_winner))
     {
      gC_SL_winner = newWall;
      ApplyWallToWinners_C(newWall, state.magicNumber);
     }

   // All winners closed by SL → trigger cleanup
   if(AllClosed_C(gC_WinnerTickets))
     {
      for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
         ClosePosition(gC_LoserTickets[i]);
      ResetSLManager_C();
      state.slApplied         = false;
      state.cleanupInProgress = true; // signals coordinator to run CheckAndRefill
     }
}

void ProcessSLManager_C(GridState &state)
{
   if(gC_ABWCLArmed) { TrailWall_C(state); return; }

   state.basketProfit = CalculateBasketProfit(state.magicNumber);
   bool triggered = false;
   if(InpSLTriggerByLot    && state.currentBlockLot >= InpSLTriggerLot) triggered = true;
   if(InpSLTriggerByProfit && state.basketProfit > 0)                   triggered = true;
   if(triggered) ArmStyleC(state);
}

//+------------------------------------------------------------------+
//| MASTER — routes by style                                         |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
{
   if(InpStrategyStyle == STYLE_C) { ProcessSLManager_C(state); return; }

   state.basketProfit = CalculateBasketProfit(state.magicNumber);
   if(!CheckSLTrigger(state)) return;

   ENUM_POSITION_TYPE winningDir = GetWinningDirection(state);
   double slLevel = CalculateSLLevel(winningDir, state.magicNumber);
   if(slLevel <= 0) return;
   ApplySLToPositions(winningDir, slLevel, state);
}

#endif

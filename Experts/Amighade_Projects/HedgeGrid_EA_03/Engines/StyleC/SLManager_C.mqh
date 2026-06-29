//+------------------------------------------------------------------+
//| SLManager_C.mqh                                                   |
//| Style C: ABWCL-style SL arming with loser check on each trail   |
//|                                                                  |
//| Differences from standard SLManager:                            |
//| - Uses full ABWCL math (winners vs losers, equilibrium price)   |
//| - Trails wall each tick                                          |
//| - Checks loser closing on every trail                           |
//| - On SL hit: close positions only, keep orders → trigger refill  |
//+------------------------------------------------------------------+
#ifndef SL_MANAGER_C_MQH
#define SL_MANAGER_C_MQH

#include "../../Inputs.mqh"
#include "../../Models/GridState.mqh"
#include "../../Utils/TradeUtils.mqh"
#include "../../Utils/MathUtils.mqh"
#include "../../Utils/DebugLogger.mqh"

//--- Style C ABWCL state (separate from main SLManager state)
bool   gC_ABWCLArmed        = false;
int    gC_WinnerSide        = -1;      // POSITION_TYPE_BUY or SELL
double gC_SL_winner         = 0.0;    // current wall SL for winners
double gC_SL_loser          = 0.0;    // current wall SL for losers (Phase B)
ulong  gC_WinnerTickets[];
ulong  gC_LoserTickets[];

//+------------------------------------------------------------------+
//| Reset Style C ABWCL state                                        |
//+------------------------------------------------------------------+
void ResetSLManager_C()
{
   gC_ABWCLArmed = false;
   gC_WinnerSide = -1;
   gC_SL_winner  = 0.0;
   gC_SL_loser   = 0.0;
   ArrayResize(gC_WinnerTickets, 0);
   ArrayResize(gC_LoserTickets,  0);
   LogDebug("[SLManager_C] State reset.");
}

//+------------------------------------------------------------------+
//| Snapshot open positions into winner/loser arrays                 |
//+------------------------------------------------------------------+
void SnapshotEpoch_C(int magicNumber)
{
   ArrayResize(gC_WinnerTickets, 0);
   ArrayResize(gC_LoserTickets,  0);

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != magicNumber) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == gC_WinnerSide)
        {
         int sz = ArraySize(gC_WinnerTickets);
         ArrayResize(gC_WinnerTickets, sz+1);
         gC_WinnerTickets[sz] = t;
        }
      else
        {
         int sz = ArraySize(gC_LoserTickets);
         ArrayResize(gC_LoserTickets, sz+1);
         gC_LoserTickets[sz] = t;
        }
     }
}

//+------------------------------------------------------------------+
//| Check all tickets in array are closed                            |
//+------------------------------------------------------------------+
bool AllClosed_C(ulong &tickets[])
{
   for(int i = 0; i < ArraySize(tickets); i++)
      if(PositionSelectByTicket(tickets[i])) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Calculate winner profit at a given wall price                    |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Calculate current floating profit of loser positions             |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Check if closing losers now keeps net positive                   |
//+------------------------------------------------------------------+
bool CanCloseLosers_C(double wallLevel)
{
   double winnersAtWall = CalcWinnersAtWall_C(wallLevel);
   double losersNow     = CalcLosersNow_C();
   return (winnersAtWall + losersNow > 0.0);
}

//+------------------------------------------------------------------+
//| Apply SL to all winner positions                                 |
//+------------------------------------------------------------------+
int ApplyWallToWinners_C(double wallPrice, int magicNumber)
{
   int    protectedCount = 0;
   bool   anyFailed      = false;
   double wallNorm       = NormalizeDouble(wallPrice, _Digits);

   for(int i = 0; i < ArraySize(gC_WinnerTickets); i++)
     {
      ulong t = gC_WinnerTickets[i];
      if(!PositionSelectByTicket(t)) continue;

      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(oldNorm == wallNorm && wallNorm > 0.0) { protectedCount++; continue; }

      if(ModifyPositionSL(t, wallPrice))
         protectedCount++;
      else
         anyFailed = true;
     }

   if(anyFailed)
     {
      // If wall application fails, close all positions and reset
      LogDebug("[SLManager_C] Wall application failed — closing all positions.");
      for(int i = PositionsTotal()-1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
         if(PositionGetInteger(POSITION_MAGIC)  != magicNumber) continue;
         ClosePosition(t);
        }
      ResetSLManager_C();
      return 0;
     }

   return protectedCount;
}

//+------------------------------------------------------------------+
//| Arm Style C ABWCL — evaluate winners, apply wall, check losers  |
//+------------------------------------------------------------------+
void ArmStyleC(GridState &state)
{
   // Get candle reference for wall level
   // Use previous candle body (same as PREV_CANDLE_BODY mode in ABWCL)
   double candleHigh = MathMax(iOpen(_Symbol, PERIOD_CURRENT, 1),
                               iClose(_Symbol, PERIOD_CURRENT, 1));
   double candleLow  = MathMin(iOpen(_Symbol, PERIOD_CURRENT, 1),
                               iClose(_Symbol, PERIOD_CURRENT, 1));

   // Determine winner side by floating profit
   double buyProfit  = CalculateDirectionProfit(POSITION_TYPE_BUY,  state.magicNumber);
   double sellProfit = CalculateDirectionProfit(POSITION_TYPE_SELL, state.magicNumber);

   if(buyProfit == 0.0 && sellProfit == 0.0) return;

   gC_WinnerSide = (buyProfit >= sellProfit) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   // Wall level from previous candle
   double wallLevel = (gC_WinnerSide == POSITION_TYPE_BUY) ? candleLow : candleHigh;
   wallLevel = AlignToTick(_Symbol, wallLevel);

   // Broker minimum stop check
   double minStop = MinStopDistancePrice(_Symbol);
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool brokerOK = (gC_WinnerSide == POSITION_TYPE_BUY) ?
                   wallLevel <= bid - minStop :
                   wallLevel >= ask + minStop;
   if(!brokerOK)
     {
      LogDebug(StringFormat("[SLManager_C] Wall %.2f rejected by broker minStop=%.2f",
                            wallLevel, minStop));
      return;
     }

   // Snapshot epoch
   SnapshotEpoch_C(state.magicNumber);

   // Apply wall to winners
   int protectedCount = ApplyWallToWinners_C(wallLevel, state.magicNumber);
   if(protectedCount == 0) return;

   // Check if losers can be closed
   if(CanCloseLosers_C(wallLevel))
     {
      for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
         FastClosePosition(gC_LoserTickets[i]);
      LogDebug("[SLManager_C] Losers closed at arming.");
     }

   gC_ABWCLArmed = true;
   gC_SL_winner  = wallLevel;
   gC_SL_loser   = 0.0;

   LogSLTriggered("STYLE_C_ARMED", wallLevel);
   LogDebug(StringFormat("[SLManager_C] Armed. Side=%s Wall=%.2f Protected=%d",
                         gC_WinnerSide==POSITION_TYPE_BUY?"BUY":"SELL",
                         wallLevel, protectedCount));
}

//+------------------------------------------------------------------+
//| Trail the wall — Phase A (winners trailing)                      |
//| Called every tick while armed                                    |
//+------------------------------------------------------------------+
void TrailWall_C(GridState &state)
{
   if(!gC_ABWCLArmed) return;
   if(gC_SL_winner <= 0.0) return;

   // Trail wall based on previous candle body
   double candleHigh = MathMax(iOpen(_Symbol, PERIOD_CURRENT, 1),
                               iClose(_Symbol, PERIOD_CURRENT, 1));
   double candleLow  = MathMin(iOpen(_Symbol, PERIOD_CURRENT, 1),
                               iClose(_Symbol, PERIOD_CURRENT, 1));

   double rawRef = (gC_WinnerSide==POSITION_TYPE_BUY) ? candleLow : candleHigh;

   // Monotonic: never move wall against winners
   double newWall = (gC_WinnerSide==POSITION_TYPE_BUY) ?
                    MathMax(gC_SL_winner, rawRef) :
                    MathMin(gC_SL_winner, rawRef);
   newWall = AlignToTick(_Symbol, newWall);

   if(NearlyEqualPrice(newWall, gC_SL_winner))
     {
      // Wall unchanged — still check losers
      if(CanCloseLosers_C(gC_SL_winner))
        {
         for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
            FastClosePosition(gC_LoserTickets[i]);
        }
      return;
     }

   // Apply new wall to all winner positions
   gC_SL_winner = newWall;
   ApplyWallToWinners_C(newWall, state.magicNumber);

   // Check losers on every trail
   if(CanCloseLosers_C(newWall))
     {
      for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
         FastClosePosition(gC_LoserTickets[i]);
      LogDebug(StringFormat("[SLManager_C] Losers closed at trail wall=%.2f", newWall));
     }

   // Check if all winners closed (SL hit)
   if(AllClosed_C(gC_WinnerTickets))
     {
      LogDebug("[SLManager_C] All winners closed by SL — cleanup triggered.");
      // Close any remaining loser positions
      for(int i = 0; i < ArraySize(gC_LoserTickets); i++)
         ClosePosition(gC_LoserTickets[i]);
      ResetSLManager_C();
      state.slApplied = false;
      // Signal coordinator to run refill check
      state.cleanupInProgress = true;
     }
}

//+------------------------------------------------------------------+
//| Check SL trigger and arm if conditions met                       |
//| Call after every order fill and on every tick                   |
//+------------------------------------------------------------------+
void ProcessSLManager_C(GridState &state)
{
   if(gC_ABWCLArmed)
     {
      // Already armed — just trail
      TrailWall_C(state);
      return;
     }

   // Update basket profit
   state.basketProfit = CalculateBasketProfit(state.magicNumber);

   // Check trigger conditions
   bool triggered = false;
   if(InpSLTriggerByLot    && state.currentBlockLot >= InpSLTriggerLot) triggered = true;
   if(InpSLTriggerByProfit && state.basketProfit > 0)                   triggered = true;

   if(!triggered) return;

   // Arm
   ArmStyleC(state);
}

#endif

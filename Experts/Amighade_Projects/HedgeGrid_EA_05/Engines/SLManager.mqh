#ifndef SL_MANAGER_MQH
#define SL_MANAGER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| SHARED: Determine winning side by profit                         |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetWinningDirection(GridState &state)
{
   double buyP  = CalculateDirectionProfit(POSITION_TYPE_BUY,  state.magicNumber);
   double sellP = CalculateDirectionProfit(POSITION_TYPE_SELL, state.magicNumber);
   state.basketBuyProfit  = buyP;
   state.basketSellProfit = sellP;
   return (buyP >= sellP) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| SHARED: SL level = breakeven-safe grid level                     |
//|                                                                  |
//| Find the closest position (by entry price) on winning side       |
//| such that: (profit of all positions at that SL level)            |
//|            - commission - spread >= 0                            |
//| SL is placed AT that position's entry price (previous grid hit)  |
//+------------------------------------------------------------------+
double CalculateSafeGridSL(ENUM_POSITION_TYPE winnerSide, int magicNumber)
{
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double spread  = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(tickSz <= 0 || tickVal <= 0) return 0.0;
   double moneyPerPrice = tickVal / tickSz;

   // Collect all positions
   struct PosInfo { double entryPrice; double lot; int type; };
   PosInfo positions[];
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      ArrayResize(positions, count+1);
      positions[count].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      positions[count].lot        = PositionGetDouble(POSITION_VOLUME);
      positions[count].type       = (int)PositionGetInteger(POSITION_TYPE);
      count++;
     }
   if(count == 0) return 0.0;

   // Collect winner side entry prices as candidate SL levels
   // sorted closest to current price first
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double candidates[];
   int    candCount = 0;
   for(int i = 0; i < count; i++)
     {
      if(positions[i].type != (int)winnerSide) continue;
      ArrayResize(candidates, candCount+1);
      candidates[candCount++] = positions[i].entryPrice;
     }
   if(candCount == 0) return 0.0;

   // Sort candidates: closest to current price first
   for(int a = 0; a < candCount-1; a++)
      for(int b = a+1; b < candCount; b++)
        {
         bool swap = (winnerSide==POSITION_TYPE_BUY) ?
                     candidates[b] > candidates[a] :  // BUY: highest entry = closest to price
                     candidates[b] < candidates[a];   // SELL: lowest entry = closest to price
         if(swap) { double tmp=candidates[a]; candidates[a]=candidates[b]; candidates[b]=tmp; }
        }

   // Test each candidate SL level — find closest one where net >= 0
   for(int c = 0; c < candCount; c++)
     {
      double slCandidate = candidates[c];
      double netPnL = 0.0;

      for(int i = 0; i < count; i++)
        {
         double entry = positions[i].entryPrice;
         double lot   = positions[i].lot;
         int    type  = positions[i].type;

         // PnL at this SL level
         double priceDiff = (type==POSITION_TYPE_BUY) ?
                            slCandidate - entry :
                            entry - (slCandidate + spread);

         netPnL += priceDiff * moneyPerPrice * lot;
         netPnL -= InpCommissionPerLot * lot; // commission per round turn
        }

      if(netPnL >= 0.0)
        {
         // Validate broker minimum stop distance
         double minStop = MinStopDistancePrice(_Symbol);
         double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         bool   ok      = (winnerSide==POSITION_TYPE_BUY) ?
                          slCandidate <= bid - minStop :
                          slCandidate >= ask + minStop;
         if(ok) return AlignToTick(_Symbol, slCandidate);
        }
     }
   return 0.0; // no safe level found
}

//+------------------------------------------------------------------+
//| SHARED: Apply SL to winning side positions                       |
//| Returns count of positions that received SL                      |
//+------------------------------------------------------------------+
int ApplySLToWinners(ENUM_POSITION_TYPE winnerSide, double slLevel,
                     int magicNumber)
{
   int    count  = 0;
   double slNorm = NormalizeDouble(slLevel, _Digits);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != winnerSide) continue;
      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(oldNorm == slNorm && slNorm > 0.0) { count++; continue; }
      if(ModifyPositionSL(t, slLevel)) count++;
     }
   return count;
}

//+------------------------------------------------------------------+
//| SHARED: Check SL trigger (lot threshold or profit positive)      |
//+------------------------------------------------------------------+
bool CheckSLTrigger(GridState &state)
{
   if(state.slApplied) return false;
   if(InpSLTriggerByLot    && state.currentBlockLot >= InpSLTriggerLot) return true;
   if(InpSLTriggerByProfit && state.basketProfit > 0)                   return true;
   return false;
}

//+------------------------------------------------------------------+
//| STYLE A/B SL processing                                          |
//+------------------------------------------------------------------+
void ProcessSLManager_AB(GridState &state)
{
   state.basketProfit = CalculateBasketProfit(state.magicNumber);
   if(!CheckSLTrigger(state)) return;

   ENUM_POSITION_TYPE winnerSide = GetWinningDirection(state);
   double slLevel = CalculateSafeGridSL(winnerSide, state.magicNumber);
   if(slLevel <= 0) return;

   int applied = ApplySLToWinners(winnerSide, slLevel, state.magicNumber);
   if(applied > 0)
     {
      state.slApplied    = true;
      state.slLevel      = slLevel;
      state.slWinnerSide = (int)winnerSide;
      LogSLTriggered("AB_SL_APPLIED", slLevel);
     }
}

//+------------------------------------------------------------------+
//| STYLE C: ABWCL snapshot stored in state arrays via index         |
//| We use state flags only — no cross-engine calls                  |
//|                                                                  |
//| Trail logic: same SL grid level approach                         |
//| On winner SL hit: state.c_SLHitDetected = true → coordinator    |
//|   closes loser positions directly, then calls CheckAndRefill     |
//+------------------------------------------------------------------+

// Internal arrays for Style C epoch — owned by SLManager, accessed only here
ulong g_c_WinnerTickets[];
ulong g_c_LoserTickets[];

void SnapshotEpoch_C(int magicNumber, int winnerSide)
{
   ArrayResize(g_c_WinnerTickets, 0);
   ArrayResize(g_c_LoserTickets,  0);
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == winnerSide)
        { int sz=ArraySize(g_c_WinnerTickets); ArrayResize(g_c_WinnerTickets,sz+1); g_c_WinnerTickets[sz]=t; }
      else
        { int sz=ArraySize(g_c_LoserTickets);  ArrayResize(g_c_LoserTickets, sz+1); g_c_LoserTickets[sz]=t;  }
     }
}

bool AllClosed_C()
{
   for(int i = 0; i < ArraySize(g_c_WinnerTickets); i++)
      if(PositionSelectByTicket(g_c_WinnerTickets[i])) return false;
   return true;
}

// Called by coordinator to close loser positions after SL hit
void CloseLoserPositions_C(int magicNumber)
{
   for(int i = 0; i < ArraySize(g_c_LoserTickets); i++)
     {
      if(PositionSelectByTicket(g_c_LoserTickets[i]))
         ClosePosition(g_c_LoserTickets[i]);
     }
}

void ResetSLManager_C()
{
   ArrayResize(g_c_WinnerTickets, 0);
   ArrayResize(g_c_LoserTickets,  0);
}

void ArmStyleC(GridState &state)
{
   ENUM_POSITION_TYPE winnerSide = GetWinningDirection(state);
   double slLevel = CalculateSafeGridSL(winnerSide, state.magicNumber);
   if(slLevel <= 0) return;

   SnapshotEpoch_C(state.magicNumber, (int)winnerSide);

   int applied = ApplySLToWinners(winnerSide, slLevel, state.magicNumber);
   if(applied == 0) return;

   state.c_ABWCLArmed = true;
   state.slApplied    = true;
   state.slLevel      = slLevel;
   state.slWinnerSide = (int)winnerSide;
   LogSLTriggered("STYLE_C_ARMED", slLevel);
}

void TrailWall_C(GridState &state)
{
   if(!state.c_ABWCLArmed) return;

   // New SL level = next safe grid level closer to current price
   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)state.slWinnerSide;
   double newSL = CalculateSafeGridSL(winnerSide, state.magicNumber);

   // Monotonic: only trail if it improves the wall
   bool improved = (winnerSide==POSITION_TYPE_BUY) ?
                   (newSL > state.slLevel) : (newSL < state.slLevel);

   if(newSL > 0 && improved)
     {
      int applied = ApplySLToWinners(winnerSide, newSL, state.magicNumber);
      if(applied > 0) state.slLevel = newSL;
     }

   // Check if all winners closed by SL
   if(AllClosed_C())
     {
      // Signal coordinator — it will close losers and trigger refill
      state.c_SLHitDetected = true;
      state.c_ABWCLArmed    = false;
      LogDebug("[SLManager_C] All winners SL hit — signalling coordinator.");
     }
}

void ProcessSLManager_C(GridState &state)
{
   if(state.c_ABWCLArmed) { TrailWall_C(state); return; }
   state.basketProfit = CalculateBasketProfit(state.magicNumber);
   if(!CheckSLTrigger(state)) return;
   ArmStyleC(state);
}

//+------------------------------------------------------------------+
//| MASTER — routes by style                                         |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
{
   if(InpStrategyStyle == STYLE_C) ProcessSLManager_C(state);
   else                            ProcessSLManager_AB(state);
}

#endif

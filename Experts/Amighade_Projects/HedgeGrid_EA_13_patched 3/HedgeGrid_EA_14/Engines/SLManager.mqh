//+------------------------------------------------------------------+
//| SLManager.mqh                                                     |
//| BRICK 6: add SL to the winning side once armed, then trail it.   |
//| Gated by InpEnableSL. Unified — every combo uses the same         |
//| arm -> snapshot -> trail -> all-closed -> cleanup pipeline that   |
//| used to be Style-C-only. No more separate "AB path"/"C path".    |
//|                                                                    |
//| Trigger: arms as soon as the leading side's basket profit > 0.   |
//| ASSUMPTION (flagged for confirmation): the old InpSLTriggerByLot /|
//| InpSLTriggerByProfit toggles were dropped per your instruction;  |
//| "profit > 0" is the only trigger left, applied unconditionally   |
//| whenever InpEnableSL is true. Tell me if you want this gated       |
//| further and I'll add an input back.                              |
//|                                                                    |
//| SL PLACEMENT (Bug fix #5 applied — struct moved to file scope):  |
//|   Candidates are grid lines stepping back from the winning side's|
//|   most recent fill, in InpGridSpacing increments. Each candidate |
//|   is tested with the same net-PnL-safe formula (entries, lots,  |
//|   commission, spread, broker min-stop-distance). The largest n   |
//|   for which the test still passes is maxValidN.                  |
//|     SL_LAST_HIT_GRID : always n=1 (last hit's own grid line),    |
//|                        no search beyond it.                      |
//|     SL_N_BACK_GRID   : n = MIN(InpSLNBack, maxValidN) — depth-   |
//|                        clamped to the farthest still-safe line.  |
//|                                                                    |
//| TRAILING (Bug fix #6 applied):                                    |
//|   The full net-PnL search above is heavy (loops every position   |
//|   per candidate) and only runs at arm time and whenever an armed |
//|   winner CLOSES (position set changed, so the safe level might   |
//|   change too). Per-tick trailing is a cheap, purely arithmetic   |
//|   step: if price has advanced past the next grid line beyond the |
//|   current SL, move the SL forward by one InpGridSpacing step —   |
//|   no position loop, no PnL recompute.                            |
//|                                                                    |
//| RE-SNAPSHOT (per your instruction): the armed-winner ticket set   |
//|   is re-captured on every new fill while armed (ReSnapshotIfArmed,|
//|   called by the coordinator on every DEAL_ENTRY_IN), not just     |
//|   once at arm time — closes the "new fill mid-epoch falls through |
//|   the cracks" gap.                                                |
//|                                                                    |
//| BROKER FAULT (updated): if ModifyPositionSL fails after its one   |
//|   immediate retry (no Sleep), that ticket is closed instead of    |
//|   nuking the whole basket. TriggerSafetyStop only fires if the    |
//|   close itself also fails (unprotectable AND unclosable).         |
//|   See ApplySLToWinners for the full reasoning.                    |
//+------------------------------------------------------------------+
#ifndef SL_MANAGER_MQH
#define SL_MANAGER_MQH

#include "SLGridFeasibility.mqh"
#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/SafetyNet.mqh"

//--- Struct at file scope (Bug fix #5 — MQL5 forbids struct-in-function)
struct SLPosInfo
  {
   double entryPrice;
   double lot;
   int    type;
  };

//--- Armed-epoch winner ticket set — owned by this engine only
ulong g_ArmedWinnerTickets[];

//+------------------------------------------------------------------+
//| Determine winning side by profit                                  |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetWinningDirection(GridState &state)
{
   double buyP  = state.basketBuyProfit;
   double sellP = state.basketSellProfit;
   return (buyP >= sellP) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| Collect all open positions for this EA into a flat array          |
//+------------------------------------------------------------------+
int CollectAllPositions(int magicNumber, SLPos &positions[])
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      ArrayResize(positions, count+1);
      positions[count].ticket = t;
      positions[count].entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      positions[count].lot    = PositionGetDouble(POSITION_VOLUME);
      positions[count].type   = (int)PositionGetInteger(POSITION_TYPE);
      count++;
     }
   return count;
}
   
//+------------------------------------------------------------------+
//| Net PnL of the whole basket if closed at candidateSL              |
//+------------------------------------------------------------------+
double NetPnLAtCandidate(double candidateSL, ENUM_POSITION_TYPE winnerSide,
                         const SLPosInfo &positions[], int count,
                         double moneyPerPrice, double spread)
{
   double netPnL = 0.0;
   for(int i = 0; i < count; i++)
     {
      double entry = positions[i].entryPrice;
      double lot   = positions[i].lot;
      int    type  = positions[i].type;

      double priceDiff = (type == POSITION_TYPE_BUY) ?
                         candidateSL - entry :
                         entry - (candidateSL + spread);

      netPnL += priceDiff * moneyPerPrice * lot;
      netPnL -= InpCommissionPerLot * lot;
     }
   return netPnL;
}

//+------------------------------------------------------------------+
//| Cheap existence/count check for CalculateSLCandidate's guard.     |
//| None of the live ENUM_SL_MODE branches in SL_FindCandidate read   |
//| the position list itself (only the two commented-out legacy       |
//| modes did, and those enum values no longer even exist in          |
//| Inputs.mqh) — so building/copying the full array via               |
//| CollectAllPositions on every call was pure overhead. This counts   |
//| the same filtered set (symbol + magic) with no ArrayResize and no  |
//| per-field reads.                                                   |
//+------------------------------------------------------------------+
int CountMatchingPositions(int magicNumber)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      count++;
     }
   return count;
}

//+------------------------------------------------------------------+
//| Grid-line SL candidate search (Brick 6 core algorithm)            |
//+------------------------------------------------------------------+
double CalculateSLCandidate(GridState &state, ENUM_POSITION_TYPE winnerSide, int magicNumber,
                            ENUM_SL_MODE mode)
{
   int count = CountMatchingPositions(magicNumber);
   if(count <= 0) return 0;
   SLPos list[]; // intentionally left empty — no live SL mode reads it, see note above
   return SL_FindCandidate(state, list, count, winnerSide, magicNumber, mode);
}
//+------------------------------------------------------------------+
//| Apply SL to every ticket in the armed-winner snapshot.            |
//| Returns applied count (0..N). A ticket that can't be protected is |
//| closed instead (see below) — it no longer aborts the whole batch, |
//| so this never returns -1 anymore. The -1 checks in ArmSL/TrailWall|
//| are kept as harmless dead guards rather than ripped out.          |
//|                                                                    |
//| Design change (agreed): a modify failure used to be treated as a  |
//| basket-wide emergency (TriggerSafetyStop closes/deletes           |
//| everything). That's a wildly disproportionate response to one     |
//| ticket getting rejected. New behavior:                            |
//|   1. ModifyPositionSL already pre-validates via ValidateStopPrice |
//|      and now does at most one immediate retry, no Sleep.          |
//|   2. If it still fails, close JUST that ticket instead of the     |
//|      whole basket. A ticket closed this way looks identical to    |
//|      one closed by a real SL hit to AllWinnersClosed() / the rest |
//|      of this file — no special-casing needed elsewhere.           |
//|   3. Only if the close ALSO fails (now genuinely unprotectable    |
//|      AND unclosable) do we escalate to TriggerSafetyStop — that   |
//|      case still deserves the nuclear response.                    |
//+------------------------------------------------------------------+
int ApplySLToWinners(double slLevel, GridState &state)
{
   int    count  = 0;
   double slNorm = NormalizeDouble(slLevel, _Digits);

   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
     {
      ulong t = g_ArmedWinnerTickets[i];
      if(!PositionSelectByTicket(t)) continue; // already closed, skip

      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(oldNorm == slNorm && slNorm > 0.0) { count++; continue; }

      if(ModifyPositionSL(t, slLevel))
        {
         count++;
         continue;
        }

      // Modify failed even after ModifyPositionSL's own one retry.
      // Can't protect it -> close it, rather than nuke the whole basket.
      LogDebug(StringFormat("SL_MODIFY_FAILED ticket=%I64u -> closing position instead", t));
      if(!ClosePosition(t))
        {
         // Genuinely unprotectable AND unclosable — this is the case
         // that still warrants the emergency stop.
         TriggerSafetyStop(state, StringFormat("SL_MODIFY_AND_CLOSE_FAILED ticket=%I64u", t));
         return -1;
        }
     }
   return count;
}

//+------------------------------------------------------------------+
//| Snapshot every current winner-side position into the armed set.  |
//| Applies to ALL positions on that side regardless of individual   |
//| P/L (per design: SL applies to the whole winning-side basket).   |
//+------------------------------------------------------------------+
void SnapshotWinners(int magicNumber, ENUM_POSITION_TYPE winnerSide)
{
   ArrayResize(g_ArmedWinnerTickets, 0);
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != winnerSide) continue;

      int sz = ArraySize(g_ArmedWinnerTickets);
      ArrayResize(g_ArmedWinnerTickets, sz+1);
      g_ArmedWinnerTickets[sz] = t;
     }
}

//+------------------------------------------------------------------+
//| Re-snapshot on every new fill while armed (closes the epoch gap).|
//| Call from coordinator on every DEAL_ENTRY_IN.                    |
//+------------------------------------------------------------------+
void ReSnapshotIfArmed(GridState &state)
{
   if(!state.slWallArmed) return;
   SnapshotWinners(state.magicNumber, (ENUM_POSITION_TYPE)state.slWinnerSide);
}

//+------------------------------------------------------------------+
//| True once every armed winner ticket has closed.                  |
//+------------------------------------------------------------------+
bool AllWinnersClosed()
{
   if(ArraySize(g_ArmedWinnerTickets) == 0) return false; // never armed / nothing to check
   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
      if(PositionSelectByTicket(g_ArmedWinnerTickets[i])) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Reset SL engine state — call after a cycle fully completes.      |
//+------------------------------------------------------------------+
void ResetSLManager(GridState &state)
{
   ArrayResize(g_ArmedWinnerTickets, 0);
   state.slAllWinnersClosed = false;
   state.slApplied = false;
   state.slLevel = 0;
   state.slWallArmed = false;
   state.slWinnerSide = -1;
}

//+------------------------------------------------------------------+
//| Arm the SL wall: compute initial safe level, snapshot, apply.    |
//+------------------------------------------------------------------+
void ArmSL(GridState &state)
{
   ENUM_POSITION_TYPE winnerSide = GetWinningDirection(state);
   double slLevel = CalculateSLCandidate(state, winnerSide, state.magicNumber, InpSLArmMode);

   if(slLevel <= 0) return; // not safe yet, try again next tick

   SnapshotWinners(state.magicNumber, winnerSide);
   if(ArraySize(g_ArmedWinnerTickets) == 0) return;

   int applied = ApplySLToWinners(slLevel, state);
   if(applied < 0) return; // safety stop already triggered
   if(applied == 0) return;

   state.slWallArmed  = true;
   state.slApplied    = true;
   state.slLevel      = slLevel;
   state.slWinnerSide = (int)winnerSide;
   LogSLTriggered("SL_ARMED", slLevel);
}

//+------------------------------------------------------------------+
//| Cheap per-tick trail: step SL forward by one grid spacing when   |
//| price has advanced past the next line. No position/PnL loop.    |
//+------------------------------------------------------------------+
void TrailWall_orgn(GridState &state)
{
   if(!state.slWallArmed) return;

   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)state.slWinnerSide;
   double price = (winnerSide == POSITION_TYPE_BUY) ?
                  SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double newSL = state.slLevel;
   bool   stepped = false;

   ReSnapshotIfArmed(g_state);
      
   // Step forward one grid line at a time while price has passed the next one
   while(true)
     {
      double nextLevel = (winnerSide == POSITION_TYPE_BUY) ?
                         newSL + InpGridSpacing : newSL - InpGridSpacing;
      bool passed = (winnerSide == POSITION_TYPE_BUY) ?
                    (price > nextLevel) : (price < nextLevel);
      if(!passed) break;
      newSL = AlignToTick(_Symbol, nextLevel);
      stepped = true;
     }

   if(stepped)
     {
      int applied = ApplySLToWinners(newSL, state);
      if(applied < 0) return; // safety stop already triggered
      if(applied > 0) state.slLevel = newSL;
     }

   // Check if all armed winners have closed (SL hit) -> signal coordinator
   if(AllWinnersClosed())
     {
      state.slAllWinnersClosed = true;
      state.slWallArmed        = false;
      LogDebug("[SLManager] All armed winners closed — signalling coordinator to start cleanup.");
     }
}

void TrailWall(GridState &state)
{
   //ENUM_POSITION_TYPE winnerSide = GetWinningDirection(state);
   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)state.slWinnerSide;
   double slLevel = CalculateSLCandidate(state, winnerSide, state.magicNumber, InpSLTrailMode);

   if(slLevel <= 0) return; // not safe yet, try again next tick

   // Perf: removed the unconditional SnapshotWinners() call that used to
   // sit here -- it re-scanned every open position every tick, but the
   // armed-winner set only ever changes on a new fill, which is already
   // captured correctly and exclusively via ReSnapshotIfArmed (called
   // from the coordinator on every fill while armed) and the initial
   // snapshot in ArmSL. Re-running it here every tick just rebuilt the
   // same array over and over for no reason.
   if(ArraySize(g_ArmedWinnerTickets) == 0) return;

   int applied = ApplySLToWinners(slLevel, state);
   if(applied < 0) return; // safety stop already triggered
   if(applied == 0) return;
   
   ulong t = g_ArmedWinnerTickets[0];
   if(!PositionSelectByTicket(t))
   {
   ResetSLManager(state);
   } 
   else
   {
   slLevel = PositionGetDouble(POSITION_SL);
   
   state.slWallArmed  = true;
   state.slApplied    = true;
   state.slLevel      = slLevel;
   state.slWinnerSide = (int)winnerSide;
   LogSLTriggered("SL_ARMED", slLevel);
   }
}
//+------------------------------------------------------------------+
//| Called by coordinator when an armed winner closes (DEAL_ENTRY_OUT|
//| while armed) — position set changed, so re-run the heavy safe-   |
//| level search once and re-apply (Bug fix #6: not on every tick).  |
//+------------------------------------------------------------------+
//to be checked
void RecalcOnWinnerClose(GridState &state)
{
   if(!state.slWallArmed) return;

   if(AllWinnersClosed())
     {
      ArrayResize(g_ArmedWinnerTickets, 0);
      state.slAllWinnersClosed = true;
      state.slApplied = false;
      state.slLevel = 0;
      state.slWallArmed = false;
      state.slWinnerSide = -1;
      LogDebug("[SLManager] All armed winners closed — signalling coordinator to start cleanup.");
     }
}
//+------------------------------------------------------------------+
//| Master entry point. No-op unless InpEnableSL is true.            |
//| Call every tick from coordinator.                                 |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
{
   double net = state.basketProfit;
   //if (InpRunawayN > 0 && state.passCounter >= InpRunawayN) net = state.basketProfit;
   
   if(state.slWallArmed)
     {
      if(InpSLTrailMode != SL_NONE) TrailWall(state);
      return;
     }

   if(InpSLArmMode == SL_NONE) return;
   if(net <= 0) return;
   ArmSL(state);
}
#endif

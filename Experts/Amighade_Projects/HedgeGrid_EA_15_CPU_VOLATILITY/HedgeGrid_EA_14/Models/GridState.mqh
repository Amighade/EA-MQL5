#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

enum EA_MODE
{
   MODE_RUNNING = 0,
   MODE_PAUSED,
   MODE_SHUTDOWN
};

struct GridState
  {
   bool           outsideRefillPending;
   //--- Cycle state
   bool           cycleActive;
   bool           gridPlaced;
   int            passCounter;       // used by Brick 1 (lot increase mode A)
   ENUM_LOT_MODE  lotMode;
   bool needsGridVerification;

   //--- Grid anchors
   double         anchorBuy;
   double         anchorSell;

   //--- Last hit tracking
   ENUM_ORDER_TYPE lastHitDirection;
   ENUM_ORDER_TYPE prevHitDirection;
   double          lastHitLot;
   double          lastHitPrice;
   double          prevHitPrice;
   datetime        lastHitTime;
   ulong           lastHitTicket;

   //--- Farthest hit tracking (Brick 2: SHIFT_FARTHEST_HIT)
   double         farthestHitBuy;    // farthest (highest) BUY fill price this cycle
   double         farthestHitSell;   // farthest (lowest) SELL fill price this cycle

   //--- Block lot tracking (Brick 1)
   double         currentBlockLot;
   
   //--- Level revisit tracking (Brick 1, Mode B: level increment)
   double         levelPrices[];
   int            levelVisitCount[];
   int            levelLastSide[];   // 0 = sell, 1 = buy, -1 = none

   //--- Level pass tracking
   double         levelBaseLot[];    // parallel to levelPrices[] — captured once, first fill only
   double         runLevels[];
   int            runSide;           // 0 = none yet, 1 = buy, 2 = sell

   //--- Basket tracking
   double         basketProfit;
   double         basketNetProfit;
   double         basketBuyProfit;
   double         basketSellProfit;

   // [REV-2026-09-12-BACKBONE] why: O(1) per-side profit tracking to
   // replace the full-position-loop CalculateBasketProfits() for the
   // pre-arm decision. Maintained incrementally by
   // OrderMonitor::UpdateSideVolumeAggregate on every fill/close.
   // Frozen (no longer updated) for the winner side once armed --
   // trailing doesn't need live profit (confirmed). Loser side keeps
   // updating post-arm ONLY if InpCloseLosersAtArm is false (losers
   // deliberately left open), so the candidate-net-check in
   // SL_FindCandidate still sees real numbers in that mode. Reset to 0
   // at BuildGrid (fresh grid) and at successful arm (see ArmSL).
   double         buyVolume;
   double         buyAvgEntry;
   double         sellVolume;
   double         sellAvgEntry;

   // [REV-2026-09-12-BACKBONE] why: OnTradeTransaction only records this
   // fact (a winner-side SL/SO hit) -- OnTick is the only place that
   // acts on it (starts cleanup), per the "transactions record, ticks
   // decide" rule agreed this session.
   bool           winnerStoppedOut;

   //--- SL state (Brick 6)
   bool           slApplied;
   double         slLevel;
   int            slWinnerSide;      // POSITION_TYPE_BUY or SELL — side that got SL
   bool           slWallArmed;       // SL wall armed (winners flagged to receive SL)
   bool           slAllWinnersClosed;// set true once all armed winners have closed (triggers cleanup)

   //--- Refill flag (Brick 4/5, set by GridBuilder side, read by coordinator)
   bool           refillNeeded;

   //--- Cleanup state
   ENUM_CLEANUP_MODE cleanupType;
   bool           cleanupInProgress;
   int            cleanupStep;
   // [REV-2026-09-11-CPU-FIX] why: added to let OnTick's cleanup-reconciliation
   // scan (a full CountPositions() loop) run every ~2s instead of every tick.
   datetime       lastCleanupUnstickCheck;   // throttles the OnTick reconciliation scan below

   // [REV-2026-09-13-CLOSE-SAFETY] why: distinguishes "still progressing
   // normally via real confirmations" from "genuinely stuck, nothing has
   // changed since the last check" -- only the latter should trigger a
   // retry + eventually an alarm. Reset to 0 the moment progress resumes.
   int            lastCleanupRemainingCount;
   int            cleanupStuckCount;

   // [REV-2026-09-13-CLOSE-SAFETY] why: the loser-purge-at-arm sequence,
   // structurally the same paced-close pattern ExecuteNextCloseStep
   // already uses for winners, reused rather than duplicated. No
   // ordering needed (no profit-sequence rationale for losers) -- plain
   // ticket list. Used for BOTH InpCloseStyle settings: bulk mode
   // does a best-effort CloseAllPositionsBySide first, then this sequence
   // is (re)built from whatever's still open -- empty if bulk fully
   // worked, so the recheck mechanism is identical either way.
   ulong          loserPurgeSequence[];
   int            loserPurgeIndex;
   bool           loserPurgeInProgress;
   int            lastLoserPurgeRemainingCount;
   int            loserPurgeStuckCount;

   //--- Margin/session/fault
   bool           marginWarning;
   bool           sessionAllowed;
   bool           gapFaultDetected;

   // [REV-2026-09-15-CPU-VOLATILITY] why: these timestamps/price snapshots
   // let the coordinator and SL engine reject repeated housekeeping work
   // before they touch broker state. They are intentionally transient; no
   // trading decision depends on restoring them after a terminal restart.
   datetime       lastSessionCheckMinute;   // cached IsSessionAllowed() bucket
   ulong          lastSLTrailMs;            // last heavy trail calculation
   double         lastSLTrailPrice;         // price used for that calculation

   //--- New-candle detection (shared, per consumer, see Utils/BarUtils.mqh)
   datetime       lastBarGridCheck;
   datetime       lastBarRecenter;
   datetime       lastBarGridFirstSL;

   //--- Magic number
   int            magicNumber;
   
   //--- Ea Mode
   EA_MODE        mode;
   
   //--- Cleanup close sequence (built once per cleanup, drained, rescanned when empty)
   ulong          closeSequence[];
   int            closeIndex;
   
  };

void ResetGridState(GridState &state)
  {
   state.cycleActive        = false;
   state.gridPlaced         = false;
   state.passCounter        = 0;
   state.lotMode            = LOT_FULL;
   state.anchorBuy          = 0.0;
   state.anchorSell         = 0.0;
   state.lastHitDirection   = WRONG_VALUE;
   state.prevHitDirection   = WRONG_VALUE;
   state.lastHitLot         = 0.0;
   state.lastHitPrice       = 0.0;
   state.prevHitPrice       = 0.0;
   state.lastHitTime        = 0;
   state.lastHitTicket      = 0;
   state.farthestHitBuy     = 0.0;
   state.farthestHitSell    = 0.0;
   state.currentBlockLot    = 0.0;
   state.basketProfit       = 0.0;
   state.basketNetProfit    = 0.0;
   state.basketBuyProfit    = 0.0;
   state.basketSellProfit   = 0.0;
   state.buyVolume          = 0.0;
   state.buyAvgEntry        = 0.0;
   state.sellVolume         = 0.0;
   state.sellAvgEntry       = 0.0;
   state.winnerStoppedOut   = false;
   state.slApplied          = false;
   state.slLevel            = 0.0;
   state.slWinnerSide       = -1;
   state.slWallArmed        = false;
   state.slAllWinnersClosed = false;
   state.refillNeeded       = false;
   state.cleanupType        = InpCleanupMode;
   state.cleanupInProgress  = false;
   state.cleanupStep        = 0;
   state.lastCleanupUnstickCheck = 0;
   state.lastCleanupRemainingCount = -1;
   state.cleanupStuckCount = 0;
   ArrayResize(state.loserPurgeSequence, 0);
   state.loserPurgeIndex = 0;
   state.loserPurgeInProgress = false;
   state.lastLoserPurgeRemainingCount = -1;
   state.loserPurgeStuckCount = 0;
   state.marginWarning      = false;
   state.sessionAllowed     = false;
   state.gapFaultDetected   = false;
   state.lastSessionCheckMinute = 0;
   state.lastSLTrailMs          = 0;
   state.lastSLTrailPrice       = 0.0;
   state.mode               = MODE_RUNNING;
   state.runSide            = 0;
   ArrayResize(state.levelPrices, 0);
   ArrayResize(state.levelVisitCount, 0);
   ArrayResize(state.levelLastSide, 0);
   ArrayResize(state.levelBaseLot, 0);
   ArrayResize(state.runLevels, 0);
   ArrayResize(state.closeSequence, 0);
   state.closeIndex = 0;
   state.needsGridVerification = false;
   // lastBarGridCheck / lastBarRecenter NOT reset — candle trackers persist across cycles
   // magicNumber NOT reset — set once in OnInit
  }

#endif

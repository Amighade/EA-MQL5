#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

enum EA_MODE
{
   MODE_RUNNING = 0,
   MODE_PAUSED,
   MODE_SHUTDOWN
};

// Pending cleanup request record. Kept outside GridState so the type can
// be reused cleanly by the cleanup engine and remains easy to inspect.
struct CleanupPendingRequest
  {
   ulong ticket;
   ulong requestId;
   int   kind;       // 0 = position close, 1 = pending-order delete
   ulong sentAtMs;
  };

struct GridState
  {
   bool           outsideRefillPending;
   //--- Cycle state
   bool           cycleActive;
   bool           gridPlaced;
   int            passCounter;       // used by Brick 1 (lot increase mode A)
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

   //--- Margin/session/fault
   bool           marginWarning;
   bool           sessionAllowed;
   bool           gapFaultDetected;

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
   
   //--- Scheduler / event bridge state ---------------------------------
   MqlTradeTransactionShort g_txQueue[];   // Events are queued; never processed in OnTradeTransaction.
   int  g_txReadIndex;
   bool g_txDirty;

   // OnTick is intentionally lossy for price data: only the latest quote is kept.
   double latestBid;
   double latestAsk;
   datetime latestTickTime;
   ulong latestTickSequence;
   bool marketDirty;

   // One native heartbeat drives all software scheduling tiers.
   ulong g_lastTimeFast;
   ulong g_lastTimeMedium;
   ulong g_lastTimeSlow;
   ulong g_lastTimeBackground;

   //--- Async cleanup requests ----------------------------------------
   // A request can remain in-flight while the scheduler continues other work.
   CleanupPendingRequest cleanupPending[];
   ulong cleanupLastRetryMs;
   ulong cleanupLastRebuildMs;

  };

void ResetGridState(GridState &state)
  {
   state.cycleActive        = false;
   state.gridPlaced         = false;
   state.passCounter        = 0;
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
   state.slApplied          = false;
   state.slLevel            = 0.0;
   state.slWinnerSide       = -1;
   state.slWallArmed        = false;
   state.slAllWinnersClosed = false;
   state.refillNeeded       = false;
   state.cleanupType        = InpCleanupMode;
   state.cleanupInProgress  = false;
   state.cleanupStep        = 0;
   state.marginWarning      = false;
   state.sessionAllowed     = false;
   state.gapFaultDetected   = false;
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
   // Scheduler/event state intentionally survives a trading-cycle reset.
   // ResetGridState is also used after cleanup; clearing queued events here
   // could discard trade events that arrived while the cleanup was finishing.
   // Scheduler initialization/queue clearing is handled explicitly by OnInit/OnDeinit.
   state.g_txReadIndex         = 0;
   state.latestBid             = 0.0;
   state.latestAsk             = 0.0;
   state.latestTickTime        = 0;
   state.latestTickSequence    = 0;
   state.marketDirty           = false;
   ArrayResize(state.cleanupPending, 0);
   state.cleanupLastRetryMs    = 0;
   state.cleanupLastRebuildMs  = 0;
   // lastBarGridCheck / lastBarRecenter NOT reset — candle trackers persist across cycles
   // magicNumber NOT reset — set once in OnInit
  }

#endif

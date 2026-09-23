#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

// Runtime state for one cleanup request. A request being SENT/WAITING is
// deliberately different from the requested trade actually being complete.
// Completion is verified against live terminal state by CleanupReset.mqh.
struct CleanupPendingRequest
  {
   ulong targetTicket;       // Position ticket or pending-order ticket
   uint  requestId;         // Terminal request_id for OrderSendAsync()
   int   action;             // 1 = close position, 2 = delete pending order
   int   attempts;           // Submission attempts; never advances strategy state
   ulong sentAtMs;           // Timestamp of the latest submission
   ulong retryAfterMs;       // Earliest next retry if submission/processing failed
   int   lastRetcode;        // Last request-level server retcode, for diagnostics
   bool  requestAccepted;    // REQUEST transaction confirmed acceptance
  };

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
   bool needsGridVerification;

   //--- Grid anchors
   double         anchorBuy;
   double         anchorSell;

   //--- Last hit tracking
   ENUM_ORDER_TYPE lastHitDirection;
   ENUM_ORDER_TYPE prevHitDirection;
   double         lastHitLot;
   double         lastHitPrice;
   double         prevHitPrice;
   datetime       lastHitTime;
   ulong          lastHitTicket;

   //--- Farthest hit tracking (Brick 2: SHIFT_FARTHEST_HIT)
   double         farthestHitBuy;
   double         farthestHitSell;

   //--- Block lot tracking (Brick 1)
   double         currentBlockLot;
   
   //--- Level revisit tracking (Brick 1, Mode B: level increment)
   double         levelPrices[];
   int            levelVisitCount[];
   int            levelLastSide[];   // 0 = sell, 1 = buy, -1 = none

   //--- Level pass tracking
   double         levelBaseLot[];
   double         runLevels[];
   int            runSide;           // 0 = none yet, 1 = buy, 2 = sell

   //--- Basket tracking
   double         basketProfit;
   double         basketNetProfit;
   double         basketBuyProfit;
   double         basketSellProfit;
   
   double         buyVolume;
   double         buyAvgEntry;
   double         sellVolume;
   double         sellAvgEntry;

   //--- SL state (Brick 6)
   bool           slApplied;
   double         slLevel;
   int            slWinnerSide;
   bool           slWallArmed;
   bool           slAllWinnersClosed;

   //--- Refill flag (Brick 4/5, set by GridBuilder side, read by coordinator)
   bool           refillNeeded;

   //--- Cleanup state
   ENUM_CLEANUP_MODE cleanupType;
   bool           cleanupInProgress;
   int            cleanupStep;
   ulong          closeSequence[];
   int            closeIndex;
   ulong          orderSequence[];
   int            orderIndex;
   CleanupPendingRequest cleanupRequests[];
   ulong          cleanupHandledPositions[]; // Positions intentionally owned by this cleanup

   //--- Margin/session/fault
   bool           marginWarning;
   bool           sessionAllowed;
   bool           gapFaultDetected;

   //--- New-candle detection
   datetime       lastBarGridCheck;
   //datetime       lastBarRecenter;
   datetime       lastBarGridFirstSL;

   //--- Magic number
   int            magicNumber;
   
   //--- EA mode
   EA_MODE        mode;
   
   bool   safetyStopPending;
   bool   safetyAlertPending;
   string safetyStopReason;
  
  };

//+------------------------------------------------------------------+
//| Reset strategy/cycle state.                                      |
//| Scheduler queues live outside GridState so a cycle reset cannot   |
//| accidentally erase transaction events that are still arriving.  |
//+------------------------------------------------------------------+
void ResetGridState(GridState &state)
  {
   state.outsideRefillPending = false;
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
   state.buyVolume          = 0.0;
   state.buyAvgEntry        = 0.0;
   state.sellVolume         = 0.0;
   state.sellAvgEntry       = 0.0;
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
   ArrayResize(state.orderSequence, 0);
   state.orderIndex = 0;
   ArrayResize(state.cleanupRequests, 0);
   // cleanupHandledPositions is intentionally NOT cleared here. A late
   // DEAL_ADD/DEAL_ENTRY_OUT event generated by the just-finished cleanup may
   // still be present in the transaction queue after ResetCycle(). The ticket
   // list is therefore cleared only when the NEXT cleanup sequence starts.

   state.needsGridVerification = false;
   // lastBarGridCheck / lastBarRecenter persist across cycles as before.
   // lastBarGridFirstSL also persists to preserve candle ownership.
   // magicNumber is set once in OnInit and intentionally survives reset.
   state.safetyStopPending    = false;
   state.safetyAlertPending   = false;
   state.safetyStopReason     = "";
  }

#endif

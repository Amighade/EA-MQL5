#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Operational mode — separate from the brick system. This governs  |
//| whether the EA is allowed to grow the grid at all, independent   |
//| of which bricks are enabled. Toggled via the dashboard MODE      |
//| label (click to cycle) — see Dashboard/ChartPanel.mqh.           |
//|   MODE_RUNNING  : normal operation, every enabled brick active.  |
//|   MODE_PAUSED   : "maintenance" — no new builds/refills/shifts/  |
//|                   recenters, but SL management, cleanup          |
//|                   sequences, and emergency close all continue.   |
//|   MODE_SHUTDOWN : same opening-logic freeze as Paused, PLUS the  |
//|                   coordinator repeatedly drives an emergency     |
//|                   close every tick until the account is fully    |
//|                   flat (shutdownFlat becomes true).              |
//| NOT reset by ResetGridState (see below) — a cycle reset (e.g.    |
//| from the emergency close that Shutdown itself triggers) must     |
//| never silently bounce the mode back to Running.                  |
//+------------------------------------------------------------------+
enum ENUM_EA_MODE
  {
   MODE_RUNNING  = 0,
   MODE_PAUSED   = 1,
   MODE_SHUTDOWN = 2,
  };

struct GridState
  {
   //--- Cycle state
   bool           cycleActive;
   bool           gridPlaced;
   int            passCounter;       // used by Brick 1 (lot increase mode A)
   ENUM_LOT_MODE  lotMode;

   //--- Operational mode (Running/Paused/Shutdown) — see enum above
   ENUM_EA_MODE   mode;
   bool           shutdownFlat;      // true once Shutdown has closed everything

   //--- Grid anchors
   double         anchorBuy;
   double         anchorSell;

   //--- Last hit tracking
   ENUM_ORDER_TYPE lastHitDirection;
   double          lastHitLot;
   double          lastHitPrice;
   datetime        lastHitTime;
   ulong           lastHitTicket;

   //--- Farthest hit tracking (Brick 2: SHIFT_FARTHEST_HIT)
   double         farthestHitBuy;    // farthest (highest) BUY fill price this cycle
   double         farthestHitSell;   // farthest (lowest) SELL fill price this cycle

   //--- Block lot tracking (Brick 1)
   double         currentBlockLot;

   //--- Basket tracking
   double         basketProfit;
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

   //--- Magic number
   int            magicNumber;
  };

void ResetGridState(GridState &state)
  {
   state.cycleActive        = false;
   state.gridPlaced         = false;
   state.passCounter        = 0;
   state.lotMode            = LOT_FULL;
   state.anchorBuy          = 0.0;
   state.anchorSell         = 0.0;
   state.lastHitDirection   = ORDER_TYPE_BUY;
   state.lastHitLot         = 0.0;
   state.lastHitPrice       = 0.0;
   state.lastHitTime        = 0;
   state.lastHitTicket      = 0;
   state.farthestHitBuy     = 0.0;
   state.farthestHitSell    = 0.0;
   state.currentBlockLot    = 0.0;
   state.basketProfit       = 0.0;
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
   // lastBarGridCheck / lastBarRecenter NOT reset — candle trackers persist across cycles
   // magicNumber NOT reset — set once in OnInit
   // mode / shutdownFlat NOT reset — Shutdown must survive the very emergency
   // close it triggers; only OnInit sets mode = MODE_RUNNING (a true first start).
  }

//+------------------------------------------------------------------+
//| Call ONCE from OnInit only — sets the initial operational mode.  |
//| Never call this from anywhere a cycle reset happens (that would  |
//| defeat the whole point of excluding mode from ResetGridState).   |
//+------------------------------------------------------------------+
void InitOperationalMode(GridState &state)
  {
   state.mode         = MODE_RUNNING;
   state.shutdownFlat = false;
  }

#endif

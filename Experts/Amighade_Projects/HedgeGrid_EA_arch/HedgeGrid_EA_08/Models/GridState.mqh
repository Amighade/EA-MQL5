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
   //--- Cycle state
   bool           cycleActive;
   bool           gridPlaced;
   int            passCounter;       // used by Brick 1 (lot increase mode A)
   ENUM_LOT_MODE  lotMode;

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
   
   //--- Ea Mode
   EA_MODE        mode;
   
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
   state.mode               = MODE_RUNNING;
   // lastBarGridCheck / lastBarRecenter NOT reset — candle trackers persist across cycles
   // magicNumber NOT reset — set once in OnInit
  }

#endif

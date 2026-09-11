#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

struct GridState
  {
   //--- Cycle state
   bool           cycleActive;
   bool           gridPlaced;
   int            passCounter;
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

   //--- Block lot tracking
   double         currentBlockLot;

   //--- Basket tracking
   double         basketProfit;
   double         basketBuyProfit;
   double         basketSellProfit;

   //--- SL state
   bool           slApplied;
   double         slLevel;
   int            slWinnerSide;    // POSITION_TYPE_BUY or SELL — side that got SL
   ENUM_CLEANUP_TYPE cleanupType;

   //--- Style C ABWCL state (communicated via state, not cross-engine calls)
   bool           c_ABWCLArmed;
   bool           c_SLHitDetected; // set by SLManager, read by coordinator
   bool           c_RefillNeeded;  // set by CleanupReset, read by coordinator
   bool           c_ResetSLNeeded; // set by CleanupReset, read by coordinator

   //--- Cleanup state
   bool           cleanupInProgress;
   int            cleanupStep;

   //--- Margin/session/fault
   bool           marginWarning;
   bool           sessionAllowed;
   bool           gapFaultDetected;

   //--- Magic number
   int            magicNumber;
  };

void ResetGridState(GridState &state)
  {
   state.cycleActive       = false;
   state.gridPlaced        = false;
   state.passCounter       = 0;
   state.lotMode           = LOT_FULL;
   state.anchorBuy         = 0.0;
   state.anchorSell        = 0.0;
   state.lastHitDirection  = ORDER_TYPE_BUY;
   state.lastHitLot        = 0.0;
   state.lastHitPrice      = 0.0;
   state.lastHitTime       = 0;
   state.lastHitTicket     = 0;
   state.currentBlockLot   = 0.0;
   state.basketProfit      = 0.0;
   state.basketBuyProfit   = 0.0;
   state.basketSellProfit  = 0.0;
   state.slApplied         = false;
   state.slLevel           = 0.0;
   state.slWinnerSide      = -1;
   state.cleanupType       = CLEANUP_EMERGENCY;
   state.c_ABWCLArmed      = false;
   state.c_SLHitDetected   = false;
   state.c_RefillNeeded    = false;
   state.c_ResetSLNeeded   = false;
   state.cleanupInProgress = false;
   state.cleanupStep       = 0;
   state.marginWarning     = false;
   state.sessionAllowed    = false;
   state.gapFaultDetected  = false;
   // magicNumber NOT reset — set once in OnInit
  }

#endif

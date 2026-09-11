//+------------------------------------------------------------------+
//| GridState.mqh                                                     |
//| Central state struct shared across ALL engines                   |
//| All engines read and write state through this single struct      |
//| No engine should maintain its own private state variables        |
//+------------------------------------------------------------------+
#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| GRID STATE STRUCT                                                 |
//| One instance of this struct lives in HedgeGrid.mq5               |
//| Passed by reference to every engine function                     |
//+------------------------------------------------------------------+
struct GridState
  {
   //--- Cycle state
   bool           cycleActive;          // True if at least one order has been filled
   bool           gridPlaced;           // True if initial grid orders are placed
   int            passCounter;          // Direction switch counter (0=fresh, 1=first sell pass, 2=first buy pass...)
   ENUM_LOT_MODE  lotMode;             // Current lot mode (FULL or HALF)

   //--- Grid anchors
   double         anchorBuy;           // Price of first (nearest) BUY STOP order
   double         anchorSell;          // Price of first (nearest) SELL STOP order

   //--- Last hit tracking
   ENUM_ORDER_TYPE lastHitDirection;   // Direction of last filled order (ORDER_TYPE_BUY or SELL)
   double          lastHitLot;         // Lot size of last filled order
   double          lastHitPrice;       // Entry price of last filled order
   datetime        lastHitTime;        // Time of last fill
   ulong           lastHitTicket;      // Ticket of last filled order/position

   //--- Block lot tracking
   double         currentBlockLot;     // Current uniform lot size of rebuilt opposite grid
                                       // Example: after BUY 0.03 hit → SELL grid = 0.06 → currentBlockLot = 0.06

   //--- Basket tracking
   double         basketProfit;        // Total floating profit/loss of all open positions
   double         basketBuyProfit;     // Floating profit of BUY positions only
   double         basketSellProfit;    // Floating profit of SELL positions only

   //--- SL state
   bool           slApplied;           // True if SL has been applied to positions this cycle
   double         slLevel;             // SL price level currently applied
   ENUM_CLEANUP_TYPE cleanupType;      // Which cleanup style is active

   //--- Cleanup state
   bool           cleanupInProgress;   // True while confirmation-based close sequence is running
   int            cleanupStep;         // Which step in the close sequence we are on

   //--- Margin state
   bool           marginWarning;       // True if margin warning is active

   //--- Session state
   bool           sessionAllowed;      // True if current time is within allowed session

   //--- Fault state
   bool           gapFaultDetected;    // True if a price gap/skip fault was detected

   //--- Magic number (resolved at OnInit)
   int            magicNumber;         // Actual magic number in use (auto or manual)
  };

//+------------------------------------------------------------------+
//| Initialize GridState to clean defaults                            |
//| Call this on EA start and after every cycle reset                |
//+------------------------------------------------------------------+
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

   state.currentBlockLot    = 0.0;

   state.basketProfit       = 0.0;
   state.basketBuyProfit    = 0.0;
   state.basketSellProfit   = 0.0;

   state.slApplied          = false;
   state.slLevel            = 0.0;
   state.cleanupType        = CLEANUP_EMERGENCY;

   state.cleanupInProgress  = false;
   state.cleanupStep        = 0;

   state.marginWarning      = false;
   state.sessionAllowed     = false;
   state.gapFaultDetected   = false;

   // magicNumber is NOT reset here — set once in OnInit and kept
  }


#endif
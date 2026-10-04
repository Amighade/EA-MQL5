#ifndef GRID_STATE_MQH
#define GRID_STATE_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| REV 30.01                                                        |
//| One GridState describes the complete strategy cycle.             |
//| The FIRST member is the lifecycle of the whole cycle.            |
//| The SECOND member is the ONE array that contains every EA-owned  |
//| pending order / open position and any async action attached to it.|
//+------------------------------------------------------------------+

enum ENUM_GRID_LIFECYCLE
  {
   GRID_IDLE     = 0,  // no cycle, no EA-owned trade object
   GRID_BUILDING = 1,  // initial grid is being requested / confirmed
   GRID_READY    = 2,  // pending grid exists, no position has filled yet
   GRID_ACTIVE   = 3,  // at least one strategy position exists
   GRID_CLEANUP  = 4,  // close positions + delete orders, then return to IDLE
   GRID_FAULT    = 5   // unresolved infrastructure fault; strategy must decide
  };

enum ENUM_TRADE_ITEM_KIND
  {
   ITEM_NONE     = 0,
   ITEM_ORDER    = 1,
   ITEM_POSITION = 2
  };

enum ENUM_ITEM_ACTION
  {
   ACTION_NONE      = 0,
   ACTION_PLACE     = 1,
   ACTION_DELETE    = 2,
   ACTION_CLOSE     = 3,
   ACTION_MODIFY_SL = 4
  };

enum ENUM_ACTION_STATUS
  {
   ACTION_IDLE         = 0,
   ACTION_READY        = 1,
   ACTION_WAIT_RESULT  = 2,
   ACTION_WAIT_CONFIRM = 3,
   ACTION_FAILED       = 4
  };

struct TradeItem
  {
   //--- Stable EA-local identity. Does not change if ORDER becomes POSITION.
   uint                    id;

   //--- What this member represents now.
   ENUM_TRADE_ITEM_KIND    kind;
   ENUM_POSITION_TYPE      side;
   ENUM_ORDER_TYPE         orderType;

   //--- Strategy identity. Optional fields may remain zero/-1 until a brick uses them.
   int                     level;
   double                  targetPrice;
   double                  targetLot;
   double                  originalLot;

   //--- Broker identity / latest live data.
   ulong                   orderTicket;
   ulong                   positionTicket;
   ulong                   lastDealTicket;
   double                  openPrice;
   double                  volume;
   double                  currentSL;
   double                  currentTP;
   bool                    brokerPresent;

   //--- What the strategy currently asks the broker to do.
   ENUM_ITEM_ACTION        action;
   ENUM_ACTION_STATUS      actionStatus;
   double                  requestedPrice;
   double                  requestedLot;
   double                  requestedSL;
   double                  requestedTP;

   //--- Async request/result tracking. Kept on the SAME member.
   uint                    requestId;
   int                     attempts;
   ulong                   sentTimeMs;
   ulong                   resultTimeMs;
   int                     lastRetcode;
   int                     lastError;

   //--- Simple sequencing flags; no second async-request array is needed.
   bool                    cleanupAfterConfirm; // PLACE was already sent when cleanup began
   bool                    replaceAfterDelete;  // delete old order, then place replacement
   double                  replacementPrice;
   double                  replacementLot;
   double                  replacementSL;
   double                  replacementTP;
  };

enum EA_MODE
  {
   MODE_RUNNING = 0,
   MODE_PAUSED,
   MODE_SHUTDOWN
  };

struct GridState
  {
   //=================================================================
   // 1) WHOLE-CYCLE STATUS -- intentionally the first member.
   //=================================================================
   ENUM_GRID_LIFECYCLE     lifecycle;

   //=================================================================
   // 2) ONE TRADE BOOK -- every planned/live order and position.
   //=================================================================
   TradeItem               items[];

   //=================================================================
   // 3) BASIC IDENTITY / BOOKKEEPING.
   //=================================================================
   int                     magicNumber;
   ulong                   cycleId;
   uint                    nextItemId;
   EA_MODE                 mode;

   //=================================================================
   // 4) GRID / STRATEGY STATE -- carried from Rev 22.2 as reference.
   //=================================================================
   bool                    outsideRefillPending;
   bool                    needsGridVerification;
   int                     passCounter;
   double                  anchorBuy;
   double                  anchorSell;

   ENUM_ORDER_TYPE         lastHitDirection;
   ENUM_ORDER_TYPE         prevHitDirection;
   double                  lastHitLot;
   double                  lastHitPrice;
   double                  prevHitPrice;
   datetime                lastHitTime;
   ulong                   lastHitTicket;

   double                  farthestHitBuy;
   double                  farthestHitSell;
   double                  currentBlockLot;

   double                  levelPrices[];
   int                     levelVisitCount[];
   int                     levelLastSide[];
   double                  levelBaseLot[];
   double                  runLevels[];
   int                     runSide;

   //=================================================================
   // 5) BASKET AGGREGATES.
   //=================================================================
   double                  basketProfit;
   double                  basketNetProfit;
   double                  basketBuyProfit;
   double                  basketSellProfit;
   double                  buyVolume;
   double                  buyAvgEntry;
   double                  sellVolume;
   double                  sellAvgEntry;

   //=================================================================
   // 6) SL STRATEGY STATE.
   //=================================================================
   bool                    slApplied;
   double                  slLevel;
   int                     slWinnerSide;
   bool                    slWallArmed;
   bool                    slAllWinnersClosed;

   //=================================================================
   // 7) WORK / SAFETY / SESSION FLAGS.
   //=================================================================
   bool                    refillNeeded;
   bool                    marginWarning;
   bool                    sessionAllowed;
   bool                    gapFaultDetected;
   bool                    safetyStopPending;
   bool                    safetyAlertPending;
   string                  safetyStopReason;
   string                  cleanupReason;

   //=================================================================
   // 8) TIME / CANDLE OWNERSHIP.
   //=================================================================
   datetime                lastBarGridCheck;
   datetime                lastBarGridFirstSL;
  };

//+------------------------------------------------------------------+
//| Reset one TradeItem before filling it.                            |
//+------------------------------------------------------------------+
void ResetTradeItem(TradeItem &item)
  {
   item.id                  = 0;
   item.kind                = ITEM_NONE;
   item.side                = POSITION_TYPE_BUY;
   item.orderType           = (ENUM_ORDER_TYPE)WRONG_VALUE;
   item.level               = -1;
   item.targetPrice         = 0.0;
   item.targetLot           = 0.0;
   item.originalLot         = 0.0;
   item.orderTicket         = 0;
   item.positionTicket      = 0;
   item.lastDealTicket      = 0;
   item.openPrice           = 0.0;
   item.volume              = 0.0;
   item.currentSL           = 0.0;
   item.currentTP           = 0.0;
   item.brokerPresent       = false;
   item.action              = ACTION_NONE;
   item.actionStatus        = ACTION_IDLE;
   item.requestedPrice      = 0.0;
   item.requestedLot        = 0.0;
   item.requestedSL         = 0.0;
   item.requestedTP         = 0.0;
   item.requestId           = 0;
   item.attempts            = 0;
   item.sentTimeMs          = 0;
   item.resultTimeMs        = 0;
   item.lastRetcode         = 0;
   item.lastError           = 0;
   item.cleanupAfterConfirm = false;
   item.replaceAfterDelete  = false;
   item.replacementPrice    = 0.0;
   item.replacementLot      = 0.0;
   item.replacementSL       = 0.0;
   item.replacementTP       = 0.0;
  }

//+------------------------------------------------------------------+
//| Reset strategy/cycle state. magicNumber is intentionally kept.   |
//+------------------------------------------------------------------+
void ResetGridState(GridState &state)
  {
   int savedMagic = state.magicNumber;

   state.lifecycle             = GRID_IDLE;
   ArrayResize(state.items, 0);

   state.magicNumber           = savedMagic;
   state.cycleId               = 0;
   state.nextItemId            = 1;
   state.mode                  = MODE_RUNNING;

   state.outsideRefillPending  = false;
   state.needsGridVerification = false;
   state.passCounter           = 0;
   state.anchorBuy             = 0.0;
   state.anchorSell            = 0.0;
   state.lastHitDirection      = (ENUM_ORDER_TYPE)WRONG_VALUE;
   state.prevHitDirection      = (ENUM_ORDER_TYPE)WRONG_VALUE;
   state.lastHitLot            = 0.0;
   state.lastHitPrice          = 0.0;
   state.prevHitPrice          = 0.0;
   state.lastHitTime           = 0;
   state.lastHitTicket         = 0;
   state.farthestHitBuy        = 0.0;
   state.farthestHitSell       = 0.0;
   state.currentBlockLot       = 0.0;

   ArrayResize(state.levelPrices, 0);
   ArrayResize(state.levelVisitCount, 0);
   ArrayResize(state.levelLastSide, 0);
   ArrayResize(state.levelBaseLot, 0);
   ArrayResize(state.runLevels, 0);
   state.runSide               = 0;

   state.basketProfit          = 0.0;
   state.basketNetProfit       = 0.0;
   state.basketBuyProfit       = 0.0;
   state.basketSellProfit      = 0.0;
   state.buyVolume             = 0.0;
   state.buyAvgEntry           = 0.0;
   state.sellVolume            = 0.0;
   state.sellAvgEntry          = 0.0;

   state.slApplied             = false;
   state.slLevel               = 0.0;
   state.slWinnerSide          = -1;
   state.slWallArmed           = false;
   state.slAllWinnersClosed    = false;

   state.refillNeeded          = false;
   state.marginWarning         = false;
   state.sessionAllowed        = false;
   state.gapFaultDetected      = false;
   state.safetyStopPending     = false;
   state.safetyAlertPending    = false;
   state.safetyStopReason      = "";
   state.cleanupReason         = "";

   // Candle timestamps intentionally survive a cycle reset only when the
   // strategy later chooses to preserve them. Rev 30.01 starts them clean.
   state.lastBarGridCheck      = 0;
   state.lastBarGridFirstSL    = 0;
  }

bool GridIsCleanup(GridState &state)
  {
   return (state.lifecycle == GRID_CLEANUP);
  }

bool GridHasCycle(GridState &state)
  {
   return (state.lifecycle != GRID_IDLE && state.lifecycle != GRID_FAULT);
  }

#endif

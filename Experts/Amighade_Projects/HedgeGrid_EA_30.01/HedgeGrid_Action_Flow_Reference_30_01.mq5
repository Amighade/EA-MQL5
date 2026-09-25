//+------------------------------------------------------------------+
//| HedgeGrid_Action_Flow_Reference_30_01.mq5                        |
//| REV 30.01 - READABLE REFERENCE ONLY                              |
//|                                                                  |
//| This file does NOT control trading and is NOT included by the EA.|
//| Each numbered reference section is a separate function so        |
//| MetaEditor can fold/collapse it with the +/- code-fold control.  |
//+------------------------------------------------------------------+
#property strict
#property version   "30.01"
#property description "REFERENCE ONLY - HedgeGrid Rev 30.01 action flow"

// Prevent accidental use as a trading EA.
int OnInit()
  {
   Print("HedgeGrid Action Flow Reference 30.01 only. Do not attach for trading.");
   return(INIT_FAILED);
  }

//====================================================================
// 01. EA STARTUP
//====================================================================
void REF_01_EA_STARTUP()
  {
   
      OnInit()
      -> ResetGridState(g_state)
            lifecycle = GRID_IDLE
            items[] cleared
      -> magic number / identity prepared
      -> ResetTransactionQueue()
      -> Profiler30Init()
      -> RebuildTradeBookFromTerminal(g_state)
            scan EA-owned pending orders
            scan EA-owned positions
            add each broker object to state.items[]
            if positions exist -> GRID_ACTIVE
            else if orders exist -> GRID_READY
            else -> GRID_IDLE
      -> InitScheduler30()
      -> EventSetMillisecondTimer(...)

      IMPORTANT:
      Restart/reload does not blindly mean GRID_IDLE.
      Existing broker orders/positions rebuild the trade book first.
   
  }

//====================================================================
// 02. EVERY TIMER HEARTBEAT / MAIN LOOP
//====================================================================
void REF_02_TIMER_HEARTBEAT()
  {
   /*
      OnTimer()
      -> RunScheduler30(g_state)

      RunScheduler30 order:

      1) ProcessTransactionQueue()
            MT5 facts -> GridState / TradeItem[]

      2) if safetyStopPending and not already GRID_CLEANUP
            StartCleanup(...)

      3) ProcessPendingActions()
            ACTION_READY items -> OrderSendAsync()

      4) ReconcileTradeItems() when needed
            live broker state confirms results

      5) if GRID_CLEANUP
            ProcessCleanupState()
            if still GRID_CLEANUP -> return; strategy does not run

      6) Strategy_Fast()
         Strategy_Medium()
         Strategy_Background()
            Rev 30.01 strategy hooks are intentionally empty.

      7) FinishSchedulerFrame30()
            CPU/frame profiling
   */
  }

//====================================================================
// 03. ONTRADETRANSACTION -> TRANSACTION QUEUE
//====================================================================
void REF_03_ON_TRADE_TRANSACTION()
  {
   /*
      MT5 trade event
      -> OnTradeTransaction(...)
      -> copy useful trans/request/result fields into TransactionItem
      -> QueueTransaction(tx)
      -> return

      OnTradeTransaction itself does NOT:
         - run grid strategy
         - run SL strategy
         - clean the grid
         - call OrderSendAsync()

      Later, scheduler calls:

      ProcessTransactionQueue()
      -> HandleTransaction(state, tx)

      Dispatcher routes:
         TRADE_TRANSACTION_REQUEST
            -> HandleRequestTransaction()

         TRADE_TRANSACTION_DEAL_ADD
            -> HandleDealTransaction()

         ORDER_ADD / ORDER_UPDATE / ORDER_DELETE
            -> HandleOrderTransaction()

         TRADE_TRANSACTION_POSITION
            -> HandlePositionTransaction()
   */
  }

//====================================================================
// 04. PLACE NEW PENDING ORDER
//====================================================================
void REF_04_PLACE_PENDING_ORDER()
  {
   /*
      Strategy/infrastructure calls:

      RequestPlacePending(...)
      -> avoid duplicate planned item for same type/price
      -> AddTradeItem()
      -> item.kind         = ITEM_ORDER
      -> item.action       = ACTION_PLACE
      -> item.actionStatus = ACTION_READY
      -> if lifecycle == GRID_IDLE
            lifecycle = GRID_BUILDING

      NOTHING SENT YET.

      Scheduler:
      ProcessPendingActions()
      -> finds ACTION_READY
      -> SendTradeItemAction()
      -> builds TRADE_ACTION_PENDING
      -> OrderSendAsync()

      If local OrderSendAsync() submission succeeds:
         ACTION_READY
         -> ACTION_WAIT_RESULT
         requestId saved
         sentTimeMs saved

      Broker result later arrives through OnTradeTransaction:
         REQUEST transaction
         -> HandleRequestTransaction()

      Accepted broker retcode:
         ACTION_WAIT_RESULT
         -> ACTION_WAIT_CONFIRM

      This means ACCEPTED, NOT YET FINISHED.

      Live order confirmation:
         ORDER_ADD transaction and/or ReconcileTradeItems()
         -> orderTicket/live fields stored
         -> brokerPresent = true
         -> action         = ACTION_NONE
         -> actionStatus   = ACTION_IDLE

      NOW placement is finished.
   */
  }

//====================================================================
// 05. PENDING ORDER FILLS -> POSITION
//====================================================================
void REF_05_ORDER_FILL_TO_POSITION()
  {
   /*
      Broker produces DEAL_ADD
      -> OnTradeTransaction()
      -> transactionQueue[]
      -> HandleDealTransaction()
      -> HistoryDealSelect(dealTicket)
      -> verify magic / symbol / deal entry

      For DEAL_ENTRY_IN:
         find existing TradeItem by order ticket
         else by position ticket
         else create a new TradeItem

      Same logical item becomes a POSITION:
         kind           = ITEM_POSITION
         positionTicket = broker position ticket
         lastDealTicket = deal ticket
         side           = BUY / SELL
         openPrice      = fill price
         volume         = fill volume
         brokerPresent  = true
         action         = ACTION_NONE
         actionStatus   = ACTION_IDLE
         requestId      = 0

      If lifecycle == GRID_CLEANUP:
         action       = ACTION_CLOSE
         actionStatus = ACTION_READY

      Else:
         lifecycle = GRID_ACTIVE
         -> Strategy_OnEntryFill(...)

      In Rev 30.01 Strategy_OnEntryFill() is intentionally empty.
   */
  }

//====================================================================
// 06. DELETE PENDING ORDER
//====================================================================
void REF_06_DELETE_PENDING_ORDER()
  {
   /*
      RequestDeleteOrder(orderTicket)
      -> find TradeItem
      -> action       = ACTION_DELETE
      -> actionStatus = ACTION_READY

      Scheduler:
      ProcessPendingActions()
      -> SendTradeItemAction()
      -> TRADE_ACTION_REMOVE
      -> OrderSendAsync()
      -> ACTION_WAIT_RESULT

      Broker accepts:
      REQUEST transaction
      -> ACTION_WAIT_CONFIRM

      Actual broker order disappears:
         ORDER_DELETE transaction and/or reconciliation
         -> TradeItem removed when absence is confirmed

      Deletion is finished only when live broker state says the order is gone.
   */
  }

//====================================================================
// 07. REPLACE PENDING ORDER
//====================================================================
void REF_07_REPLACE_PENDING_ORDER()
  {
   /*
      RequestReplaceOrder(...)
      -> store replacementPrice/Lot/SL/TP
      -> replaceAfterDelete = true
      -> action       = ACTION_DELETE
      -> actionStatus = ACTION_READY

      Flow:
         DELETE OLD
         -> WAIT_RESULT
         -> WAIT_CONFIRM
         -> confirm old order gone
         -> same TradeItem prepared for ACTION_PLACE
         -> ACTION_READY
         -> scheduler sends new pending order
         -> WAIT_RESULT
         -> WAIT_CONFIRM
         -> confirm new order exists
         -> ACTION_NONE / ACTION_IDLE

      Rule:
         old order must be confirmed gone before replacement is placed.
   */
  }

//====================================================================
// 08. CLOSE POSITION
//====================================================================
void REF_08_CLOSE_POSITION()
  {
   /*
      RequestClosePosition(positionTicket)
      -> find TradeItem
      -> action       = ACTION_CLOSE
      -> actionStatus = ACTION_READY

      Scheduler:
      ProcessPendingActions()
      -> SendTradeItemAction()
      -> build opposite market DEAL for the position
      -> OrderSendAsync()
      -> ACTION_WAIT_RESULT

      Broker accepts request:
         -> ACTION_WAIT_CONFIRM

      Exit deal arrives:
         DEAL_ADD
         -> HandleDealTransaction()
         -> DEAL_ENTRY_OUT / OUT_BY / INOUT
         -> Strategy_OnExitDeal(...)

      Then:
         if position still exists
            -> partial close: refresh volume/open price/SL/TP
         else
            -> RemoveTradeItem()

      Reconciliation can also confirm position disappearance and remove item.
   */
  }

//====================================================================
// 09. MODIFY POSITION SL
//====================================================================
void REF_09_MODIFY_POSITION_SL()
  {
   /*
      RequestModifySL(positionTicket, newSL)
      -> find TradeItem
      -> requestedSL  = newSL
      -> action       = ACTION_MODIFY_SL
      -> actionStatus = ACTION_READY

      Scheduler:
      ProcessPendingActions()
      -> SendTradeItemAction()
      -> build TRADE_ACTION_SLTP
      -> OrderSendAsync()
      -> ACTION_WAIT_RESULT

      Broker REQUEST result accepted:
         ACTION_WAIT_RESULT
         -> ACTION_WAIT_CONFIRM

      IMPORTANT:
         ACTION_WAIT_CONFIRM means broker accepted the request,
         but Rev 30.01 does NOT yet consider the SL operation finished.

      ReconcileTradeItems() reads actual POSITION_SL.

      When live SL matches requestedSL within the configured tick tolerance:
         currentSL    = live SL
         action       = ACTION_NONE
         actionStatus = ACTION_IDLE

      Only here is MODIFY SL finished.

      Therefore:
         OrderSendAsync returned true != finished
         accepted retcode              != finished
         live POSITION_SL confirmed     = finished
   */
  }

//====================================================================
// 10. BROKER REJECTS ASYNC ACTION
//====================================================================
void REF_10_BROKER_REJECTS_ACTION()
  {
   /*
      Applies to:
         ACTION_PLACE
         ACTION_DELETE
         ACTION_CLOSE
         ACTION_MODIFY_SL

      Normal start:
         ACTION_READY
         -> OrderSendAsync()
         -> ACTION_WAIT_RESULT

      Broker REQUEST transaction returns a non-accepted retcode:
         -> lastRetcode stored
         -> ACTION_FAILED

      CURRENT REV 30.01 BEHAVIOR:
         ACTION_FAILED remains failed.
         There is no automatic strategy retry policy yet.
         There is no automatic cleanup policy for every failed action yet.

      That policy is intentionally left for later review.
   */
  }

//====================================================================
// 11. WAIT_RESULT TIMEOUT
//====================================================================
void REF_11_WAIT_RESULT_TIMEOUT()
  {
   /*
      ACTION_WAIT_RESULT means:
         OrderSendAsync() was submitted locally,
         but matching broker REQUEST result has not been processed yet.

      ReconcileTradeItems() checks elapsed time.

      If result wait exceeds InpAsyncResultTimeoutMs:
         actionStatus = ACTION_FAILED
         lastRetcode  = TRADE_RETCODE_TIMEOUT

      This is a bounded wait.
      Rev 30.01 does not wait forever.
   */
  }

//====================================================================
// 12. WAIT_CONFIRM TIMEOUT
//====================================================================
void REF_12_WAIT_CONFIRM_TIMEOUT()
  {
   /*
      ACTION_WAIT_CONFIRM means:
         broker accepted request,
         but required live account state is not confirmed yet.

      Examples of required live confirmation:
         PLACE     -> pending order exists
         DELETE    -> pending order absent
         CLOSE     -> position absent
         MODIFY_SL -> live POSITION_SL matches requestedSL

      If live confirmation exceeds InpAsyncLiveConfirmTimeoutMs:
         actionStatus = ACTION_FAILED
         lastRetcode  = TRADE_RETCODE_TIMEOUT

      Result timeout and live-confirm timeout are separate states/timers.
   */
  }

//====================================================================
// 13. START CLEANUP
//====================================================================
void REF_13_START_CLEANUP()
  {
   /*
      StartCleanup(state, reason)

      First guard:
         if lifecycle == GRID_CLEANUP
            return

      Meaning:
         cleanup is already running;
         do not initialize it again.

      Otherwise:
         lifecycle     = GRID_CLEANUP
         cleanupReason = reason

      For each TradeItem:

      POSITION:
         action       = ACTION_CLOSE
         actionStatus = ACTION_READY

      Existing broker ORDER:
         action       = ACTION_DELETE
         actionStatus = ACTION_READY

      Planned PLACE that has NOT been sent yet:
         remove/cancel local planned item; do not send it

      PLACE already sent and still waiting:
         cleanupAfterConfirm = true
         wait for outcome
         if order appears, schedule ACTION_DELETE

      StartCleanup() does NOT synchronously close/delete everything itself.
      It prepares actions. ProcessPendingActions() sends them asynchronously.
   */
  }

//====================================================================
// 14. COMPLETE CLEANUP -> GRID_IDLE
//====================================================================
void REF_14_COMPLETE_CLEANUP_TO_IDLE()
  {
   /*
      Cleanup progression:

      StartCleanup()
      -> TradeItems marked CLOSE / DELETE
      -> ProcessPendingActions()
      -> OrderSendAsync()
      -> broker transactions
      -> ProcessTransactionQueue()
      -> ReconcileTradeItems()
      -> confirmed-gone TradeItems removed
      -> ProcessCleanupState()
      -> CleanupFinished()

      CleanupFinished() requires ALL of these:

         1) ArraySize(state.items) == 0
         2) live EA positions == 0
         3) live EA pending orders == 0

      Only then:
         ResetGridState(state)
         -> lifecycle = GRID_IDLE
         -> items[] cleared

      ProcessCleanupState() then restores preserved identity values such as
      magic/cycle bookkeeping according to current Rev 30.01 implementation.

      HARD RULE:
         request sent      != cleanup complete
         broker accepted   != cleanup complete
         local array empty != cleanup complete by itself

         local items zero + live positions zero + live orders zero
         = cleanup complete
   */
  }

//====================================================================
// 15. SAFETY STOP
//====================================================================
void REF_15_SAFETY_STOP()
  {
   /*
      Scheduler checks:
         state.safetyStopPending == true
         and lifecycle != GRID_CLEANUP

      Then:
         StartCleanup(state, state.safetyStopReason)
         state.safetyStopPending = false

      From that point safety uses the SAME cleanup path:
         positions -> ACTION_CLOSE
         orders    -> ACTION_DELETE
         async send
         broker/live confirmation
         zero positions + zero orders + zero items
         -> GRID_IDLE

      There is no separate normal-runtime synchronous safety close path here.
   */
  }

//====================================================================
// 16. DEAL HISTORY NOT AVAILABLE
//====================================================================
void REF_16_DEAL_HISTORY_UNAVAILABLE()
  {
   /*
      HandleDealTransaction()
      -> HistoryDealSelect(dealTicket)

      If the deal is not locally available yet:
         HandleDealTransaction() returns false

      ProcessTransactionQueue():
         historyRetries++
         if historyRetries < 3
            -> requeue same TransactionItem at tail
         else
            -> state.lifecycle = GRID_FAULT
            -> state.safetyStopReason = "DEAL_HISTORY_UNAVAILABLE"

      IMPORTANT CURRENT REV 30.01 DETAIL:
         this path sets GRID_FAULT,
         but does NOT also set safetyStopPending = true.

      Therefore the current file does not automatically enter cleanup from this
      fault. This is a review item, not silently changed here.
   */
  }

//====================================================================
// 17. POSITION TRANSACTION
//====================================================================
void REF_17_POSITION_TRANSACTION()
  {
   /*
      TRADE_TRANSACTION_POSITION
      -> transactionQueue[]
      -> HandlePositionTransaction()

      Find TradeItem by positionTicket.

      If PositionSelectByTicket(positionTicket) succeeds:
         kind          = ITEM_POSITION
         side          = live POSITION_TYPE
         openPrice     = live POSITION_PRICE_OPEN
         volume        = live POSITION_VOLUME
         currentSL     = live POSITION_SL
         currentTP     = live POSITION_TP
         brokerPresent = true

      If position cannot be selected:
         brokerPresent = false

      This transaction does not directly run general strategy logic.
   */
  }

//====================================================================
// 18. RECONCILIATION OF TRADE ITEMS
//====================================================================
void REF_18_RECONCILE_TRADE_ITEMS()
  {
   /*
      ReconcileTradeItems(state)
      treats live terminal/broker state as final confirmation.

      Stable ITEM_ORDER:
         refresh actual broker order data

      Stable ITEM_POSITION:
         refresh actual broker position data

      Waiting async actions:
         PLACE     -> confirm order exists
         DELETE    -> confirm order absent
         CLOSE     -> confirm position absent
         MODIFY_SL -> confirm live SL equals requested SL

      Confirmed successful action:
         ACTION_NONE / ACTION_IDLE
         or remove TradeItem if broker object is gone.

      Timeout:
         ACTION_FAILED

      Reconciliation is therefore the bridge between
      "broker accepted the request" and "the requested live state exists".
   */
  }

//====================================================================
// 19. GRID LIFECYCLE
//====================================================================
void REF_19_GRID_LIFECYCLE()
  {
   /*
      Main lifecycle:

         GRID_IDLE
            no active cycle / no EA-owned trade object

            | RequestPlacePending()
            v

         GRID_BUILDING
            initial grid requests are being sent/confirmed

            | initial placement actions settle and order(s) exist
            v

         GRID_READY
            pending grid exists, no strategy position filled yet

            | DEAL_ENTRY_IN
            v

         GRID_ACTIVE
            at least one strategy position has filled

            | StartCleanup()
            v

         GRID_CLEANUP
            positions closing + orders deleting asynchronously

            | state.items[] == 0
            | live positions == 0
            | live orders == 0
            v

         GRID_IDLE

      Fault path:
         -> GRID_FAULT

      GRID_FAULT means unresolved infrastructure fault.
      Current Rev 30.01 has no complete automatic recovery policy for all faults.
   */
  }

//====================================================================
// 20. ACTION STATUS
//====================================================================
void REF_20_ACTION_STATUS()
  {
   /*
      ACTION_IDLE
         Nothing is currently requested for this TradeItem.

      ACTION_READY
         An action has been requested by strategy/cleanup,
         but has NOT yet been sent to broker.

      ACTION_WAIT_RESULT
         OrderSendAsync() was called successfully.
         Waiting for matching broker REQUEST result.

      ACTION_WAIT_CONFIRM
         Broker accepted request.
         Waiting for required live terminal state.

      ACTION_FAILED
         Local send failure, broker rejection, or timeout.

      Normal successful sequence:

         ACTION_IDLE
         -> ACTION_READY
         -> ACTION_WAIT_RESULT
         -> ACTION_WAIT_CONFIRM
         -> ACTION_IDLE
   */
  }

//====================================================================
// 21. ACTION TYPE
//====================================================================
void REF_21_ACTION_TYPE()
  {
   /*
      ACTION_NONE
         no broker operation requested

      ACTION_PLACE
         create pending order

      ACTION_DELETE
         delete pending order

      ACTION_CLOSE
         close position

      ACTION_MODIFY_SL
         modify position stop loss

      Remember:

         item.action
            = WHAT we want broker to do

         item.actionStatus
            = WHERE we are in executing/confirming that action

      Example:

         action       = ACTION_DELETE
         actionStatus = ACTION_READY

      means:
         "Delete this order, but it has not been sent yet."

      While:

         action       = ACTION_DELETE
         actionStatus = ACTION_WAIT_CONFIRM

      means:
         "Broker accepted deletion; now confirm the order is actually gone."
   */
  }

//====================================================================
// 22. KNOWN REV 30.01 REVIEW ITEM: DEAD LOCAL ITEM DURING CLEANUP
//====================================================================
void REF_22_KNOWN_REVIEW_ITEM_DEAD_LOCAL_ITEM()
  {
   /*
      Current edge case to review before strategy migration:

      If SendTradeItemAction() is asked to DELETE/CLOSE an object that is
      already absent before the request is sent, current code can change it to:

         action         = ACTION_NONE
         actionStatus   = ACTION_IDLE
         brokerPresent  = false

      without necessarily removing that TradeItem immediately.

      During GRID_CLEANUP this may leave a dead local item in state.items[].
      CleanupFinished() requires ArraySize(state.items) == 0, so such an item
      could prevent cleanup completion.

      THIS FILE DOCUMENTS THE ISSUE ONLY.
      No behavior is changed by this reference file.
   */
  }

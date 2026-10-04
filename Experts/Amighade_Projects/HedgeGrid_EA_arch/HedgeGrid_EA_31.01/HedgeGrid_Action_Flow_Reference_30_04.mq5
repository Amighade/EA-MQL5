/*
   REV30.04 — READING COMPANION ONLY. Not included by HedgeGrid.mq5.
   This is an explanation of the active functions, not a second implementation.

   DATA
     TransactionItem = one incoming broker fact.
     TradeItem       = one planned/live broker object and its outgoing command.
     GridState       = one cycle and one items[] array.

   STARTUP
     OnInit()
       validate hedging account + scheduler inputs
       ResetGridState(), establish magic, initialize timer/profiler
       ReconcileTradeItems() discovers existing broker objects

   BROKER CALLBACK
     OnTradeTransaction()
       copy fields valid for this transaction type
       QueueTransaction()
       return

   TIMER FRAME
     RunScheduler30()
       ProcessTransactionQueue()
         HandleTransaction() dispatches one fact
           REQUEST  -> correlate request_id; retain result; wait for live proof
           ORDER    -> request broker synchronization
           POSITION -> request broker synchronization
           DEAL     -> read actual deal, synchronize, invoke the appropriate hook
         false means required data unavailable: retry on a later frame
         exhausted retries request reconciliation, never whole-cycle cleanup

       explicit safetyStopPending -> StartCleanup()
       ReconcileTradeItems()
         RebuildTradeBookFromTerminal() merges broker data without clearing intent
         each item resolves its own existing command
         stale absent objects are removed
         no arbitrary trading command is created

       if GRID_CLEANUP
         StartCleanup() routes live POSITION -> CLOSE; live ORDER -> DELETE
         ProcessPendingActions() obeys the in-flight batch limit
         ProcessCleanupState() resets only after book empty + broker zero/zero
         finish frame

       ProcessPendingActions()
       due Strategy_Fast(), Strategy_Medium(), Strategy_Background()
       finish frame

   REQUEST SETTERS
     RequestPlacePending()  -> new local PLACE, or existing same-type/price item
     RequestDeleteOrder()   -> DELETE; clear any unsent replacement flag
     RequestClosePosition() -> CLOSE
     RequestModifySL()      -> MODIFY_SL with the exact requested SL
     RequestReplaceOrder()  -> guarded DELETE plus requested replacement values

     A waiting item rejects a new request before any command field is changed.
     Placement, replacement and SL modification are rejected during cleanup.

   SUBMISSION
     ProcessPendingActions() -> SendTradeItemAction() -> OrderSendAsync()
     Only READY may send. Reverse iteration tolerates removal of absent targets.
     Each send clears prior result evidence and records its own request_id and timestamp.
     No synchronous OrderSend() exists in active source.

   CONFIRMATION
     PLACE     -> exact result-ticket identity + confirmed pending order/resulting position
     DELETE    -> old order absent + final history; any filled exposure must be accounted for
     CLOSE     -> position absent; otherwise final execution order + deals + live volume confirm continuation
     MODIFY_SL -> successful result + matching live SL (or remove an absent position)

     Request acceptance alone is never completion.
     Time alone is never evidence of failure and never unlocks a submitted command.
     An unresolved request stays visible and locked until broker evidence resolves it.

   ORDERING AND PARTIAL FILLS
     Full fill: reuse source order item for the position where possible.
     Partial fill: pending remainder and position are two live objects, two items.
     Broker position ticket changes retain identity through the opening-order ID.
     Late exact result tickets merge recovered broker objects with their source plans.
     Equal prices never prove that a broker object belongs to an outstanding PLACE.
     REQUEST result does not write lastDealTicket; only consumed DEAL events do.

   NORMAL DISAPPEARANCE
     No live position -> reconciliation removes the stale item.
     No live order -> final history first rules out an unobserved filled position.
     It does not request cleanup of the other objects.

   WHOLE-CYCLE CLEANUP
     Keep discovering and routing live broker objects.
     Do not replace an item already waiting for a submitted action.
     Retry definitive failures after delay; never retry an unknown result.
     Finish only with no tracked object/request and broker positions=0, orders=0.
     Do not finish disconnected or in the gap between filled order and visible position.

   STRATEGY
     All five StrategyBridge hooks are empty.
     Prices, lots, grid geometry, widening, shifting and recentering are not implemented
     or modified by this infrastructure review.

   VALIDATION
     See README_REV30_04.md, AUDIT_REV30_04.md and SIMULATION_REV30_04.md.
     Simulated lifecycle tests passed; native MQL5 compilation and MT5 runs are pending.
*/

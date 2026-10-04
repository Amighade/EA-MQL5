# HedgeGrid Rev30.04 — reviewed source baseline

This replaces the first issued Rev30.04. It keeps the revision number, removes repeated broker synchronization, and corrects lifecycle defects found during the second review. Strategy hooks remain empty. Read the active source in the order below; `Reference_Rev22_2/` and `Validation/` are not included by the EA.

## Reading order

| Order | File | What to understand |
|---|---|---|
| 1 | `Models/GridState.mqh` | One cycle, one item array, one command per item. Strategy fields below the infrastructure fields are dormant. |
| 2 | `Models/TransactionItem.mqh` | Incoming facts only. No strategy commands. |
| 3 | `HedgeGrid.mq5` | Initialization, tiny event recorder, timer entry point. |
| 4 | `Engines/Scheduler.mqh` | The entire frame in one function, with one exit and one shared budget. |
| 5 | `Utils/TradeBook.mqh` | Identity lookup and the single broker-to-book synchronization path. |
| 6 | `Engines/TransactionHandler.mqh` | Consume request/order/position notifications; process actual deal facts. |
| 7 | `Engines/ReconcileEngine.mqh` | Refresh facts, resolve existing commands, remove stale items, check lifecycle. |
| 8 | `Engines/CleanupEngine.mqh` | Assign CLOSE/DELETE to live objects; finish only at confirmed zero/zero. |
| 9 | `Utils/AsyncTrade.mqh` | Strategy request setters, one asynchronous sender, pending-action loop. |
| 10 | `Engines/StrategyBridge.mqh` | The five empty places where future strategy code belongs. |
| 11 | `Inputs.mqh`, `Utils/Identity.mqh`, `Utils/ProfilerUtils.mqh` | Settings, ownership and optional diagnostics. |

## The frame

1. Consume a bounded number of queued broker facts.
2. Apply an explicit whole-cycle cleanup request, if one exists.
3. Refresh broker facts and reconcile outstanding commands when required, and at least on the medium tier.
4. During cleanup, route every live position to CLOSE and every live pending order to DELETE. Send within the batch limit and check completion. End that frame.
5. Otherwise, send READY commands and call the due strategy hooks.

Timing defaults remain 15 ms heartbeat, 50 ms fast, 250 ms medium and 60 s background. All work shares one cooperative frame budget. A broker scan or individual API call is a stage that cannot be preempted; the budget is not a hard real-time guarantee for arbitrarily large accounts. No new-bar, shifting or recentering gate is active.

## Facts and commands

`RebuildTradeBookFromTerminal()` now merges the live broker view into the existing book. It does **not** clear the array or erase commands. It is reused by startup, deal handling and reconciliation; cleanup has no separate adoption mechanism.

- A newly discovered broker object starts at `ACTION_NONE / ACTION_IDLE`.
- A position uses `positionTicket` for current broker requests and `orderTicket` for its stable opening-order identity.
- A full fill reuses the source item where possible. A partial fill can have two simultaneous objects, so the remaining order and the position have separate items.
- Later history can merge an unresolved source plan with a position recovered earlier.
- `lastDealTicket` means a consumed DEAL event. A request-result acknowledgement never writes it.
- `reconcilePending` requests another check. It is not a second action state and never bypasses completion checks.

## Command contract

| State | Meaning | What may happen next |
|---|---|---|
| `ACTION_IDLE` | No command outstanding | A strategy request may set one. |
| `ACTION_READY` | Local command, not currently submitted | The sender may submit it once. A strategy may revise unsent intent. Cleanup may supersede it. |
| `ACTION_WAIT_RESULT` | Submitted, no usable result yet | Setters reject changes. Broker proof can resolve it. |
| `ACTION_WAIT_CONFIRM` | Result received; live outcome still needed | Setters reject changes. Reconciliation checks the actual target. |
| `ACTION_FAILED` | Local submission failed or a definitive rejection arrived | The live object is still counted. Cleanup retries after the configured delay; ordinary strategy decides whether to retry. |

Live proof can arrive before a REQUEST callback. A confirmed pending order/position proves PLACE, and absence resolves CLOSE/DELETE. For a submitted SL modification, both a successful result and the requested live SL are required. A request acknowledgement by itself never means completion.

An uncertain or missing result is **not** converted into failure just because a timer expired. It stays locked, is checked again, and prevents false cleanup completion. If the terminal never supplies enough evidence, this requires investigation of the broker/terminal; automatically unlocking it would permit duplicate trading. `reconcilePending` does not prevent recovery when evidence arrives.

A partial CLOSE is continued only after a `DONE_PARTIAL` result and a smaller live position volume. Its remainder uses the same CLOSE command and respects the grace interval.

## DELETE and replacement

A plain DELETE/CLOSE whose target is already absent resolves without another trade request. An absent SL target is removed as stale.

Replacement is stricter: a confirmed canceled, expired or rejected order may become the already-requested replacement PLACE on the same item. A fully filled order cancels the obsolete replacement. Canceling a partially filled pending remainder still honors the requested replacement; its existing position stays separate. Missing cancellation history waits for evidence. Plain `RequestDeleteOrder()` cancels any unsent replacement flag.

## Cleanup and cycle completion

Cleanup is an explicit cycle-level decision. Retry exhaustion or one stale item disappearing does not initiate it.

- Reconciliation discovers missed broker objects even outside cleanup.
- Cleanup repeatedly routes all live objects and discards unsent PLACE plans.
- It never overwrites a submitted command.
- Definitively rejected CLOSE/DELETE commands may be retried after a delay; unknown outcomes remain locked.
- The local book must contain no live objects or unresolved requests, and terminal queries must show zero EA-owned positions and zero pending orders.
- Cleanup cannot finish while disconnected. A filled order awaiting position visibility is not treated as flat; a rapid open-and-close can instead be confirmed from its position history.

## Before adding strategy

The runtime supports a retail hedging account without FIFO close restrictions. Startup rejects incompatible accounts and invalid scheduler settings. Run one owner for each symbol/magic pair. Pending placement currently accepts BUY/SELL LIMIT and BUY/SELL STOP; stop-limit placement needs its extra price and is rejected rather than sent incorrectly. Existing stop-limit pending orders can still be discovered and cleaned up.

Use the request setters from `StrategyBridge.mqh` hooks and handle their return values. Do not modify request IDs, waiting states or broker identity directly. Entry hooks receive a current live position; snapshots do not synthesize missed strategy events. There is no general historical strategy-event replay after a terminal restart or exhausted history retries.

No prices, grid geometry, lot progression or widening calculations were changed. The original strategy tree is preserved byte-for-byte and is not active. Deinitialization stops the timer and does not liquidate positions; runtime request tracking is not persisted across terminal restarts.

## Verification status

The included C++ simulated-terminal harness executes the current EA function bodies after adapting MQL include/input/array syntax. All 27 scenario groups pass, including six event-order permutations. It is stronger than text checks but is **not** a native MQL5 compiler or a real broker.

See `AUDIT_REV30_04.md` for the requirement matrix and remaining validation. Native MetaEditor compilation and an MT5 demo/tester lifecycle run have not been performed here. No active Rev30.04 EX5 is included.

**NOT READY — native MetaEditor compilation and MT5 lifecycle verification remain outstanding.**

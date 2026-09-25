# HedgeGrid Rev 21 — Scheduler / Event Architecture

## Purpose
This revision is the first implementation of the scheduler architecture discussed before coding. It is deliberately a comprehension/architecture revision: strategy rules and brick behavior are kept as they were, while event execution is moved behind a bounded scheduler.

## Changes

### 1. One native heartbeat
- Replaced the prototype fixed task checks with one native MQL5 millisecond timer.
- Starting heartbeat value: `15 ms` (configurable via `InpSchedulerHeartbeatMs`).
- Software tiers run from that single heartbeat rather than creating multiple native timers.

### 2. Global frame budget
- Starting scheduler frame budget: `15 ms` (configurable via `InpSchedulerFrameBudgetMs`).
- The budget is global to one scheduler frame, not a separate budget per tier.
- Tasks that are not completed remain pending through their state/queue instead of blocking the frame.

### 3. OnTick becomes a latest-state bridge
- `OnTick()` no longer runs the strategy pipeline.
- It only overwrites the latest bid/ask/time snapshot and increments a tick sequence.
- Price events are intentionally lossy: intermediate ticks do not accumulate in a queue.

### 4. OnTradeTransaction becomes a lossless event bridge
- `OnTradeTransaction()` now copies compact transaction facts to a queue and returns.
- Strategy processing of fills/closes is performed by the scheduler.
- Transaction order is preserved in the queue.
- The queue retains request identifiers and result retcodes needed for async cleanup bookkeeping.

### 5. Task tiers
Starting release intervals are configurable and intentionally provisional:
- Fast market tier: `30 ms`
- Medium reconciliation/session tier: `250 ms`
- Slow dashboard tier: `2000 ms`
- Background tier: `60000 ms`

These are scheduler settings only; they do not change grid/SL/cleanup strategy rules.

### 6. Bounded transaction processing
- At most `InpSchedulerMaxTransactionsPerFrame` queued transactions are processed per scheduler frame (starting value: 3), in addition to the global time budget.
- This prevents a burst of queued trade events from monopolizing the entire scheduler frame.

### 7. Non-blocking cleanup
- Normal cleanup no longer depends on the legacy blocking `ClosePosition()` loop.
- New asynchronous helpers use `OrderSendAsync()` for position closes and pending-order deletion.
- A small configurable batch of requests may remain outstanding while other scheduler work continues.
- Starting batch size: `3`.
- The scheduler never sends a duplicate request for the same ticket while that ticket is marked waiting.

### 8. Cleanup completion is state-confirmed
- Sending a close/delete request is never treated as completion.
- A waiting request remains pending until the actual position/order disappears, or a request transaction reports a failed submission.
- For `CLEANUP_CLOSE_ALL`, cleanup is only completed when both EA positions and EA pending orders are actually zero.
- The previous immediate `cleanupInProgress = false` behavior after a send attempt is therefore not used by the active Rev 21 scheduler path.

### 9. Scheduler does not block while waiting for broker confirmation
- Outstanding cleanup requests are allowed to wait for broker processing while the scheduler services other eligible work.
- A trade transaction releases/invalidates the relevant waiting slot, but the scheduler still uses live account state as the final authority.

### 10. Cycle reset isolation
- `ResetGridState()` no longer clears the scheduler transaction queue/timing state during a trading-cycle reset.
- This prevents a cycle reset from discarding transaction events that are queued for later processing.
- Scheduler initialization/queue clearing is explicit in `OnInit()` / `OnDeinit()`.

### 11. Continuation instead of array-index cleanup state
- The first scheduler revision does not use the old `g_nextCleanupIndex` scheduler field.
- Cleanup continuation is based on ticket sequences plus explicit pending-request records.
- Live sequence rebuilding occurs when the current sequence is exhausted and no corresponding request is still outstanding.

## Deliberately NOT changed
- Grid construction rules
- Lot sizing rules
- Grid update/shifting logic
- SL strategy rules
- Cleanup mode semantics (`CLEANUP_CLOSE_ALL` vs `CLEANUP_CLOSE_POSITIONS`)
- Existing deviation values
- Existing synchronous emergency SafetyNet path
- Existing strategy functions themselves; their normal-fill call order is preserved when the queued event is processed

## Important test note
This environment does not contain MetaEditor/MQL5 compiler tooling, so the `.ex5` included in the source package is not rebuilt from Rev 21. The `.mq5/.mqh` source is the Rev 21 implementation and must be compiled in MetaEditor before live/tester execution.

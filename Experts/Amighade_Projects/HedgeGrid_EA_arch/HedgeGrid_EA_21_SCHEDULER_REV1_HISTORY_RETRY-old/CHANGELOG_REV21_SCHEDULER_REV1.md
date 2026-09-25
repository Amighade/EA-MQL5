# HedgeGrid EA — Rev 21 Scheduler / Execution Architecture — Changelog

## Purpose

This revision is the first complete implementation of the timer/scheduler architecture discussed after Rev 20. It is intended as a valid working base for further tuning and review, not as the final performance-optimized release.

## Core scheduler rules implemented

- One native MQL5 millisecond timer is used as the heartbeat.
- Default heartbeat: **15 ms**.
- Default global scheduler work budget: **15 ms** for the complete heartbeat.
- All software tiers share the same global budget; there is no independent CPU budget per tier.
- Tier intervals are configurable starting points and can be adjusted later without redesigning the scheduler.
- The scheduler never performs timer catch-up bursts after a delayed frame; each tier is released again from current time.
- Work is ordered by priority: transaction classification → cleanup → fast strategy work → medium structural work → slow/background work.

## Event handling

### OnTick

- `OnTick()` now performs only a lightweight `SymbolInfoTick()` snapshot.
- Latest price/tick data is overwritten rather than queued.
- No strategy calculation is performed directly from `OnTick()`.

### OnTradeTransaction

- The callback is now an event recorder only.
- No `HistoryDealSelect()`, position/order scans, SL calculations, cleanup execution, or grid mutation occur inside the callback.
- Compact transaction facts are appended to a lossless scheduler queue.
- Cleanup request/result transactions are retained while cleanup is active so `request_id` can correlate asynchronous requests.

## Transaction queue

- Transaction events are processed in scheduler context.
- `DEAL_ENTRY_IN` creates a separate fill-work item rather than executing the full fill strategy inside the transaction queue.
- `DEAL_ENTRY_OUT`, `INOUT`, and `OUT_BY` create a cleanup trigger when appropriate.
- Transaction queue entries are not discarded because the scheduler budget expired.
- Queue compaction is delayed rather than shifting the entire array for every event.
- Queue growth uses reserved capacity to reduce repeated memory reallocations during burst activity.

## Fill processing

The original post-fill strategy sequence is retained in order but made resumable between scheduler stages:

1. `ProcessOrderFill()`
2. `ReSnapshotIfArmed()`
3. `UpdateOppositeGrid()`
4. `ShiftGrid()`
5. `ProcessInsideStrategy()`
6. Set `outsideRefillPending`
7. `CalculateBasketProfits()` + `ProcessSLManager()`
8. `LogHistory()`

If cleanup takes ownership of the cycle before queued fill work is consumed, pending fill reactions are invalidated so they cannot revive the cycle after cleanup.

## Cleanup execution

### Main change

Normal cleanup now uses `OrderSendAsync()` for:

- position closes (`TRADE_ACTION_DEAL` with `position` ticket)
- pending-order deletion (`TRADE_ACTION_REMOVE`)

A small configurable batch can be in flight at the same time.

Default:

- `InpCleanupAsyncBatch = 3`

### Confirmation model

Submitting a request is **not** treated as completion.

Cleanup tracks:

- target ticket
- request ID
- action type
- attempt count
- request state
- retry timing
- last request-level retcode

`OnTradeTransaction()` records request/result events, but actual completion is verified from current live terminal state.

### Cycle completion barrier

For `CLEANUP_CLOSE_ALL` the cycle can finish only when:

- EA-owned positions = 0
- EA-owned pending orders = 0
- no cleanup request remains unresolved

The state is reset only after that condition is true.

`CLEANUP_CLOSE_POSITIONS` keeps its original semantics: positions are closed while pending orders remain intentionally.

### Retry protection

- No `Sleep()` occurs in the scheduler cleanup path.
- Failed or partial requests become retryable after a delay.
- Retryable requests are checked before new cleanup targets so an early failed ticket cannot become permanently stranded behind the sequence cursor.
- A target is never submitted again while an active request for the same ticket/action is still outstanding.

### Late-event protection

Cleanup remembers position tickets it intentionally handled. This prevents a late cleanup-generated `DEAL_ENTRY_OUT` event from being interpreted as a fresh external cleanup trigger after the current cycle has already been reset.

## State separation

Scheduler queues were moved out of `GridState` where appropriate so a normal strategy-cycle reset cannot erase newly arriving transaction events.

Cleanup-specific execution state remains in `GridState` because it is part of the cycle lifecycle.

## Configurable scheduler starting points

| Parameter | Default |
|---|---:|
| `InpSchedulerHeartbeatMs` | 15 ms |
| `InpSchedulerBudgetMs` | 15 ms |
| `InpFastTierIntervalMs` | 50 ms |
| `InpMediumTierIntervalMs` | 250 ms |
| `InpTimerIntervalSec` (dashboard/slow tier) | 2 sec |
| `InpBackgroundTierIntervalMs` | 60 sec |
| `InpSchedulerMaxTransactionsPerFrame` | 32 |
| `InpCleanupAsyncBatch` | 3 |
| `InpAsyncConfirmGraceMs` | 500 ms |
| `InpSessionCheckIntervalMs` | 1000 ms |

These values are intentionally starting values for measurement/tuning.

## Important boundary of Rev 21

The scheduler can stop **between functions/stages**, but a legacy function that performs a large synchronous loop remains non-preemptible until that function returns. In particular, some existing grid placement/refill/SL-modification functions still execute synchronously once selected by the scheduler.

Those functions are deliberately not rewritten in this revision so the first scheduler revision remains easy to audit against Rev 20 behavior.

## Trade execution abstraction

`CTrade` was not introduced. Existing explicit `MqlTradeRequest` handling remains in place, with asynchronous helper functions added only where required by scheduler cleanup.

Existing deviation settings were not changed.

## Files materially changed

- `HedgeGrid.mq5`
- `Inputs.mqh`
- `Models/GridState.mqh`
- `Engines/CleanupReset.mqh`
- `Engines/TimerEngine.mqh`
- `Utils/TradeUtils.mqh`

## Follow-up correction: non-blocking transaction-history retry

- A `DEAL_ADD` whose `HistoryDealSelect()` is temporarily unavailable no longer blocks the transaction queue head.
- The immutable transaction is re-appended to the queue tail and the current frame continues processing unrelated queued events.
- The re-appended item is outside the frame-start queue-size snapshot, so it cannot be retried repeatedly in the same heartbeat.
- Queue compaction retains the deferred transaction for a later heartbeat, preserving the event instead of dropping it.
- No other scheduler priority, trading rule, cleanup rule, or strategy behavior was changed in this correction.

## Validation performed

- Source ZIP structure verified.
- Brace balance checked across all `.mq5` / `.mqh` source files.
- Duplicate event-handler checks performed.
- Legacy scheduler fields/functions removed from the active Rev 21 path.
- Stale Rev 20 `.ex5` binary removed from the deliverable so it cannot be mistaken for a compiled Rev 21 executable.
- MetaEditor/MQL5 compiler was not available in this environment; compilation must therefore be performed in MetaEditor before live/VPS deployment.

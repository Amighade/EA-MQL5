# HedgeGrid Rev 22.06 — corrected overwrite

This file describes only the changes made in the corrected Rev 22.06 overwrite.
No grid, sizing, refill, cleanup, session, scheduler-cadence, widening, or other strategy rule was changed.
The input defaults previously requested for Rev 22.06 remain unchanged in `Inputs.mqh`.

## 1. Async SL retry/confirmation fixed

### `Utils/TradeUtils.mqh` — lines 723–1059
- Replaced the one-shot async SL tracker with an explicit per-ticket state machine:
  `WAIT_RETRY -> WAIT_RESULT -> WAIT_LIVE`.
- `InpSafetyRetryAttempts` and `InpSafetyRetryDelayMs` now apply to SL modification failures without `Sleep()`.
- Broker rejection below the retry limit schedules another attempt instead of immediately starting cleanup.
- Missing request/live confirmation is released for retry after `InpAsyncConfirmGraceMs` so an SL request cannot paralyze the wall indefinitely.
- Live `POSITION_SL` remains the authority for completion.
- The exact strategy SL target is retained across retries; a temporary broker-distance validation failure is retried rather than silently replacing the target.

### `Engines/SLManager.mqh` — lines 99–210, 238–272, 391–400
- A logical wall update now keeps retrying unresolved winner tickets until all live winners confirm the target SL or the configured retry limit is exhausted.
- `slWallArmed/slApplied/slLevel` advance only after all live winner positions confirm protection.
- A new winner-side fill while a wall is already armed is explicitly brought under the existing wall and shares the same async confirmation/retry lifecycle.
- Safety cleanup starts only after retry exhaustion, not after the first broker rejection.

## 2. OnTradeTransaction data flow made explicit/readable

### `HedgeGrid.mq5` — lines 142–163
- `OnTradeTransaction()` is now visibly capture-only:
  `CaptureTradeTransaction(...) -> QueueTransaction(...) -> return`.
- No strategy, history lookup, SL work, cleanup action, or account scan runs in the terminal callback.

### `Engines/TimerEngine.mqh` — lines 167–204, 291–457
- Added `CaptureTradeTransaction()` as the single field-picking/filtering point.
- Split transaction distribution into three readable owners:
  - `DispatchRequestTransaction()` — async request/result routing.
  - `DispatchDealTransaction()` — deal ownership, aggregate bookkeeping, fill/cleanup flags.
  - `DispatchAccountStateTransaction()` — order/position reconciliation only.
- `ProcessTransactionQueue()` now only selects the appropriate distributor.

### `Engines/TimerEngine.mqh` — lines 473–485
- Added an in-code strategy map showing that strategy reactions begin in `ProcessFillWork()` and the exact stage order used after an entry fill.

## 3. Async cleanup-delete request ownership made explicit

### `Utils/TradeUtils.mqh` — lines 536–556
- `SendDeleteOrderAsync()` now includes the order symbol and magic in the request so REQUEST events pass the same ownership filter and can be routed back to cleanup correctly.
- No cleanup strategy/order was changed.

## Profiling
- Existing Rev 22.4/22.5 function and frame profiling remains enabled and unchanged for comparison testing.

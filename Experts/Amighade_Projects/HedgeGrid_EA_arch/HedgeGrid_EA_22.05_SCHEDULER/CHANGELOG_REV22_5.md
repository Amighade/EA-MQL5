# Rev 22.5 Changelog

This revision changes only the four approved broker-blocking/widening issues while keeping the Rev 22.4 function profiler active. Strategy inputs and strategy rules are otherwise unchanged.

## 1. Pending-order placement is asynchronous; widening removed
- `Utils/TradeUtils.mqh:121-289` — added in-flight pending-placement tracking and per-cycle rejected-level tracking so async submissions are not duplicated and a broker-rejected level is dropped for that cycle.
- `Utils/TradeUtils.mqh:295-337` — `PlacePendingOrder()` now uses `OrderSendAsync()` instead of synchronous `OrderSend()`.
- `Utils/TradeUtils.mqh:341-392` — removed the widening/retry loop and replaced it with `PlacePendingSingleAttempt()`. The exact rejected level is skipped; later ladder levels keep their existing price/lot progression.
- `HedgeGrid.mq5:153-180` — normal async REQUEST results are now queued for scheduler-side correlation; `result.order` is retained for async pending-order correlation.
- `Engines/TimerEngine.mqh:271-296, 372-390` — correlates async placement request/order events without running strategy logic inside `OnTradeTransaction()`.
- `Engines/GridBuilder.mqh:300-304, 793-840` — resets rejected-level state at a new grid cycle and allows only explicitly rejected/dropped levels to remain absent during fresh-grid verification.
- `Engines/TimerEngine.mqh:679-696` — fresh-grid verification waits until all async initial placement requests have resolved.
- `Engines/CleanupReset.mqh:516-532` — cleanup cannot finish while a normal async placement request can still create a late pending order.

## 2. Normal pending-order deletion is asynchronous
- `Utils/TradeUtils.mqh:395-463` — normal runtime `DeleteOrder()` now uses `OrderSendAsync()`; `DeleteOrderSync()` is retained only for EA deinitialization where no future scheduler heartbeat exists.
- `Utils/SafetyNet.mqh:50-58` — deinitialization safety-close uses `DeleteOrderSync()`.
- `Engines/GridUpdater.mqh:25-119, 180-227` — opposite-grid lot replacement now keeps the original delete-before-place strategy order by queueing the replacement and submitting it only after the old pending ticket is confirmed absent.
- `Engines/TimerEngine.mqh:586-601` — processes deferred delete→replace work in the fast tier.
- `Engines/TimerEngine.mqh:947-965` — clears deferred replacement work whenever cleanup takes ownership of the cycle, preventing late replacement orders.

## 3. SL modification is asynchronous
- `Utils/TradeUtils.mqh:719-816` — added request-id tracking/reconciliation for async SL modifications and prevents duplicate SL submissions while one request for the same ticket is still outstanding.
- `Utils/TradeUtils.mqh:819-876` — `ModifyPositionSL()` now submits one `OrderSendAsync()` request instead of synchronous retry calls.
- `Engines/TimerEngine.mqh:278-290, 377-380` — broker-side SL rejection still routes to the existing safety-stop path; successful requests are reconciled against live position state.
- `Engines/SLManager.mqh:41-44` — source comment updated to the Rev 22.5 async SL failure path.
- `InpSafetyRetryAttempts` no longer drives repeated SL-modification submissions; it remains unchanged for the synchronous close path where it was already used.

## 4. Profiling retained and renamed for the new paths
- `Utils/ProfilerUtils.mqh:21-51, 93-131` — retained function timing and renamed the affected entries to `OrderSendAsync.Pending`, `OrderSendAsync.Delete`, `OrderSendAsync.ModifySL`, and `PlacePendingSingleAttempt`; added `ProcessPendingGridReplacements` timing.
- `HedgeGrid.mq5:19` — version set to `22.50`.

No changes were made to the intentional commented new-bar gate, grid-level settings, session logic, lot algorithms, refill selection, cleanup strategy, or other trading settings outside these four approved issues.

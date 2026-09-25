# HedgeGrid EA — Rev 22.3 Changelog

This changelog contains only changes made in Rev 22.3.

- Initialized `MqlTradeTransactionShort.historyRetries` to `0` when each transaction is queued.
- Fixed scheduler CPU profiling so the profiling period starts once at scheduler initialization instead of restarting every frame.
- Moved the CPU profile report out of the 60-second background tier; `[CPU PROFILE]` now reports every 10 seconds from frame accounting.
- Cleanup reconciliation is no longer released on every 15 ms heartbeat; it uses the existing fast-tier interval (50 ms default).
- Reduced cleanup account scanning to one position/order snapshot per cleanup release instead of repeated full-account scans inside the same frame.
- Removed the unused `OnTick()` latest-tick snapshot and its unused scheduler globals.
- Medium-tier position/order reconciliation now runs only when `g_reconcilePending` is set by account/trade activity, instead of scanning continuously every 250 ms while a grid/cycle exists.
- Restored SL trailing to a one-grid-step arithmetic trail using the existing armed winner snapshot; it no longer recalculates the full SL candidate or re-scans all positions every fast-tier pass.
- Removed `Sleep()` delays from `ModifyPositionSL()` retries while preserving the existing bounded retry count.
- Updated EA metadata version to `22.30`.

## Rev 22.3 diagnostic profiling addition

No strategy rule, setting, scheduler interval, cleanup rule, widening rule, or trade-request behavior was changed. This addition only measures elapsed wall-clock time.

- Added `Utils/ProfilerUtils.mqh` with 10-second interval statistics: `Last`, `Max10s`, `MaxAll`, `Avg10s`, and `Calls`.
- `Engines/TimerEngine.mqh`: profiles transaction processing, history selection, aggregate updates, fill-work stages, fast/medium scheduler work, grid build/verification/refill/maintenance, dashboard/background work, and cleanup work; prints `[FUNCTION PROFILE]` beside the existing 10-second CPU report.
- `Engines/GridBuilder.mqh`: profiles the actual `BuildGrid()` execution separately from the surrounding build-condition check.
- `Engines/OrderMonitor.mqh`: profiles `RebuildSideVolumeAggregate()` separately from the surrounding aggregate update.
- `Engines/CleanupReset.mqh`: profiles cleanup reconciliation and close/delete submission slices.
- `Engines/SLManager.mqh`: profiles SL candidate calculation, winner snapshot/application, basket aggregate calculation, arm, and trail work.
- `Utils/TradeUtils.mqh`: profiles pending-order placement/widening, synchronous and asynchronous trade requests, SL modification, safety-close sleeps, and position/order scans. `OrderSend*()` calls are timed separately from their parent functions so broker wait can be identified.
- `Utils/TelegramUtils.mqh`: profiles `SendTelegramMessage()` and the `WebRequest()` call separately.

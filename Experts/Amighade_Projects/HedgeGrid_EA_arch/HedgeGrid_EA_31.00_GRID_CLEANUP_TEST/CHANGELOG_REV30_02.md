# Changelog — Rev 30.02

Base: Rev 30.01 Simple Async.

Only the lifecycle fault-handling change approved for this revision was applied.

## Changes

- Removed `GRID_FAULT` from `ENUM_GRID_LIFECYCLE`.
- Repeated `HistoryDealSelect()` failure after the existing three attempts now sets:
  - `state.safetyStopPending = true`
  - `state.safetyStopReason = "DEAL_HISTORY_UNAVAILABLE"`
- Scheduler consumes `safetyStopPending` and routes it through the existing full cleanup lifecycle:
  - `StartCleanup()`
  - `GRID_CLEANUP`
  - async CLOSE/DELETE actions
  - broker/live-state reconciliation
  - zero EA positions + zero EA pending orders
  - `GRID_IDLE`
- Removed the old `GRID_FAULT` strategy gate. Active cleanup already prevents strategy execution.
- If a safety request arrives while cleanup is already running, the request flag is consumed without restarting cleanup.
- Updated the readable `.mq5` action-flow reference to Rev 30.02.
- CPU/function profiling remains unchanged.
- Strategy hooks remain unchanged and intentionally empty.

## Not changed

- No strategy from Rev 22.2 was added or altered.
- No async retry policy was added.
- No SL/grid/refill behavior was changed.
- The previously documented cleanup dead-local-item review issue was not changed in this revision.

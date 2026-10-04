# Changelog — Rev 30.01

This revision is a structural review baseline. It does **not** enable HedgeGrid strategy trading yet.

## Active architecture changes

- `Models/GridState.mqh`
  - Added `ENUM_GRID_LIFECYCLE` as the whole-cycle state.
  - Added unified `TradeItem` definition.
  - `GridState.lifecycle` is the first member.
  - `GridState.items[]` is the single durable array for orders, positions, and their async action state.
  - Retained Rev 22.2 strategy-state fields so strategy bricks can be migrated without inventing new strategy state.

- `Models/TransactionItem.mqh`
  - Added one compact event struct for facts captured by `OnTradeTransaction()`.

- `HedgeGrid.mq5`
  - `OnTradeTransaction()` is recorder-only and appends one `TransactionItem` per callback.
  - No strategy logic, history lookup, account scan, or broker action occurs in the callback.
  - No `OnTick()` workload.

- `Engines/TransactionHandler.mqh`
  - Added one explicit `HandleTransaction()` dispatcher.
  - REQUEST, DEAL_ADD, ORDER_*, and POSITION paths are visible in one place.
  - Durable results update `GridState.items[]`.

- `Utils/AsyncTrade.mqh`
  - Strategy-facing request helpers write actions onto `TradeItem` members.
  - `ProcessPendingActions()` is the only normal broker-send layer.
  - Normal broker actions use `OrderSendAsync()` only.

- `Engines/ReconcileEngine.mqh`
  - Broker/live state confirms PLACE, DELETE, CLOSE, and MODIFY_SL completion.
  - Added explicit WAIT_RESULT and WAIT_CONFIRM timeout caps.

- `Engines/CleanupEngine.mqh`
  - Cleanup uses the same `TradeItem.items[]` members; no separate cleanup request arrays.
  - Cleanup completion requires local book empty + live positions zero + live orders zero.

- `Engines/Scheduler.mqh`
  - Simple order: transactions -> cleanup decision -> async actions -> reconciliation -> strategy hooks.
  - One 15 ms global budget remains.

- `Engines/StrategyBridge.mqh`
  - Added the small, readable boundary where Rev 22.2 strategy bricks will be inserted after review.

- `Inputs.mqh`
  - Rev 22.2 inputs retained for future strategy migration.
  - Added `InpAsyncResultTimeoutMs` and `InpAsyncLiveConfirmTimeoutMs` as reviewable async caps.

## Strategy reference

- `Reference_Rev22_2/`
  - Contains the source from the user-provided Rev 22.2 project for direct comparison.
  - It is reference-only and not included by the active Rev 30.01 EA.

## Exact review locations

- `Models/GridState.mqh:13-314` — lifecycle enums, `TradeItem`, `GridState`, reset helpers.
- `Models/TransactionItem.mqh:5-73` — transaction inbox struct and reset helper.
- `HedgeGrid.mq5:73-109` — recorder-only `OnTradeTransaction()`.
- `Engines/TransactionHandler.mqh:48-381` — request/order/deal/position handlers and `HandleTransaction()` dispatcher.
- `Utils/AsyncTrade.mqh:38-300` — strategy request setters, `OrderSendAsync()` layer, pending-action processor.
- `Engines/ReconcileEngine.mqh:71-229` — WAIT_RESULT / WAIT_CONFIRM reconciliation and timeout handling.
- `Engines/CleanupEngine.mqh:13-112` — cleanup conversion to TradeItem actions and zero/zero finish invariant.
- `Engines/Scheduler.mqh:140-242` — simple scheduler order and frame budget.
- `Engines/StrategyBridge.mqh:18-58` — all strategy insertion points.
- `Inputs.mqh:192-193` — new async result/live-confirm timeout caps.

## CPU measurement completion — same Rev 30.01

Only diagnostic timing was added in this rewrite; no strategy or async-state behavior was changed.

- `Utils/ProfilerUtils.mqh:12-180`
  - Added the detailed wall-clock function profiler used by active Rev 30.01.
  - Reports `Last`, interval maximum, all-time maximum, interval average, and call count.
  - Separately times each `OrderSendAsync()` action type and profiler/log print overhead.

- `Inputs.mqh:195-201`
  - Added `InpEnableCpuProfiler` and `InpCpuProfileIntervalMs`.

- `HedgeGrid.mq5:73-109`
  - Times the recorder-only `OnTradeTransaction()` callback while preserving its existing data capture behavior.

- `Engines/TransactionHandler.mqh:19-381`
  - Times queue append, transaction dispatch, REQUEST/DEAL/ORDER/POSITION handling, `HistoryDealSelect()`, and queue processing.

- `Utils/AsyncTrade.mqh:38-300`
  - Times strategy-to-action request setters, pending-action processing, `SendTradeItemAction()`, and `OrderSendAsync()` separately for PLACE/DELETE/CLOSE/MODIFY_SL.

- `Engines/ReconcileEngine.mqh:71-229`
  - Times live reconciliation and live-order matching.

- `Engines/CleanupEngine.mqh:13-112`
  - Times cleanup activation and cleanup completion processing.

- `Utils/TradeBook.mqh:131-163`
  - Times live terminal position/order scans used by the cleanup invariant.

- `Engines/Scheduler.mqh:52-242`
  - Adds interval and all-time frame timing, interval duty, average frame time, transaction/action/reconciliation/cleanup stage timing, and Fast/Medium/Background strategy-hook timing.
  - CPU report now prints independently of `InpEnableDebugLog` when `InpEnableCpuProfiler=true`.
  - `WallDuty` is elapsed scheduler wall time, not operating-system CPU time.

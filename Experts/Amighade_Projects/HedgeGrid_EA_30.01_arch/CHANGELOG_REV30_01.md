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
- `HedgeGrid.mq5:72-105` — recorder-only `OnTradeTransaction()`.
- `Engines/TransactionHandler.mqh:47-346` — request/order/deal/position handlers and `HandleTransaction()` dispatcher.
- `Utils/AsyncTrade.mqh:28-248` — strategy request setters, `OrderSendAsync()` layer, pending-action processor.
- `Engines/ReconcileEngine.mqh:70-223` — WAIT_RESULT / WAIT_CONFIRM reconciliation and timeout handling.
- `Engines/CleanupEngine.mqh:12-100` — cleanup conversion to TradeItem actions and zero/zero finish invariant.
- `Engines/Scheduler.mqh:100-174` — simple scheduler order and frame budget.
- `Engines/StrategyBridge.mqh:18-58` — all strategy insertion points.
- `Inputs.mqh:192-193` — new async result/live-confirm timeout caps.

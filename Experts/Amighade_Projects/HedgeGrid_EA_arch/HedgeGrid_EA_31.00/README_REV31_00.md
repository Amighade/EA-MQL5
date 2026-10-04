# HedgeGrid Rev31.00 — Rev22.2 strategy on the async baseline

Rev31.00 adds the active Rev22.2 strategy to the post-simulation Rev30.04 infrastructure. The strategy sets commands on `GridState.items[]`; `Utils/AsyncTrade.mqh` remains the only broker request sender. The original Rev22.2 source is kept under `Reference_Rev22_2/` for comparison and is not included by the active EA.

## Where to read

| Order | File | Responsibility |
|---|---|---|
| 1 | `Inputs.mqh` | Strategy settings and defaults. |
| 2 | `Models/GridState.mqh` | Shared cycle state and item book. |
| 3 | `HedgeGrid.mq5`, `Engines/Scheduler.mqh` | Startup, event capture and the 15/50/250/60000 ms scheduler. |
| 4 | `Engines/StrategyBridge.mqh` | Small map from fills/tiers to the strategy modules. |
| 5 | `Engines/StrategyGrid.mqh` | Initial grid, lot sizing, lot increase and inside/outside refill. |
| 6 | `Engines/StrategyProtection.mqh` | Fill bookkeeping, basket values, SL wall/trailing and exit decision. |
| 7 | `Utils/SessionFilter.mqh` | Existing session rules used by grid start. |
| 8 | `Utils/AsyncTrade.mqh` | `Request...()` intent setters and the sole `OrderSendAsync()` path. |
| 9 | `Utils/TradeBook.mqh`, `Engines/TransactionHandler.mqh`, `Engines/ReconcileEngine.mqh`, `Engines/CleanupEngine.mqh` | Broker facts, exact identity matching, command confirmation and cleanup. |

## Repeatable pattern for the next strategy edit

1. Add or adjust its setting in `Inputs.mqh` only when the feature needs a setting.
2. Put the decision beside the related strategy logic: grid/refill logic in `StrategyGrid.mqh`; basket/SL/exit logic in `StrategyProtection.mqh`.
3. Call the existing request setter for the desired broker change: `RequestPlacePending`, `RequestReplaceOrder`, `RequestDeleteOrder`, `RequestClosePosition` or `RequestModifySL`.
4. Call the strategy routine from its existing bridge hook or scheduler tier. Keep broker request IDs, action statuses and result handling inside the async infrastructure.
5. Add one focused scenario to `Validation/strategy_tests.cpp` and run the lifecycle, race and stress suites.

Each strategy operation follows the same path: **condition → request setter → `ACTION_READY` item → async sender → broker result → live-state reconciliation**. Do not set `WAIT_RESULT`/`WAIT_CONFIRM` in strategy code or send directly from an event callback.

## Ported behavior and defaults

- Idle cycle builds 20 buy stops and 20 sell stops, with a $2.00 total nearest-order gap and $0.50 level spacing. The current-price anchor uses bid; the previous-bar-range anchor is still available.
- Initial sizing is fixed 0.01 lots by default. Ladder and exponential modes remain selectable.
- Lot increase, inside maintenance/refill, outside refill and SL arming/trailing are available but default to `NONE`.
- The source’s new-bar gate is commented out, so the grid builds when the EA is idle and the session filter allows it.
- Shifting and recentering remain disabled as in the active Rev22.2 source.
- Position exits use the infrastructure’s cycle-wide cleanup: close every EA position, delete every EA pending order, then wait for broker-confirmed zero positions and zero orders.
- Debug and CPU profiling remain disabled by default. The dashboard is not wired into this EA.

## Validation

The translated C++ harness passed 27 lifecycle groups, 8 broker-event race groups, 3 strategy groups, and 2,000 randomized broker timelines. The strategy tests confirm grid intent creation and async submission, the nearest-grid SL basket-net check, and cleanup after a full position exit. These checks do not replace native MetaEditor compilation or a MetaTrader demo/tester run. No live-account result is claimed.

See `CHANGELOG_REV31_00.md`, `AUDIT_REV30_04.md` and `SIMULATION_REV30_04.md` for changes and infrastructure validation. `Validation/README.md` contains repeatable commands.

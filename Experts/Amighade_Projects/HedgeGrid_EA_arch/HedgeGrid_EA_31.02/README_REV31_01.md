# HedgeGrid Rev31.01 — Rev22.2 strategy on the async baseline

Rev31.01 keeps the active Rev22.2 strategy on the post-simulation Rev30.04 infrastructure and fixes incomplete initial-grid recovery. The strategy sets commands on `GridState.items[]`; `Utils/AsyncTrade.mqh` remains the only broker request sender. The original Rev22.2 source is kept under `Reference_Rev22_2/` for comparison and is not included by the active EA.

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
- If any initial level fails placement, the EA deletes accepted orders and closes any positions from that build. It starts a fresh full grid only after broker state is zero positions and zero orders.
- Debug and CPU profiling remain disabled by default. The dashboard is not wired into this EA.

## Validation

Incomplete initial grids are now detected even while lifecycle is GRID_BUILDING. The EA waits for each initial placement result, then uses cycle-wide cleanup, retries rejected cancels, confirms broker zero positions and zero orders, and only then rebuilds the full grid.

The translated C++ harness passed 27 lifecycle groups, 8 broker-event race groups, 4 strategy groups, and 2,000 randomized broker timelines. The strategy tests include incomplete-grid cleanup and full-grid retry after broker zero/zero. These checks do not replace native MetaEditor compilation or a MetaTrader demo/tester run. No live-account result is claimed.

See `CHANGELOG_REV31_01.md` and `SIMULATION_REV31_01.md` for this fix and its validation; `AUDIT_REV30_04.md` covers the infrastructure baseline. `Validation/README.md` contains repeatable commands.

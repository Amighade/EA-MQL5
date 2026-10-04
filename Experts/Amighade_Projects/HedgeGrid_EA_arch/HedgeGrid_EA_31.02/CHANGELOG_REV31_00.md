# Rev31.00 — Rev22.2 strategy migration

## Added

- Activated the Rev22.2 grid, sizing, lot increase, refill and SL behavior on the Rev30.04 asynchronous request path.
- Added `StrategyGrid.mqh` for grid/refill decisions and `StrategyProtection.mqh` for fill, basket, SL and exit decisions. `StrategyBridge.mqh` stays a short dispatcher.
- Added the session filter to the active include graph. It retains the Rev22.2 session windows and defaults.
- Added focused strategy validation for the initial two-sided grid and the request-intent/sender boundary.
- An incomplete initial grid now triggers cycle-wide cleanup from `GRID_BUILDING` as well as `GRID_READY`/`GRID_ACTIVE`. After live zero positions and zero orders are confirmed, the next cycle builds a fresh complete grid.
- A full exit deal still reaches the strategy exit hook when broker synchronization has already removed the closed position item; pending orders then enter cycle cleanup.

## Integration fixes

- A late exact PLACE result now carries the original strategy level and lot metadata to the broker object. Partial fills can have both a pending remainder and a position, so the position receives the source metadata too.
- Kept same-price orders from claiming an unconfirmed PLACE. Only the exact request-result order ticket joins those local and broker records.
- An absent stable item, or a confirmed DELETE without replacement, is removed by the existing trade-book reconciliation. During cleanup, unresolved absent orders receive the existing live-confirmation grace period so a delayed fill can still be found.
- Partial CLOSE continuation still requires matching execution-order/deal history and the resulting live volume; a smaller snapshot alone does not unlock another close.
- Lot increase uses Rev22.2’s active first-pass behavior: increase only opposite-side orders below twice the last fill lot; do not lower higher lots.
- SL candidate modes keep the Rev22.2 basket-net check, including the nearest-grid mode.

## Preserved

- No direct or synchronous trade calls were added. Strategy code uses the existing request setters; `OrderSendAsync()` remains in `AsyncTrade.mqh`.
- Scheduler timing, shared work budget, tiny `OnTradeTransaction()` callback, and CPU-safe logging defaults remain unchanged.
- No new-bar gate, shifting, or recentering was enabled. Rev22.2 strategy defaults and grid geometry remain unchanged.

## Verification limits

27 lifecycle groups, 8 race groups, 4 strategy groups and 2,000 broker stress trials passed in the translated C++ harness. Native MetaEditor compilation and a MetaTrader demo/tester run remain unverified.

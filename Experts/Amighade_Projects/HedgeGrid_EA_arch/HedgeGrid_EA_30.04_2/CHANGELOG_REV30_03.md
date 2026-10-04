# Changelog — Rev 30.03

Scope: infrastructure completion only. No HedgeGrid strategy brick was added.

## Transaction handling

- Kept one consistent boolean contract for REQUEST / DEAL / ORDER / POSITION handlers.
- Kept generic `handlerRetries` for any handler waiting for broker data.
- Removed obsolete `_old` handler copies so there is only one active readable path.
- ORDER_DELETE that is not an explicit requested delete now marks the same item for reconciliation instead of leaving an unexplained dead local state.
- POSITION lookup failure now marks the same item for reconciliation.

## Broker data versus EA commands

- Broker ORDER / DEAL / reconciliation paths no longer create cleanup DELETE/CLOSE commands.
- A confirmed PLACE becomes `ACTION_NONE / ACTION_IDLE`.
- CleanupEngine is the owner of whole-cycle CLOSE / DELETE commands.

## DEAL entry identity

- Before `AddTradeItem()`, DEAL_ENTRY_IN now tries to recover the original planned item from the source historical order's type and original order price through the existing `FindPlannedOrder()` function.
- This reduces duplicate logical items when DEAL_ADD arrives before REQUEST / ORDER_ADD correlation is complete.

## Reconciliation

- Added `TradeItem.reconcileMisses`.
- `reconcilePending` now waits for a bounded number of broker misses before removing that one item.
- Stable ORDER / POSITION disappearance is routed into the same reconciliation path instead of leaving `brokerPresent=false` indefinitely.
- Scheduler reconciliation demand now checks missing position tickets as well as missing order tickets.
- Removed obsolete `ReconcileTradeItems_old()`.

## Cleanup

- `StartCleanup()` is now idempotent and can route newly-reconciled objects while `GRID_CLEANUP` remains active.
- Existing in-flight actions are not overwritten or resent.
- `ACTION_FAILED` is not silently turned into an automatic retry loop during continuing cleanup.
- `ProcessCleanupState()` reuses `StartCleanup()` before testing the hard zero/zero completion invariant.
- While cleanup is active, live EA-owned broker orders/positions that are missing from `items[]` are adopted into the same book and routed through normal DELETE/CLOSE actions.

## Async action send

- DELETE target already absent → use existing `ConfirmReplacementOrRemove()`.
- CLOSE target already absent → remove the local TradeItem.
- Moved `ConfirmReplacementOrRemove()` into `Utils/TradeBook.mqh` so both send and reconciliation paths use the same sequencing logic.

## Clarity

- Removed the now-redundant `cleanupAfterConfirm` flag; continuing cleanup routing handles late PLACE outcomes directly.
- Updated revision labels and action-flow reference to 30.03.
- Removed stale Rev 30.02 EX5 binaries from the active revision package. Source was not compiled in this environment.

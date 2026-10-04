# HedgeGrid Rev 30.03 — Simple Async Architecture

Rev 30.03 completes the transaction / reconciliation / cleanup infrastructure review before strategy migration.

The HedgeGrid strategy itself is still intentionally not enabled. Strategy hooks remain in `Engines/StrategyBridge.mqh` so strategy bricks can be added one at a time after this infrastructure is accepted.

## Core data flow

```text
OnTradeTransaction()
        ↓
TransactionItem transactionQueue[]
        ↓
ProcessTransactionQueue()
        ↓
HandleTransaction()
        ↓
GridState.items[]
        ↓
strategy / cleanup decides item.action
        ↓
ProcessPendingActions()
        ↓
OrderSendAsync()
        ↓
future broker transactions return through OnTradeTransaction()
```

## Important rule: broker data and commands are separate

Broker handlers and reconciliation fill what exists:

```text
ORDER / POSITION found
→ fill TradeItem broker fields
→ brokerPresent = true
```

Broker data does not create strategy commands. A confirmed PLACE returns to:

```text
action       = ACTION_NONE
actionStatus = ACTION_IDLE
```

Only strategy or the cleanup lifecycle creates `PLACE / DELETE / CLOSE / MODIFY_SL` commands.

## Handler contract

All transaction handlers use the same return contract:

```text
true  = handled or intentionally ignored
false = required broker data is not ready yet; retry later
```

`handlerRetries` is therefore generic and is not tied only to deal history.

## Reconciliation

If a transaction cannot be handled after the retry cap, the already-known `TradeItem` is marked:

```text
reconcilePending = true
```

`ReconcileTradeItems()` then checks live broker state.

```text
position found → synchronize same item
order found    → synchronize same item
neither found  → count reconcile misses
                 remove only that item after the bounded miss count
```

The miss counter avoids deleting an item after one transient lookup miss.

## ORDER → POSITION identity

A `DEAL_ENTRY_IN` first tries to find the existing item by broker tickets.

If the DEAL arrives before REQUEST / ORDER_ADD attached the broker ticket, Rev 30.03 uses the deal's source historical order type + original order price and the existing `FindPlannedOrder()` function before creating a new `TradeItem`.

This preserves the original logical grid item and avoids an unnecessary duplicate item.

## Cleanup

Cleanup remains a whole-cycle lifecycle:

```text
GRID_CLEANUP
→ live POSITION → ACTION_CLOSE
→ live ORDER    → ACTION_DELETE
```

`StartCleanup()` is idempotent and is reused while cleanup is active so an order or position discovered later is routed into the same cleanup lifecycle.

While cleanup is active it also scans the live EA-owned broker orders/positions and adopts any missing broker object into the same `items[]` book before assigning DELETE/CLOSE. This prevents the hard zero/zero invariant from getting stuck on a live object that was never represented locally.

It does not resend actions already in `WAIT_RESULT` / `WAIT_CONFIRM`.

Cycle completion is unchanged:

```text
items[] == 0
AND live EA positions == 0
AND live EA pending orders == 0
```

Only then does the state return to `GRID_IDLE`.

## Already-absent DELETE / CLOSE target

If `SendTradeItemAction()` reaches a DELETE or CLOSE whose broker object is already absent, that operation is already satisfied.

Rev 30.03 removes/resolves that local item instead of leaving a dead `ACTION_NONE / ACTION_IDLE` item in the book.

Delete-then-replace still uses the existing `ConfirmReplacementOrRemove()` sequencing.

## Strategy status

No strategy brick was added in Rev 30.03.

`Reference_Rev22_2/` remains the exact old strategy reference and is not compiled into the Rev 30.03 main source.

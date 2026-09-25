# HedgeGrid Rev 30.01 — Simple Async Architecture Review

Rev 30.01 is an **architecture/reference revision**, not a production strategy revision. It intentionally does not execute the HedgeGrid strategy yet. The exact Rev 22.2 strategy source is included under `Reference_Rev22_2/` so each strategy brick can be migrated and reviewed one at a time.

## The complete data flow

```text
MT5
 │
 ▼
OnTradeTransaction()
 │   copies facts only
 ▼
TransactionItem transactionQueue[]
 │
 ▼
ProcessTransactionQueue()
 │
 ▼
HandleTransaction()
 ├─ REQUEST      -> update async status on matching TradeItem
 ├─ DEAL_ADD     -> order/position bookkeeping -> strategy fill hook
 ├─ ORDER_*      -> update one TradeItem
 └─ POSITION     -> refresh one TradeItem
 │
 ▼
GridState
 ├─ lifecycle          <- status of whole cycle
 └─ TradeItem items[]  <- ONE order/position/action array
 │
 ├─ strategy writes action=PLACE/DELETE/CLOSE/MODIFY_SL
 │
 ▼
ProcessPendingActions()
 │
 ▼
OrderSendAsync()
 │
 ▼
future OnTradeTransaction() events return through the same inbox
```

## GridState rule

`GridState.lifecycle` is intentionally the **first field** of `GridState`.

`GridState.items[]` is intentionally the **second field** and is the only durable array representing pending orders and open positions.

There is no special first element inside `items[]`. Every array member is one `TradeItem`.

## What one TradeItem contains

One member carries both strategy identity and async execution state:

- local stable `id`
- ORDER or POSITION
- side / order type / optional grid level
- target price / lot / original lot
- broker order / position / deal tickets
- live price / volume / SL / TP
- requested action: PLACE / DELETE / CLOSE / MODIFY_SL
- action state: READY / WAIT_RESULT / WAIT_CONFIRM / FAILED
- request ID / attempts / timestamps / retcode
- delete-then-replace fields
- cleanup-after-confirm flag

The async request therefore does **not** need a second request array.

## TransactionItem rule

`TransactionItem` means only: **what MT5 just told us**.

It is temporary inbox data. Once `HandleTransaction()` consumes it, the durable result belongs in `GridState.items[]`.

## Strategy boundary

All strategy insertion points are in `Engines/StrategyBridge.mqh`:

- `Strategy_OnEntryFill()`
- `Strategy_OnExitDeal()`
- `Strategy_Fast()`
- `Strategy_Medium()`
- `Strategy_Background()`

`Strategy_OnEntryFill()` contains the exact Rev 22.2 post-fill sequence as comments so it is obvious where the existing strategy will be inserted.

## Cleanup rule

Cleanup does not have `closeSequence[]`, `orderSequence[]`, or `cleanupRequests[]`.

It sets:

```text
POSITION item -> action=CLOSE
ORDER item    -> action=DELETE
```

The cycle is finished only when:

```text
items[] is empty
AND terminal EA positions == 0
AND terminal EA orders == 0
```

Then `GridState` returns to `GRID_IDLE`.

## Async waiting

Rev 30.01 separates:

```text
READY -> WAIT_RESULT -> WAIT_CONFIRM -> IDLE
```

Waiting does not itself count as a broker rejection. For review, two explicit caps are centralized in `Inputs.mqh`:

- `InpAsyncResultTimeoutMs`
- `InpAsyncLiveConfirmTimeoutMs`

A timeout marks the TradeItem `ACTION_FAILED`. Rev 30.01 deliberately does **not** hide retry/cleanup policy inside the handler; that policy can be approved when strategy bricks are migrated.

## Reference strategy

`Reference_Rev22_2/` is copied from the user-provided `HedgeGrid_EA_22.2_SCHEDULER` revision. It is not compiled into Rev 30.01. Its purpose is to provide the exact known strategy behavior while rebuilding the new architecture one brick at a time.

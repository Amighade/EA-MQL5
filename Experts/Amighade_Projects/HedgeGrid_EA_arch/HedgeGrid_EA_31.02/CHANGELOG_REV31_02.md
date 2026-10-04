# Rev31.02 — bounded async request flow

Rev31.02 keeps the Rev22.2 strategy and Rev31.01 incomplete-grid recovery. It changes only how the existing async sender drains ready actions.

## Change

- `ProcessPendingActions()` now keeps no more than `InpCleanupAsyncBatch` requests in flight during normal placement and cleanup. The default is three. A slot opens only after the async result and broker live state have been reconciled, so a slow terminal/server does not receive an entire grid burst at once.
- The existing input name is retained, so existing `.set` files keep their configured value. Its comment now describes the shared limit.
- Partial-grid cleanup, retry, and the zero-position/zero-order rebuild condition are unchanged.

## Evidence and limits

The supplied journal reports request completion times of 138,454 ms and 178,173 ms, invalid-price rejections, and cancel rejections near market. The code cannot make a broker process requests faster. Bounded submission reduces the number of unresolved requests queued together and ensures later grid levels wait for confirmed live state.

The validation harness checks that only three requests are sent initially, no additional request is sent while those remain unresolved, and the remaining items are sent after confirmation. Native MetaEditor compilation and MT5 execution are not available here.

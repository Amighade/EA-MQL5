# REV-2026-09-11-CPU-FIX

Baseline: rev13 (upload `1789080208500_HedgeGrid_EA_14.zip`), reverted from
rev14 after rev14's transaction-gateway widening (reacting to ORDER_ADD /
ORDER_DELETE in addition to DEAL_ADD) caused a pulse-multiplication cascade
combined with blocking Sleep()-based retries, freezing the VPS terminal.

Every code comment tagged `[REV-2026-09-11-CPU-FIX]` traces back to this file.
Grep the tag to find every touched spot directly in-file.

## Utils/TradeUtils.mqh

- **Line 296, `ClosePosition`**: removed the `Sleep(20/60/80/120)` retry/verify
  loop, capped to 2 total attempts, no blocking. Why: blocked the EA thread
  on every rejected close; this function is now also the fallback path for
  failed SL modifies (see SLManager.mqh below), so it runs more often than
  it used to.
- **Line 407, `ModifyPositionSL`**: same change — retry loop cut from
  `InpSafetyRetryAttempts` × `Sleep(InpSafetyRetryDelayMs)` to exactly one
  immediate retry, no Sleep. Why: this ran every tick during SL trailing;
  a blocking sleep here on a rejected modify froze the whole EA, and
  rejections were frequent during fast price movement.

## Engines/SLManager.mqh

- **Line 41 (header comment)**: updated to describe the new close-on-fail
  behavior instead of the old "Bug 1.a: immediate TriggerSafetyStop" text.
- **Line 126, new `CountMatchingPositions()` + `CalculateSLCandidate`**:
  replaced `CollectAllPositions` (builds/copies a full SLPos[] array every
  call) with a count-only scan. Why: none of the live `ENUM_SL_MODE`
  branches in `SL_FindCandidate` ever read the position array — it was
  built and thrown away on every call, every tick while armed.
  Note: this specific edit was made mid-session via a tool call that
  reported failure but silently applied anyway — flagged to the user when
  discovered via diff against the original upload.
- **Line 170, `ApplySLToWinners`**: on a modify failure (after
  `ModifyPositionSL`'s one retry), close just that ticket instead of
  calling `TriggerSafetyStop` on the whole basket. Escalates to
  `TriggerSafetyStop` only if the close itself also fails. Why: nuking
  every position/order for one rejected modify was wildly disproportionate,
  and modify rejections were routine, not rare.
- **Line 283, `ArmSL`**: removed unguarded `Print(...)//AGH` debug leftover
  (not gated by `InpEnableDebugLog`).
- **Line 353, `TrailWall`**: removed the same unguarded `Print(...)//AGH`,
  present every tick while armed.
- **Line 358, `TrailWall`**: removed the unconditional `SnapshotWinners()`
  call. Why: re-scanned every open position every tick while armed; the
  armed-winner set only changes on a new fill, already handled correctly
  and exclusively by `ReSnapshotIfArmed` (called from the coordinator on
  fills) and the initial snapshot inside `ArmSL`.

## Models/GridState.mqh

- **Line 73, new field `lastCleanupUnstickCheck`** (+ init to 0 in
  `ResetGridState`): timestamp used to throttle the `OnTick` reconciliation
  scan below instead of running it every tick.

## HedgeGrid.mq5

- **Line 197, `OnTick`**: the `cleanupInProgress && CountPositions()==0`
  reconciliation check (a rare-miss safety net, not the normal progress
  path — that's driven by `OnTradeTransaction`) now only runs once every
  2 seconds instead of every tick, using `lastCleanupUnstickCheck`.
- **Line 241, `OnTick`**: `CalculateBasketProfits(g_state)` now skipped
  while `cleanupInProgress` is true — `OnTick` returns right after with
  nothing that tick consuming the result, so it was a wasted full
  position-loop scan on every cleanup tick.

## Explicitly NOT changed (discussed, decided against)

- `TrailWall_orgn` was not wired in — user chose to keep `InpSLTrailMode`-
  based trailing (via `CalculateSLCandidate`) rather than switch to the
  fixed grid-step version `TrailWall_orgn` implements. `TrailWall_orgn`
  remains dead/unused code.
- "Arm one winner ticket, let cleanup close the rest" was considered and
  explicitly rejected — removes broker-side SL protection from most of the
  basket, a real risk increase, not just a performance trade-off.
- `PlacePendingWithWidening`'s own `Sleep(50*attempt)` retry (grid order
  placement, `TradeUtils.mqh` ~line 225) was never discussed and is
  untouched.

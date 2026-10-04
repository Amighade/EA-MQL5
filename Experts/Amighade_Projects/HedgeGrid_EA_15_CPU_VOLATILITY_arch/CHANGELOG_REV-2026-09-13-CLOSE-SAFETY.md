# REV-2026-09-13-CLOSE-SAFETY

Baseline: REV-2026-09-12-BACKBONE (previous zip). Grep
`[REV-2026-09-13-CLOSE-SAFETY]` in any file for the exact spot + reasoning.

Adds: paced (one-by-one) loser-position closing as the default, sharing the
same paced-close pattern the winner-side cleanup already uses instead of a
second bespoke mechanism; a stagnation-aware recheck/retry backstop shared
by both the winner cleanup and the loser purge; and a Telegram alarm after
repeated stuck detections.

## Why bulk closing was replaced as the default (not removed — selectable)

Walked through with the user: MT5 guarantees every transaction/tick gets
delivered to the EA (not the risk). The real risk is the *broker's* request
rate tolerance — `OrderSend` waits for a reply before the next line runs,
so a bulk loop fires N close requests back-to-back as fast as the network
round-trip allows, with no pacing. `TRADE_RETCODE_TOO_MANY_REQUESTS` exists
because brokers do rate-limit this. One-by-one via real confirmations has
no such burst — for the winner side there's no burst at all (broker's own
resting SL orders trigger on their own pace); for the loser purge, pacing
via `ClosePosition` after each confirmed close avoids sending N requests in
one instant. `InpCloseLosersBulk` (default `false`) keeps bulk available
for comparison, but paced is now the default.

## Inputs.mqh

- **New `InpCloseLosersBulk`** (default false): bulk vs. paced loser
  *position* closing. Does NOT affect loser-side pending *order* deletion,
  which stays a single bulk call unconditionally — no broker-burst risk in
  deleting resting orders that never triggered, only in closing live
  positions.
- **New `InpCloseStuckAlarmAfter`** (default 3): consecutive stagnant
  ~2s-interval recheck cycles before the Telegram alarm fires. Shared by
  both the cleanup and loser-purge backstops.

## Models/GridState.mqh

- **New fields**: `loserPurgeSequence[]`, `loserPurgeIndex`,
  `loserPurgeInProgress` (the paced loser-close sequence — structurally
  identical to `closeSequence`/`closeIndex`/`cleanupInProgress`, kept
  separate because it must coexist with winners still being armed and
  waiting on their SL, which `cleanupInProgress`'s semantics don't allow).
  `lastCleanupRemainingCount`/`cleanupStuckCount` and
  `lastLoserPurgeRemainingCount`/`loserPurgeStuckCount` (stagnation
  detection + alarm counters for each). All reset in `ResetGridState`,
  and the loser-purge ones additionally reset at the start of each
  respective sequence (`StartLoserPurgeSequence`/`StartCleanupSequence`)
  as a defensive measure against stale carryover.

## Utils/TradeUtils.mqh

- **New `CountPositionsBySide`**: same shape as the existing
  `CountPositions`, filtered to one side — used by the loser-purge
  stagnation check.

## Engines/CleanupReset.mqh

- **New `StartLoserPurgeSequence` / `ExecuteNextLoserPurgeStep`**:
  deliberately reuses the exact paced-close pattern `StartCleanupSequence`/
  `ExecuteNextCloseStep` already use, rather than inventing a second one.
  Simpler than the winner-cleanup version: no zigzag/profit ordering (no
  ordering rationale for losers — they're not being closed in any sequence
  that matters), and completion just clears the flag (no full cycle
  reset — winners are still armed and waiting).
  Used identically regardless of `InpCloseLosersBulk`: bulk mode does a
  best-effort `CloseAllPositionsBySide` first, then this sequence
  (re)scans for whatever's still open — empty array if bulk fully worked,
  so it completes immediately at no extra cost either way. This is what
  makes the recheck mechanism "the same for both options," as asked.

## Engines/SLManager.mqh — `ArmSL`

- Loser handling now: delete loser-side orders (bulk, unconditional,
  immediate) -> if `InpCloseLosersBulk`, best-effort bulk close first ->
  `StartLoserPurgeSequence` + one immediate `ExecuteNextLoserPurgeStep`
  either way -> freeze the loser-side aggregate immediately (not when the
  paced close finishes -- see note below).

### Bug caught and fixed mid-implementation
Initially left the loser-side aggregate freeze to happen only once the
paced purge fully completed. That's wrong: `UpdateSideVolumeAggregate`
already stops updating the loser side the moment `InpCloseLosersAtArm` is
true (regardless of purge progress), so if the freeze/zero itself waited
for completion, `NetBasketAtCandidate` would keep reading a **stale**
pre-purge loser volume/entry for however long the paced close takes to
drain — incorrectly still "penalizing" the net-check for losers that are
already committed to closing. Fixed: the freeze happens immediately when
the purge decision is made, not when the mechanical close finishes.

## HedgeGrid.mq5

- **`OnTradeTransaction`**: new `loserPurgeInProgress` gateway, mirroring
  the existing `cleanupInProgress` one, placed right after it. Without
  this, loser-purge closes (`DEAL_REASON_EXPERT`) would just fall through
  to the close branch, get correctly excluded from `winnerStoppedOut`, and
  then nothing would ever advance `loserPurgeIndex` — this gateway is what
  actually drives the paced purge pulse-by-pulse. These pulses skip the
  aggregate update entirely (early `return`), which is fine and intended:
  the aggregate was already zeroed at the moment the purge started, so
  there's nothing left to update from these specific closes.
- **`OnTick` recheck block — rewritten**: previously only fired
  `ExecuteNextCloseStep` when `CountPositions()==0` (catches a fully-missed
  final pulse, nothing else). Now tracks whether the remaining count
  actually changed since the last ~2s check:
  - Count unchanged since last check -> genuinely stagnant -> retry the
    close, increment the stuck counter, alarm after
    `InpCloseStuckAlarmAfter` consecutive stagnant checks.
  - Count changed -> normal progress via real confirmations -> don't
    interfere (retrying here too would risk a duplicate close request on
    a ticket that's already legitimately in flight — the exact problem
    fixed earlier this session for the multi-pulse-per-close issue).
  Same logic, same throttle, applied to both `cleanupInProgress` and
  `loserPurgeInProgress` in one combined block.

## Confirmed, not re-implemented (already true by existing structure)

- "Don't proceed to a new cycle until closure is confirmed" doesn't need a
  new gate: `CheckAndBuildGrid` already returns early via
  `if(state.gridPlaced) return;`, and `gridPlaced` stays true throughout
  arming/purging/trailing/cleanup until a full `ResetCycle`. A stuck
  purge or stuck cleanup already can't be bypassed by a fresh grid being
  built underneath it — verified by reading `CheckAndBuildGrid`, not
  assumed.
- Arming happens before the loser purge (already the order, both agreed
  and in the code) — winners get protected before anything else risky
  (sending close requests) happens.

## Known follow-ups (flagged, not fixed this pass)

- **State persistence gap**: `Utils/StatePersistence.mqh` serializes
  `GridState` field-by-field explicitly, and none of the new fields from
  this pass (or `lastCleanupUnstickCheck` from the previous CPU-fix pass)
  are included. If the EA restarts mid-cleanup or mid-purge, this tracking
  state resets to defaults on reload rather than resuming exactly where
  it left off. Not fixed here — flagged since it's a real gap, worth a
  dedicated pass if resuming exact mid-sequence state across restarts
  matters.
- This project has not been run through an actual MQL5 compiler in this
  environment across either this pass or the previous backbone pass —
  recommend compiling before live/demo use given the cumulative scope.

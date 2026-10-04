# REV-2026-09-14-CLOSE-STYLE

Baseline: REV-2026-09-13-CLOSE-SAFETY (previous zip). Grep
`[REV-2026-09-14-CLOSE-STYLE]` in any file for the exact spot + reasoning.

Two changes: broadened the bulk-vs-paced choice from "loser purge only" to
"loser purge AND winner cleanup, one shared choice" via a new enum; fixed
the state-persistence gap flagged (not fixed) in the previous pass.

## Inputs.mqh

- **`InpCloseLosersBulk` (bool) removed, replaced by `InpCloseStyle`
  (new `ENUM_CLOSE_STYLE`: `CLOSE_STYLE_PACED` / `CLOSE_STYLE_BULK`,
  default `CLOSE_STYLE_PACED`)**. Enum instead of bool because "how do
  we close" is one choice now applied in two places (loser purge at arm,
  winner cleanup after SL hit), not two independent toggles that could
  drift out of sync with each other.

## Utils/CloseOrderUtils.mqh

- **New `CloseAllPositions(magicNumber)`**: same shape as
  `CloseAllPositionsBySide`, no side filter. Needed because cleanup
  sweeps whatever's left regardless of side (unlike the loser purge,
  which is inherently side-scoped).

## Engines/SLManager.mqh — `ArmSL`

- Swapped `InpCloseLosersBulk` for `InpCloseStyle == CLOSE_STYLE_BULK`.
  No behavior change from the previous pass, just the new shared input.

## Engines/CleanupReset.mqh — `StartCleanupSequence`

- **New bulk pre-pass**: when `InpCloseStyle == CLOSE_STYLE_BULK`, calls
  `CloseAllPositions()` before `BuildAbsProfitPositionOrder` rescans.
  Same pattern already established for the loser purge: bulk is just a
  best-effort first attempt, then the existing paced sequence
  (`closeSequence`/`ExecuteNextCloseStep`) and its stagnation-recheck
  backstop from the previous pass take over for whatever's still open --
  empty rescan if bulk fully worked, so this costs nothing extra in that
  case. The `OnTick` recheck logic needed zero changes for this --  it
  already just watches "is the remaining count changing," which is true
  regardless of which style started the sequence.

## Utils/StatePersistence.mqh — the flagged gap, now fixed

- **`STATE_FILE_VERSION` bumped 1 -> 2.** `LoadGridState` already treats
  a version mismatch as "ignore, fresh start" (pre-existing behavior,
  unchanged) -- so old saved state files on disk are simply discarded on
  first load after this update. No migration path needed; the existing
  mismatch handling already covers it correctly.
- **Added to both `SaveGridState` and `LoadGridState`, in matching
  order**: `buyVolume`, `buyAvgEntry`, `sellVolume`, `sellAvgEntry`,
  `winnerStoppedOut` (from REV-2026-09-12-BACKBONE);
  `lastCleanupUnstickCheck` (from REV-2026-09-11-CPU-FIX, never added
  before now); `lastCleanupRemainingCount`, `cleanupStuckCount`,
  `loserPurgeSequence[]` (with its size prefix, same pattern as the
  existing `levelPrices`/`runLevels` arrays), `loserPurgeIndex`,
  `loserPurgeInProgress`, `lastLoserPurgeRemainingCount`,
  `loserPurgeStuckCount` (from REV-2026-09-13-CLOSE-SAFETY). A restart
  mid-cleanup or mid-purge now resumes from the exact saved state instead
  of losing this tracking on reload.

## User's stated plan for later (not acted on, just recorded)

Once testing is complete, most of these selectable options
(`InpCloseLosersAtArm`, `InpCloseStyle`, etc.) are intended to be deleted
and the EA committed to whichever behavior testing favors. Nothing to do
about this now -- noted here so it isn't forgotten when that cleanup pass
happens.

# REV-2026-09-12-BACKBONE

Baseline: the user's own hand-edited rev14 upload (`1789315843124_HedgeGrid_EA_14.zip`),
which already included the REV-2026-09-11-CPU-FIX changes plus the user's own
in-progress edits to SL_FindCandidate (blank pos[] list, InpSLNBack fix,
several commented-out alternate blocks).

Implements the full arm/trail backbone agreed over this session: winner-only
arming with an optional immediate loser purge, O(1) per-side profit tracking
replacing all position-loop-based profit checks, and the "OnTradeTransaction
only records facts, OnTick decides and acts" split for cleanup triggering.

Grep `[REV-2026-09-12-BACKBONE]` in any file to find every changed spot with
its reasoning inline.

## Inputs.mqh

- **New input `InpCloseLosersAtArm` (default true)**: selectable per user
  request, to A/B test closing the losing side immediately at arm vs.
  leaving it open until normal cleanup.

## Models/GridState.mqh

- **New fields**: `buyVolume`, `buyAvgEntry`, `sellVolume`, `sellAvgEntry`
  (the O(1) incremental per-side profit aggregate) and `winnerStoppedOut`
  (the OnTradeTransaction -> OnTick signal flag). All reset in
  `ResetGridState`.

## Utils/MathUtils.mqh

- **New function `SideProfitAtPrice`**: O(1) profit formula using the
  incremental aggregate instead of looping positions. Commission is
  computed on the fly as `InpCommissionPerLot * volume` -- since it's a
  flat configured rate, not something that needs tracking per-fill, there
  was no need for a separate running commission total.

## Engines/OrderMonitor.mqh

- **New function `UpdateSideVolumeAggregate`**: maintains `{volume,
  avgEntry}` per side incrementally from deal history. Called from
  `OnTradeTransaction` on both opens and closes. Side is derived from
  `deal_type` + `dealEntry` (a BUY deal closes a SELL position and vice
  versa), not from `PositionGetInteger` on the ticket, because a fully-
  closing OUT deal can leave the position unselectable by the time this
  runs. Freezes for the winner side once armed; keeps updating the loser
  side post-arm only when `InpCloseLosersAtArm` is false.

## Engines/SLGridFeasibility.mqh — full rewrite

- **Removed** `SLPos`, `SL_CalcNetBasket` (looped every position, every
  call; also evaluated the loser side at the winner's candidate price,
  which was never correct -- a loser doesn't close at the winner's SL).
- **New** `NetBasketAtCandidate`: O(1) net-check using the aggregate.
  Winner evaluated at the candidate; loser (if still open) evaluated at
  its own live market price, not the candidate.
- **New** `SL_IsProgress`: the "never move SL backward" guard, now applied
  consistently to all 4 modes. Previously only `SL_NEAREST_P_GRID` and
  `SL_FAREST_P_GRID` had it -- `SL_P_LEVEL` and `SL_FIRST_GRID` didn't,
  meaning those two modes could have trailed a live SL backward. Real gap,
  now closed.
- **New** `SL_SearchGridLevels`: `SL_NEAREST_P_GRID` and `SL_FAREST_P_GRID`
  were near-duplicate blocks (same checks, only loop direction differed) --
  merged into one shared search, direction as a bool param.
- **`net >= 0.0` check**: was present on 3 of 4 modes, silently missing on
  `SL_FIRST_GRID`. Now consistent across all 4.
- The user's own in-progress edit already fixed `SL_NEAREST_P_GRID`'s
  hardcoded `maxN = 3` to use `InpSLNBack` -- carried forward as-is, not
  re-touched.

## Engines/SLManager.mqh

- **`CalculateSLCandidate`**: simplified to a thin passthrough to
  `SL_FindCandidate` (new 4-arg signature, no more `pos[]`/`count`). Kept
  as a named wrapper on purpose, not inlined into callers -- so `ArmSL`
  and `TrailWall` share one choke point and can't independently drift the
  way `TrailWall`/`TrailWall_orgn` once did.
- **Removed** `CollectAllPositions`, `SLPosInfo`, `NetPnLAtCandidate`,
  `CountMatchingPositions`, `GetWinningDirection` -- all dead once the O(1)
  aggregate replaced the position-loop approach everywhere.
- **`ArmSL`**: rewritten per the agreed sequence -- arm winners (unchanged
  mechanism) -> if `InpCloseLosersAtArm`, bulk-close the loser side and
  delete its pending orders in one shot (no ordering needed, unlike winner
  cleanup) -> freeze the winner-side aggregate (always) and the loser-side
  aggregate (only if it was actually purged).
- **`ProcessSLManager`**: replaced `AccountInfoDouble(ACCOUNT_PROFIT)`
  (account-wide, wrong for multi-EA accounts -- flagged, not fixed, user
  is aware) with the O(1) per-side check, scoped to
  `state.lastHitDirection`'s side specifically, only while unarmed.
- **Not touched**: `TrailWall`'s internal flow (its every-tick re-arm/
  re-log behavior), `TrailWall_orgn` (still dead/unused, still has the
  pre-existing `g_state` vs. local `state` parameter mismatch bug --
  harmless since it's never called, left alone since it's out of scope).

## Engines/GridBuilder.mqh

- **`BuildGrid`**: zeroes the 4 aggregate fields at the start -- fresh
  grid has no positions yet, and not every path that reaches `BuildGrid`
  goes through `ResetGridState` first (e.g. phantom-grid recovery).
- **`RefillOutside`**: now skips the non-winner side once armed (`skipSell`/
  `skipBuy`), per "outside maintenance only touches the winner side once
  armed."

## Utils/CloseOrderUtils.mqh

- **New function `CloseAllPositionsBySide`**: one-shot bulk close, filtered
  by magic + symbol + side, for the loser purge in `ArmSL`.

## Utils/TradeUtils.mqh

- **New function `DeleteOrdersBySide`**: same idea as `DeleteAllOrders`,
  filtered to one side's pending-order type, for the loser-side order
  purge in `ArmSL`.

## HedgeGrid.mq5

- **`OnTradeTransaction`, close branch**: this used to treat ANY close as
  an unconditional cleanup trigger (`StartCleanupSequence` called
  directly). That broke the moment `ArmSL` started bulk-closing the loser
  side itself -- those closes (`DEAL_REASON_EXPERT`) would have
  immediately re-triggered cleanup right after arming, undoing the whole
  "protect winners, wait for their SL" design. Fix: only
  `DEAL_REASON_EXPERT` is excluded from setting the trigger; every other
  reason (SL, SO, manual/client/mobile/web) still sets
  `state.winnerStoppedOut = true`, preserving the original "any
  unexpected close is a safety signal" breadth for everything that isn't
  self-caused. This branch (and the open branch) now also calls
  `UpdateSideVolumeAggregate` unconditionally -- cheap monitoring, stays
  in the transaction handler.
- **`OnTradeTransaction`, open branch**: removed the direct
  `ProcessSLManager(state)` call that used to run on every fill. Arming
  (and now the loser-purge burst inside it) is execution, not monitoring
  -- per the "transactions record, ticks decide" rule agreed this
  session, this belongs in `OnTick` only. `OnTick` already calls
  `ProcessSLManager` every tick while `cycleActive`, so this costs at
  most one tick of latency (sub-second), not a missed arm.
- **`OnTick`**: new block consumes `winnerStoppedOut` -- clears the flag
  unconditionally (even if cleanup is already running, so a burst of
  several near-simultaneous SL hits can't leave it stuck true and
  wrongly re-trigger cleanup later), and only calls
  `StartCleanupSequence` if cleanup isn't already in progress.

## Known follow-ups (flagged, not fixed this pass)

- `ReSnapshotIfArmed` still does a full `SnapshotWinners()` rebuild on
  every new fill while armed, rather than appending just the one new
  ticket. Discussed as worth doing, not implemented here.
- `ACCOUNT_PROFIT` was already the wrong scope for a multi-EA account
  before this pass and still would be if reintroduced anywhere -- the
  new aggregate is correctly magic/symbol-scoped, but this is worth
  remembering if this account ever runs more than one EA or symbol.
- This project was not run through an actual MQL5 compiler in this
  environment -- recommend compiling before live/demo use, given the
  scope of this pass.

## Explicitly confirmed, not re-litigated this pass

- Winner-side label (`state.slWinnerSide`) frozen at arm, membership
  (`g_ArmedWinnerTickets`) NOT frozen -- new winner-side fills still get
  added while armed.
- Trailing needs no live profit at all (confirmed) -- this is what makes
  freezing/zeroing the winner-side aggregate at arm safe.
- `InpCloseLosersAtArm` is a genuine strategy trade-off (removes the
  hedge for that cycle), not a pure engineering simplification -- pros/
  cons discussed at length before implementation; user chose to make it
  selectable and test both rather than commit to one permanently.

# HedgeGrid EA — Master Specification Document (v4.00)

> **This is a full architectural rewrite.** Style A / B / C no longer exist as
> hardcoded engines. Every behavior is now an independent, toggleable "brick"
> (see Section 3). A "style" is simply a saved combination of brick settings —
> there is no code path that treats "Style A" as a special case anywhere.
> Named combo presets (auto-selecting bricks for a saved style) are a planned
> phase-2 feature and are **not** implemented in this version.

---

## TABLE OF CONTENTS

1. Overview
2. Core Definitions
3. The Brick System
4. Grid Lifecycle (build / refill / shift / recenter)
5. SL System (Brick 6) — arm, snapshot, trail, cleanup trigger
6. Safety Net (broker faults, Telegram alarm, emergency close)
7. Cleanup (Brick 7)
8. Priority & Sequencing Rules
9. Input Parameter Reference
10. File Structure
11. Changelog — Bugs Fixed in This Rewrite
12. Known Assumptions Flagged for Confirmation
13. Edge Case Handling

---

## 1. OVERVIEW

HedgeGrid places a symmetric hedge grid of BUY STOP / SELL STOP orders around
price. When one side is hit, the EA can (depending on which bricks are
enabled): grow the opposite side's lot size, shift the opposite side to
maintain a gap, refill gaps or depleted ranges, arm a breakeven-safe SL wall
on the winning side once it's profitable, and clean up (close positions
and/or delete orders) once that wall is fully triggered — or on any broker
fault / manual emergency press.

Nothing above is mandatory. Every one of those behaviors is its own on/off
switch. With everything off, HedgeGrid is just: build a grid once per empty
candle, and do nothing else.

---

## 2. CORE DEFINITIONS

- **Cycle**: the period from grid build to the next full reset.
- **cycleActive**: true once at least one position exists this cycle.
- **gridPlaced**: true once orders exist for the current cycle (fresh or not).
- **Fresh grid**: `gridPlaced == true && cycleActive == false` — no positions
  yet, only pending orders. Recentering only acts on a fresh grid.
- **Block lot**: the lot size currently used for opposite-side placement,
  tracked in `GridState.currentBlockLot`. Only changes if Brick 1 is on.
- **Last hit**: the most recent position opened, tracked in
  `GridState.lastHitPrice/lastHitDirection/lastHitLot`.
- **Farthest hit**: the highest BUY fill / lowest SELL fill reached so far
  this cycle (`farthestHitBuy` / `farthestHitSell`) — feeds Brick 2's
  `SHIFT_FARTHEST_HIT` option.
- **Pass counter**: increments on every direction switch (a hit on the
  opposite side from the previous hit). Drives Brick 1's mode A algorithm.
- **Armed winner set**: the snapshot of winning-side position tickets that
  received the SL wall (Brick 6). Re-captured on every new fill while armed.

---

## 3. THE BRICK SYSTEM

Each brick is independent. Nothing auto-couples with anything else — where
two bricks conflict (see notes below), it is the user's responsibility to
avoid enabling both. This is deliberate: named combo presets with built-in
guardrails are a phase-2 feature, not this version.

| # | Brick | Input(s) | Off behavior | On behavior |
|---|-------|----------|---------------|-------------|
| 1 | Lot increase on opposite-side hit | `InpEnableLotIncrease`, `InpLotIncreaseMode` | Lots never change (fixed forever) | Mode A: pass-counter driven (1st pass partial-update, 2nd+ pass full replace). Modes B/C are unimplemented stubs reserved for future logic. |
| 2 | Shifting on gap | `InpEnableShifting`, `InpShiftAnchor` | Opposite side never shifts | Deletes and rebuilds the opposite side at exactly one anchor: last hit, farthest hit, or current price (single choice, no "take the more conservative of two" hybrid). |
| 3 | Recentering | `InpEnableRecentering`, `InpThresholdFactor` | Fresh grid never recenters | On a fresh, off-center grid, once per candle: delete all orders, flag for rebuild at current price. |
| 4 | Refill inside gap | `InpEnableRefillInside` | No inside refill | Whenever the gap between nearest BUY/SELL exceeds the configured gap and the zone is empty, fills it in, maintaining `InpInitialGap` at the center. |
| 5 | Refill outside range | `InpEnableRefillOutside`, `InpMinGridLevels`, `InpMaxGridLevels` | No outside refill | When a side's order count drops below `InpMinGridLevels`, extends it back up to `InpMaxGridLevels`. |
| 6 | SL (breakeven-lock) | `InpEnableSL`, `InpSLMode`, `InpSLNBack` | No SL ever added | See Section 5. |
| 7 | Cleanup type | `InpCleanupMode` | n/a (always applies) | `CLEANUP_CLOSE_ALL`: delete orders + close positions, full reset. `CLEANUP_CLOSE_POSITIONS`: close positions only, orders survive. |

Plus one input that existed implicitly in the old styles but wasn't one of
the 11 discussed bricks — **initial grid sizing** (`InpInitialSizing`:
`SIZING_FIXED` or `SIZING_LADDER`). This governs lot sizing at *build* time,
completely separate from Brick 1 (which governs lot changes *after* a hit).
See Section 12 — this was added as an inferred requirement, not explicitly
specified, and is flagged there for your confirmation.

**Documented conflicts (not auto-enforced):**
- Keep `InpEnableShifting = false` when either refill brick is on.
- Keep `InpEnableLotIncrease = false` when either refill brick is on.

---

## 4. GRID LIFECYCLE

### 4.1 Build (initial or on candle-open)
The **only** place a grid is ever built is the coordinator's per-candle
check (`CheckAndBuildGridOnNewCandle` in `HedgeGrid.mq5`):

```
every new candle:
   if session not allowed        -> skip
   if a grid already exists      -> skip
   if a cleanup is in progress   -> skip (closing outranks opening)
   check margin, pick lot mode
   build grid (price-outward, in pairs)
```

`OnInit` does **not** build a grid (item 11) — editing an input on
a running chart (which forces `OnDeinit` -> `OnInit`) no longer wipes an
existing grid. On the EA's very first run, `gridPlaced` starts false, so the
very next candle-open tick builds the first grid automatically — no special
"first run" logic needed.

`OnTick` also no longer builds a grid the instant a trading session starts —
that immediate-build path has been removed entirely (item 11 confirmed).
Grid building always waits for the next candle-open.

### 4.2 Refill (Bricks 4/5)
Runs after a cleanup sequence completes, if `refillNeeded` was set.
**Priority: inside refill always runs before outside refill** — enforced
inside `FillOneSide()`, which checks the inside-gap condition first.

### 4.3 Shift (Brick 2)
Runs immediately after a normal fill (`OnTradeTransaction`, `DEAL_ENTRY_IN`),
before the SL check. Deletes and rebuilds only the opposite (gapped) side.

### 4.4 Recenter (Brick 3)
Runs once per candle from `OnTick`, only on a fresh grid.

---

## 5. SL SYSTEM (BRICK 6)

Unified — there is no longer a separate "Style A/B path" vs. "Style C path".
Every combination uses the same arm -> snapshot -> trail -> all-closed ->
cleanup pipeline that used to be Style-C-only.

### 5.1 Trigger
Arms as soon as the leading side's basket profit is positive. See Section 12
— the old `InpSLTriggerByLot` / `InpSLTriggerByProfit` toggles were dropped
per instruction; "profit > 0" is the only trigger left.

### 5.2 Placement (`InpSLMode`)
Candidates are grid lines stepping back from the winning side's most recent
fill, in `InpGridSpacing` increments. Each candidate is tested with a
net-PnL-safe formula (all open entries/lots, commission, spread, broker
minimum stop distance). The largest step `n` for which the test still
passes is `maxValidN`.

- **`SL_LAST_HIT_GRID`**: always `n = 1` — the last hit's own grid line, no
  search beyond it. If that single candidate isn't safe yet, no SL is placed
  (tries again next check).
- **`SL_N_BACK_GRID`**: `n = MIN(InpSLNBack, maxValidN)` — depth-clamped to
  the farthest grid line that's still safe, even if the requested `n` would
  overshoot into unsafe territory.

SL applies to **every** position on the winning side, whether individually
profitable or not — not just the profitable subset.

### 5.3 Trailing
The net-PnL search above is heavy (loops every position per candidate). It
only runs:
- once, at arm time, and
- again whenever an armed winner **closes** (`RecalcOnWinnerClose`) — the
  position set changed, so the safe level might have changed too.

Per-tick trailing (`TrailWall`, called every tick while armed) is a cheap,
purely arithmetic step: if price has advanced past the next grid line beyond
the current SL, step the SL forward by one `InpGridSpacing` increment — no
position loop, no PnL recompute.

### 5.4 Re-snapshot
The armed-winner ticket set is re-captured on **every new fill** while
armed (`ReSnapshotIfArmed`, called from `OnTradeTransaction` on every
`DEAL_ENTRY_IN`) — not just once at arm time. This closes the gap where a
new fill mid-epoch (e.g. from a refill firing while the wall is armed) would
otherwise never get tracked, protected, or included in the eventual cleanup.

### 5.5 Cleanup trigger — the "Big A/B fix"
Any position close (`DEAL_ENTRY_OUT`), regardless of brick combination, is
treated as a cleanup trigger — **unless** an armed SL wall is still
mid-sequence and expects more closes (some armed winners haven't closed
yet). This directly fixes the old bug where Style A/B had *no* cleanup
trigger at all after an SL hit. Concretely, in `OnTradeTransaction`:

```
on DEAL_ENTRY_OUT (position closed), not already cleaning up:
   if SL brick enabled:
      recompute safe level for remaining armed winners
      if all armed winners now closed -> start cleanup
      else if wall still armed        -> wait for the rest
   otherwise (SL disabled, nothing armed, or an unexpected/manual close)
      -> start cleanup immediately
```

---

## 6. SAFETY NET (`Utils/SafetyNet.mqh`)

Universal broker-fault / risk response, callable from any engine (never an
engine calling another engine — only Utils-level). Triggers:

- A trade-modifying call (`ClosePosition`, `DeleteOrder`, `PlaceBuyStop`,
  `PlaceSellStop`, `ModifyPositionSL`) exhausts its retries
  (`InpSafetyRetryAttempts` = 3 attempts, `InpSafetyRetryDelayMs` = 200ms
  apart, by default).
- A gap fault is detected (price skipped a level without a fill) — treated
  as the same broker/stream-reliability symptom as a failed trade call.
- **An SL modification specifically failing** gets the same nuclear
  response as any other exhausted trade call, not a lighter cleanup — a
  position we can't protect is treated as a real risk regardless of what
  triggered the failure.
- The dashboard's Emergency Close button (manual).

Response is always identical: close every position (zigzag profit order),
delete every pending order (proximity order — closest to price first),
reset all cycle state, alert via Telegram + `Alert()` + debug log. The next
candle-open check rebuilds the grid automatically — no per-brick branching
needed anywhere in the safety-net path.

### 6.1 Telegram
`Utils/TelegramUtils.mqh` — adapted from the CandleMultiOrder EA's utility.
`botToken` and `group_id` are **hardcoded constants** in that file (not
input fields, per instruction) — **you must fill these in before use**.
MT5 also requires `https://api.telegram.org` to be whitelisted under
Tools -> Options -> Expert Advisors -> "Allow WebRequest for listed URL" — a
one-time manual step the EA cannot do for itself.

---

## 7. CLEANUP (BRICK 7)

`InpCleanupMode` controls what happens once the SL system (or safety net)
triggers a cleanup:

- **`CLEANUP_CLOSE_ALL`**: delete all pending orders immediately, then close
  every remaining position one at a time (zigzag profit order), then a full
  state reset — `gridPlaced = false`, next candle-open rebuilds.
- **`CLEANUP_CLOSE_POSITIONS`**: leave pending orders in place, close every
  remaining position one at a time (zigzag order), then `cycleActive =
  false` and (if either refill brick is on) `refillNeeded = true` so the
  coordinator tops the grid back up on the next confirmation.

Both modes close exactly one position per `OnTradeTransaction` confirmation
— never a batch-close in a single call — so the sequence is always
observable and interruptible by (in principle) a later safety-net trigger.

---

## 8. PRIORITY & SEQUENCING RULES

1. **Closing always outranks opening/modifying.** While
   `cleanupInProgress`, every other brick (build, refill, shift, recenter,
   SL trail/arm) is skipped for that tick. This is enforced by an early
   return at the top of both `OnTick` and `OnTradeTransaction`.
2. **Inside-gap refill outranks outside-range refill.** Enforced inside
   `FillOneSide()` — the inside check runs first, unconditionally, before
   the outside check is even evaluated.
3. **Build / refill order**: starting from the price side, working
   outward, in BUY/SELL pairs. This applies to the initial build
   (`BuildGrid`) and is preserved as-is for refill (`FillOneSide` runs
   fully on one side then the other — kept exactly as the original
   implementation, per explicit instruction not to restructure this).
4. **Pending order deletion order** (used by the safety net): closest to
   current price first, moving outward — deleting a pending order carries
   no market-exposure risk, so strict pairing isn't required the way it is
   for building.
5. **Position closing order** (used everywhere positions are closed —
   normal cleanup, safety net, and manual emergency close alike): zigzag by
   profit — most positive, most negative, next most positive, next most
   negative, alternating, until every required position is closed. Ties
   (identical profit) break by ticket order.

---

## 9. INPUT PARAMETER REFERENCE

See `Inputs.mqh` for the authoritative, commented list. Summary by group:

- **Grid Settings**: `InpInitialGap`, `InpGridSpacing`.
- **Grid level counts** (consolidated — replaces the old single
  `InpGridLevels`): `InpInitialGridLevels` (fresh build), `InpMinGridLevels`
  (refill-outside trigger), `InpMaxGridLevels` (refill-outside target).
- **Initial sizing**: `InpInitialSizing`, `InpInitialLotStep`,
  `InpInitialLotCap`, `InpFixedLot` (also used by refill, regardless of
  `InpInitialSizing` — refill always places at `InpFixedLot`).
- **Brick 1**: `InpEnableLotIncrease`, `InpLotIncreaseMode`.
- **Brick 2**: `InpEnableShifting`, `InpShiftAnchor`.
- **Brick 3**: `InpEnableRecentering`, `InpThresholdFactor`.
- **Brick 4**: `InpEnableRefillInside`.
- **Brick 5**: `InpEnableRefillOutside`.
- **Brick 6**: `InpEnableSL`, `InpSLMode`, `InpSLNBack`.
- **Brick 7**: `InpCleanupMode`.
- **Margin**: `InpMinAllowedMargin`.
- **Time filter**: `UseTimeFilter`, `EnableLondon`, `EnableNewYork`,
  `EnableAsia`, `ExtraWindow1`, `ExtraWindow2`.
- **Commission**: `InpCommissionPerLot` (feeds the SL net-PnL safety test).
- **Magic number**: `InpMagicNumber` (0 = auto-generate from symbol +
  timeframe).
- **Safety-net retry policy**: `InpSafetyRetryAttempts` (default 3),
  `InpSafetyRetryDelayMs` (default 200).
- **Telegram**: `InpEnableTelegramAlerts` (credentials are hardcoded in
  `Utils/TelegramUtils.mqh`, not inputs).
- **Dashboard / Timer / Logging**: unchanged from prior versions.

---

## 10. FILE STRUCTURE

```
HedgeGrid.mq5                  Coordinator - OnInit/OnTick/OnTradeTransaction/
                                OnTimer/OnChartEvent. The only file allowed to
                                orchestrate multiple engines together.
Inputs.mqh                     All input parameters and enums (single source
                                of truth).
Models/
  GridState.mqh                Shared state struct + ResetGridState().
Utils/                         Stateless or shared helpers. Any engine may
                                depend on Utils/. Utils/ never depends on
                                Engines/.
  MathUtils.mqh                 Price/lot/margin math, magic number gen.
  TradeUtils.mqh                Order placement/close/delete/modify with
                                 retry + widening.
  CloseOrderUtils.mqh           Zigzag position order, proximity order
                                 helpers (Section 8, rules 4/5).
  SafetyNet.mqh                 TriggerSafetyStop - universal fault response.
  TelegramUtils.mqh             Telegram routing/sending.
  SessionFilter.mqh             Trading-session time filter.
  BarUtils.mqh                  Shared new-candle detection (IsNewBar).
  SizingUtils.mqh                Initial-build lot sizing (fixed/ladder) -
                                 lives here, not Engines/, because three
                                 different engines depend on it.
  DebugLogger.mqh               Experts-tab logging.
  HistoryLogger.mqh             CSV history logging.
Engines/                       Each engine owns exactly one brick's logic.
                                No engine includes another engine.
  GridBuilder.mqh                Unified build (all sizing modes) + Bricks
                                 4/5 (refill inside/outside).
  MarginCheck.mqh                Margin validation, lot-mode selection.
  OrderMonitor.mqh               Fill processing, farthest-hit tracking,
                                 gap-fault detection.
  GridUpdater.mqh                 Brick 1 (lot increase on hit).
  ShiftingEngine.mqh              Brick 2 (shift on gap).
  Recentering.mqh                 Brick 3 (recenter fresh grid).
  SLManager.mqh                   Brick 6 (SL arm/snapshot/trail).
  CleanupReset.mqh                Brick 7 (cleanup) + emergency close entry
                                 point (delegates to SafetyNet).
Dashboard/
  ChartPanel.mqh                Visual panel + emergency button.
```

`Engines/StatePersistence.mqh` has been **deleted**. It saved/loaded cycle
state for mid-session reconnects, but `LoadState` was never called on
restart even in the prior version, and the new architecture always rebuilds
fresh from whatever positions/orders currently exist — there was nothing
left for it to do. Reacting to input changes on a running chart is handled
natively by MT5 (`OnDeinit` -> `OnInit` on every parameter edit) and needs no
code of ours.

---

## 11. CHANGELOG - BUGS FIXED IN THIS REWRITE

1. **SL-hit detection delay** - the all-armed-winners-closed check now runs
   synchronously inside `OnTradeTransaction` (`RecalcOnWinnerClose`), not
   deferred to the next `OnTick`.
2. **Normal fill vs. SL close misidentification** - `OnTradeTransaction` now
   branches on `trans.deal_entry` (`DEAL_ENTRY_IN` vs. `DEAL_ENTRY_OUT`),
   not `deal_type` alone (which can't distinguish an opening deal from a
   closing one, since both use `DEAL_TYPE_BUY`/`SELL`).
3. **`isDeal` filter too broad** - only `TRADE_TRANSACTION_DEAL_ADD` is
   handled now. `DEAL_UPDATE`/`DEAL_DELETE` (never fire for normal trade
   activity) and `TRADE_TRANSACTION_POSITION` (doesn't carry `deal_entry`,
   needed for fix #2) are dropped.
4. **Style C's armed-flag-during-cleanup race** - resolved by construction:
   once cleanup starts, all armed winners are by definition already closed,
   so there is no remaining winner position left to re-arm mid-cleanup
   (holds as long as `ProcessSLManager` stays gated by
   `!cleanupInProgress`, which it is).
5. **`CalculateSafeGridSL`'s struct-in-function** - `SLPosInfo` is now
   declared at file scope in `SLManager.mqh` (MQL5 forbids local structs).
6. **Per-tick full position-loop recalculation** - replaced with the
   arm-time/on-winner-close heavy recompute + cheap per-tick arithmetic
   trail described in Section 5.3.
7. **Gap-fault price re-read after order may be gone** - `CheckGapFault`
   now returns the expected price via an output parameter, captured before
   the caller does anything else that could deselect or delete the order.
8. **Emergency close leaving state flags dirty** - the universal
   `ExecuteEmergencyClose` -> `TriggerSafetyStop` path always does a full
   `ResetGridState` (preserving only the magic number), so no stale flag
   can survive an emergency close.
9. **The "Big A/B" bug - no cleanup trigger at all after SL hit** - fixed
   as described in Section 5.5; every combination now has a well-defined
   cleanup trigger.
10. **Broker-fault handling** - every trade-modifying call now retries
    `InpSafetyRetryAttempts` times (`InpSafetyRetryDelayMs` apart) before
    being treated as a genuine fault; a genuine fault (including a failed
    SL modification specifically) always routes through the same
    `TriggerSafetyStop` - full close, Telegram alarm, state reset.

---

## 12. KNOWN ASSUMPTIONS FLAGGED FOR CONFIRMATION

Two design decisions were made without an explicit instruction covering
them, documented here rather than silently buried in code:

1. **Initial grid sizing is now its own toggle** (`InpInitialSizing`:
   `SIZING_FIXED` / `SIZING_LADDER`). The original 11 brick items covered
   lot changes *after* a hit (Brick 1) but never explicitly separated out
   the *initial* lot-sizing mode (ladder vs. fixed) that used to be tied to
   Style A vs. B/C. Since a grid can't be built without deciding this, it
   was added as an inferred 8th toggle, independent of Brick 1.
2. **SL arm trigger is unconditional "profit > 0"** - the old
   `InpSLTriggerByLot` / `InpSLTriggerByProfit` toggles were dropped per
   instruction with no replacement trigger specified. "Leading side's
   basket profit > 0" was chosen as the simplest sole trigger. Flag if you
   want this gated further (e.g. a minimum profit threshold input).

---

## 13. EDGE CASE HANDLING

- **Broker gap/skip fault**: detected in `CheckGapFault`, routes straight
  to `TriggerSafetyStop` (Section 6) - full close, Telegram alarm.
- **Insufficient margin at build time**: `CheckMargin` falls back to a half
  ladder, or blocks the build entirely below `InpMinAllowedMargin`,
  re-checked every `OnTimer` tick.
- **EA restart mid-cycle**: no special handling needed - the coordinator
  reads whatever positions/orders currently exist; if a grid already
  exists, it's left alone; if not, the next candle-open builds one. See
  Section 10 for why `StatePersistence` was removed rather than kept.
- **Rapid direction switches**: handled by the pass counter (Section 2),
  feeding Brick 1 mode A only.
- **Manual position close by the user** (outside the EA): treated exactly
  like any other close - see Section 5.5, the "Big A/B fix" - triggers
  cleanup like any other close event.

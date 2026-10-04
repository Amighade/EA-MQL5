# Rev30.04 — review, simplification and two-way simulation

This package supersedes the first issued Rev30.04. The earlier READY FOR STRATEGY verdict was too strong: the second review found genuine lifecycle defects, and native MT5 validation is still unavailable.

## Structure

- No new active EA functions or state machines were added. The simulation fixes add two necessary TradeItem result identifiers for exact CLOSE execution evidence; no GridState members were added.
- Removed the separate `FindMatchingLiveOrder()` fallback and duplicate matching loops.
- Reused `RebuildTradeBookFromTerminal()` as the single incremental broker-data merge. Its bool result prevents acting on a failed/incomplete scan.
- Reduced cleanup to routing existing commands and checking completion. It no longer has its own broker-adoption implementation.
- Reconciliation has one pass of command completion checks instead of duplicated broker-field copying for several statuses.
- Scheduler uses one exit path and routes cleanup before sending.
- Removed unused transaction fields and unused profiler entries. Added a source reading order and replaced the obsolete action-flow reference.

## Correctness

- Request-result deal IDs no longer suppress the actual DEAL handler.
- Only PLACE results bind an order ticket; CLOSE results cannot overwrite the opening-order identity.
- Live partial orders and their positions remain separate; final fills and exact late request results merge stale source plans without duplicating positions or commands.
- Submitted commands are never unlocked by elapsed time alone. Unknown outcomes stay locked and keep cleanup from falsely completing.
- A broker order still being registered is not treated as a confirmed PLACE. A filled order awaiting position visibility remains unresolved unless closed position history proves flatness.
- SL confirmation requires a successful result and matching live price. CLOSE continuation requires a finished execution order, accounted-for closing deals and matching live volume, including when entry fills offset the close.
- A replacement requires terminal non-fill history (canceled/expired/rejected); a full fill cancels the obsolete replacement. Canceling a partially filled remainder preserves the requested replacement. Replacement initialization clears stale request/reconcile fields.
- Stable and failed items are checked against broker reality. Failed live objects still count as exposure. New broker objects are recovered outside cleanup too.
- All request setters retain the waiting-state guard; cleanup cannot receive new PLACE/REPLACE/MODIFY_SL work through those setters.
- Cleanup enforces its existing in-flight batch setting and delays retries. Reverse action traversal avoids skipping adjacent items removed during processing.
- Capture only REQUEST fields for REQUEST callbacks; do not read unrelated callback structures as though they were valid request facts.
- Preserve paused/shutdown mode on cycle reset. Reject incompatible account modes and invalid scheduler settings explicitly.

## Two-way simulation corrections

- Fixed CLOSE waiting forever when an overlapping entry fill leaves volume unchanged or greater after a successful close. Kept completion proof in the existing reconciliation function.
- Removed price-based matching of unconfirmed PLACE requests to broker objects. Exact request-result tickets merge recovered objects without overwriting their commands.
- Extended absent-order confirmation to stable orders and DELETE, not only PLACE. Final order history and complete fill accounting prevent cleanup through an order-to-position visibility gap.
- Kept two result identifiers on the item because broker replies can expose an execution order, a deal, or both. They are cleared on each new request and never replace the opening-order identity or the last consumed DEAL marker.
- Added independent simulated broker execution, split order/position snapshots, delayed history/results, callback loss/duplication, disconnections and authoritative cleanup checks. Tests are excluded from the EA include graph.

## Preserved

15/50/250/60000 ms timing defaults; one shared cooperative budget; asynchronous requests; tiny callback; empty strategy hooks; exact SL/TP request prices; unchanged grid/lot/widening parameters; dormant bar/shifting/recentering behavior; CPU-safe logging defaults. `Reference_Rev22_2/` is unchanged byte-for-byte.

## Validation

27 lifecycle groups, 8 focused race groups and 2,000 randomized broker runs pass, including all six REQUEST/ORDER/DEAL permutations. All 13 active source files are consumed by the harness. Include checks and a C++ compilation of syntax-adapted function bodies pass. Bounds assertions and undefined-behavior instrumentation pass; C++ enum-range checks are disabled because MQL intentionally casts WRONG_VALUE. Address/leak sanitizer verification could not complete in this restricted runtime.

No native MetaEditor compilation, EX5 generation or real MT5 broker execution was possible. See the audit for the exact remaining gate. This source review does not claim universal broker behavior or guaranteed resolution after permanently lost broker evidence.

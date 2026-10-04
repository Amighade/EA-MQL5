# Rev30.04 infrastructure review — 2026-09-26

Scope: the 13 active source files reachable from `HedgeGrid.mq5`. The prior issued Rev30.04 was reviewed as source, not trusted as an already-proven baseline. The reviewed package retains Rev30.04 and supersedes that issue. No strategy code is enabled.

## Invariants and evidence

| # | Requirement | Current behavior / evidence |
|---|---|---|
| 1 | Consistent transaction consume/retry | Every handler returns consumed/irrelevant or facts-not-ready. Queue retries only on a later frame; cap and exhaustion tested. |
| 2 | Exhaustion must not trigger cleanup | Only requests broker recovery; no ticket/deal identity is invented from an unhandled fact. Tested. |
| 3 | Broker data must not create strategy actions | Single merge starts new objects at NONE/IDLE and preserves existing commands. Snapshot adoption tested. |
| 4 | Preserve valid commands through sync | Broker merge writes broker fields, not commands. DELETE retains its source-order item when a position exists. Partial-fill SL preservation tested. |
| 5 | No waiting-action overwrite | All setters reject WAIT_RESULT/WAIT_CONFIRM before mutating command fields; replacement reuses the DELETE guard. Both states tested. |
| 6 | No duplicate submission for an item | READY-only send, request state stored immediately, no timeout unlock, cleanup batch limit. Lost/late result tests. |
| 7 | Remove stable absent objects | Reverse iteration removes stale positions. Absent orders use final history and resolve any fill before removal. Tested outside cleanup. |
| 8 | Reconcile flag cannot become a separate deadlock | Flag never bypasses completion checks. Evidence clears it. A genuinely unknown broker outcome stays locked deliberately. Recovery and timeout cases tested. |
| 9 | Event ordering and identity | Exact result-ticket correlation; six REQUEST/ORDER/DEAL permutations; partial/full fills; late results/history; ticket changes; same-price collision regression. Same live position is not duplicated. |
| 10 | Cleanup finds late objects | Uses the same periodic broker merge as normal running; routes after reconciliation and before send. Tested with late positions. |
| 11 | Cleanup requires broker zero/zero | Requires connected terminal, empty book (including unknown requests or unresolved order history), zero owned positions and zero pending orders. Filled-but-not-yet-visible position gap tested. |
| 12 | Stale local item cannot block cleanup indefinitely | Ordinary absent/failed items are removed; only genuinely unresolved broker requests/history wait. Stable and failed disappearance tests. |
| 13 | DELETE/CLOSE already gone | Resolve without a new request. Every absent order checks its terminal outcome and any unobserved fill; replacement additionally requires canceled/expired/rejected status. Adjacent removals tested. |
| 14 | Acceptance is not final completion | Accepted result waits for actual target evidence. Submitted SL also needs a successful result. CLOSE continuation needs its final execution order, accounted-for closing deals and matching live volume; concurrent entry fills are covered. Tested. |
| 15 | Async-only active trade calls | One active OrderSendAsync call; no active OrderSend/CTrade calls. Static include graph checked. Old reference code is excluded. |
| 16 | No new-bar gate | No active bar gate or OnTick strategy entry was added. |
| 17 | No shifting/recentering | Neither engine is included in active source. |
| 18 | Preserve strategy parameters and price math | Grid/lot/widening settings unchanged; SL/TP requests use exact caller values. No strategy calculations added. Old reference tree checked byte-for-byte. |
| 19 | CPU-safe diagnostics | Dashboard/debug/history/profiler defaults off; no active dashboard/history/Telegram work. Profiling returns immediately when disabled. |
| 20 | Compile/member/include consistency | Includes resolve; all 13 files compiled as syntax-adapted C++ function bodies; no new active function names. Two necessary TradeItem result identifiers retain CLOSE execution evidence; no GridState fields or state machines added. **Native MetaEditor compilation remains unperformed.** |

## Validation performed

- 27 lifecycle groups, 8 focused race groups and 2,000 seeded broker runs pass. See `SIMULATION_REV30_04.md` for model assumptions, reproducible commands, counts and defects fixed.
- Checked C++ build uses bounds assertions and undefined-behavior instrumentation, with enum-range instrumentation disabled for MQL's intentional WRONG_VALUE casts.
- Address/leak sanitizer did not complete under restricted process access and is not counted as verified.
- Source include closure, asynchronous trade-call boundary, unchanged strategy defaults, dormant strategy hooks and reference preservation were checked.
- The packaged ZIP is checked for integrity; active source hashes are included in the manifest.

These tests validate the exercised control flow. They do not execute the MT5 runtime, establish performance on a live account or prove every possible broker behavior.

## Explicit operating limits

- One EA owner per symbol/magic pair; ownership means this symbol and magic, not every position in the account.
- Retail hedging without FIFO close rules. Incompatible accounts fail initialization; netting reversals are not silently treated as hedging.
- PLACE supports limit and stop orders; stop-limit placement is rejected because its second price is not part of the current request interface. Existing stop-limit orders can be discovered/deleted.
- Permanently lost broker evidence cannot be turned into both guaranteed progress and guaranteed no duplicate submission. The safe behavior is to keep that request locked and cleanup unfinished. The EA does not infer failure from elapsed time.
- No durable request-state persistence or historical strategy-event replay across restarts. The broker book is rebuilt on startup. Do not restart with an unresolved request and assume its hidden request state has survived.
- The frame budget is cooperative between bounded work stages and submissions; it cannot interrupt a broker API call or guarantee a hard deadline on an arbitrarily large account.

## Remaining native gate

Compile `HedgeGrid.mq5` in MetaEditor with the package include tree. Resolve any native compiler diagnostics before adding strategy. On a compatible MT5 demo/test environment, exercise placement/fill, partial execution if supported, SL confirmation, cancellation/replacement, cleanup during late fills, rejection, disconnection/reconnection, and zero/zero completion. Inspect both terminal state and the item book; the simulation is not a substitute for this gate.

**NOT READY — native MetaEditor compilation and MT5 lifecycle verification remain outstanding.**

## Primary platform references used

- [OnTradeTransaction](https://www.mql5.com/en/docs/event_handlers/ontradetransaction): transaction arrival order and callback-field validity.
- [OrderSendAsync](https://www.mql5.com/en/docs/trading/ordersendasync): submission versus server outcome.
- [Position properties](https://www.mql5.com/en/docs/constants/tradingconstants/positionproperties): stable position identifier versus current ticket.
- [Order properties](https://www.mql5.com/en/docs/constants/tradingconstants/orderproperties): pending types, registration, terminal states and partial execution.
- [Trade return codes](https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes): accepted, partial and failed request results.

- [Trade request results](https://www.mql5.com/en/docs/constants/structures/mqltraderesult): preserve available order/deal identifiers independently of consumed DEAL events.
- [HistorySelectByPosition](https://www.mql5.com/en/docs/trading/historyselectbyposition): collect the position's order/deal history for execution confirmation.

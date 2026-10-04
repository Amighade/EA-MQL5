# Rev30.04 — EA/broker two-way simulation

Historical Rev30.04 infrastructure simulation. Rev31.00 integration results are in `SIMULATION_REV31_00.md`.

Date: 2026-09-26. Scope: infrastructure only. All strategy hooks remain empty.

**Result:** 27 lifecycle groups, 8 focused race groups and 2,000 reproducible randomized broker trials pass on the final source. No invariant failures or sanitizer diagnostics were reported in that run. This does not prove all possible broker situations and does not replace native MetaEditor/MT5 verification.

## What was simulated

The EA issues its actual `OrderSendAsync()` request through the mock boundary. A separate broker model executes or rejects it later. Server objects, terminal order snapshots, terminal position snapshots, order history, deal history and callbacks are separate stores/queues. Order and position views advance independently; snapshots within each view do not go backward.

Each trial runs 300 active 15 ms frames with randomized request-setter calls, then explicitly requests cleanup and permits up to 1,600 more frames for convergence. The command driver tests infrastructure; it is not included as EA strategy.

| Disturbance | Modeled behavior |
|---|---|
| Server latency | Execution 1–7 frames after submission |
| Live visibility | Independent order/position views delayed 0–7 frames |
| History latency | Order and deal facts delayed 0–13 frames |
| Request results | Delayed 0–15 frames; CLOSE replies exercise both order IDs and deal-only IDs |
| Other callbacks | Delayed 0–13 frames; 8% dropped; some duplicated |
| Rejection | 15% probability during active phase, 8% during cleanup, plus invalid/stale-target rejections |
| Local send failure | 3% probability per active frame |
| Trade permission | Disabled on 5% of active frames |
| Connectivity | Random outages lasting 10–34 frames; server can continue while terminal delivery waits |
| Pending fills | Full and partial, with subsequent fills of some remainders |
| Position exits | Full/partial requested closes and some manual exits with magic zero |
| Ownership | Foreign order and position remain present throughout each trial |
| Same-price orders | Repeated requests and replacement prices can collide |

Random REQUEST results and required history eventually arrive. Permanently missing evidence is tested separately as a safe lock, not as expected automatic convergence. Rejection rates are probabilities, not guarantees that every request eventually succeeds; the recorded seeds did converge.

## Assertions

- Outgoing symbol, magic, target, volume, requested price and SL/TP payloads match the item command.
- No two requests execute concurrently for the same item or known broker order/position.
- Local IDs, request correlations and broker-ticket mappings stay unique.
- Newly adopted broker objects begin without an invented strategy command.
- Waiting-state request setters preserve existing commands.
- Reconciliation and late exact placement results preserve live DELETE/CLOSE/MODIFY intent.
- Cleanup sends liquidation requests only and does not finish while authoritative server exposure or an outstanding PLACE exists.
- With the modeled bounded responses, cleanup converges to zero owned positions and zero owned pending orders.
- Other owners are untouched; disconnected snapshots cannot complete cleanup.

## Final randomized run

Seeds **1 through 2000**, all completed:

| Measure | Count |
|---|---:|
| Simulated frames | 842,414 |
| Request submission attempts | 422,586 |
| Broker request executions, including rejection decisions | 411,174 |
| Broker rejections | 67,392 |
| Local send failures | 11,412 |
| Entry executions | 76,757 |
| Partial entries | 25,963 |
| Exit executions | 85,035 |
| Partial requested closes | 17,440 |
| Delivered callbacks | 911,226 |
| Dropped non-REQUEST notifications | 40,348 |
| Disconnections | 5,071 |

`Validation/results.txt` contains the exact program output. Commands to reproduce it are in `Validation/README.md`. Compilation uses the current 13-file include graph, bounds assertions and undefined-behavior instrumentation; C++ enum-range checks are disabled for MQL's intentional enum casts.

## Defects reproduced and corrected

1. **CLOSE could remain stuck after successful execution.** An overlapping entry fill can offset the closed volume, so `DONE_PARTIAL` plus a smaller volume was insufficient. The existing reconciliation function now verifies the exact execution order is final and no longer live, accounts for its closing deals, and compares history with the live remainder before rearming CLOSE. Tests include DONE, DONE_PARTIAL, PLACED, deal-only results, delayed deal history and a still-live partial execution order.
2. **Price matching could confirm the wrong PLACE.** A same-price broker object could bind an unrelated still-executing request, allowing another command on that item. The broker scan no longer binds unconfirmed plans by price. Exact request-result order tickets merge already adopted objects and preserve their commands. Local duplicate-price suppression remains a request policy, not broker identity.
3. **Stable orders and DELETE could finish cleanup through a fill-visibility gap.** The existing absent-order function now resolves final history for every disappearing order. Filled exposure must either be tracked live or fully accounted for as closed. Accounting checks the order's executed entry volume, so old flat history cannot conceal a newly filled remainder. Canceled partial remainders and delayed replacement confirmation are covered.

All changes are in existing EA functions. No new EA function, manager, state machine, strategy, timer tier or parallel broker book was added. Two necessary TradeItem fields retain the result's order/deal identifiers for CLOSE evidence; they do not change the opening-order ID or consumed-DEAL marker. Inputs, scheduler, cleanup routing and the historical strategy reference are unchanged. Active source remains 2241 lines, compared with 2960 before the earlier simplification; the simulation fixes add 75 lines to the previous reviewed source.

## Limits and verdict

- Native MetaEditor compilation and an MT5 demo/tester lifecycle run were unavailable. C++ adaptation cannot prove MQL compilation or exact terminal behavior.
- The simulated delays, independent snapshots and failure patterns are a finite model. Real broker execution policies, exchange corrections, session rules, price/volume validity and account-specific behavior require native checks.
- There is no durable persistence of unresolved requests across restart, and no complete historical strategy-event replay. The simulation does not claim exactly-once future strategy hooks.
- Missing request identity or permanently unavailable history stays unresolved deliberately. A timeout does not authorize a duplicate order or prove flatness. Such a case requires terminal/broker investigation; automatic progress is not promised.
- The frame budget is cooperative. Synthetic frames are not a measurement of real terminal CPU or hard latency.

**NOT READY — native MetaEditor compilation and MT5 lifecycle verification remain outstanding.**

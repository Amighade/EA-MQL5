# Rev31.00 strategy integration simulation

## Scope

The simulation recompiles the active EA function bodies after adapting include, input and dynamic-array syntax for a C++ terminal mock. It tests the Rev30.04 transaction/reconciliation path together with the active Rev22.2 strategy modules. It does not compile MQL5 or contact MetaTrader.

## Results

- Harness translated all 16 files in the active EA include graph.
- 27 lifecycle scenario groups passed, including six REQUEST/ORDER/DEAL arrival permutations, one-outstanding-action guards, delayed broker facts and cleanup.
- 8 focused race groups passed, including same-price non-identity, late exact request results, partial close evidence, and partial-fill replacement behavior.
- 4 strategy scenario groups passed. They confirmed initial two-sided grid intents and async submission; a partial initial grid enters cycle cleanup while still in `GRID_BUILDING`, retries a rejected cancel, waits for accepted cancels and broker zero/zero, then plans a fresh complete grid; a nearest-grid SL still checks basket net profit; and a full position exit starts cleanup after the position item disappears from the broker scan.
- 2,000 randomized independent-broker timelines completed: 742,162 frames, 268,873 submissions, 258,415 executions, 43,769 broker rejections, 10,458 local send failures, 47,974 entries, 16,155 partial entries, 54,186 exits, 11,153 partial closes, 570,093 callbacks, 25,359 dropped callback facts and 5,003 disconnects.
- All C++ test builds used `-Wall -Wextra` and undefined-behavior instrumentation (`-fsanitize=undefined -fno-sanitize=enum`); no compiler or sanitizer diagnostics were reported.

## Identity and unresolved results

A pending request is not joined to a live order by price. The matching rule remains the exact `result.order` ticket from the request callback. A position recovered before that callback stays a separate broker item until the exact result arrives; then the request's level/lot metadata is copied to the matching live object. In a partial fill, both the remaining order and the position retain the same source level.

For a missing request result, a same-price live order cannot safely be distinguished from an unrelated order. The EA keeps the original PLACE locked and separately reconciles the live object. Cleanup will not declare completion while the unresolved command remains. This avoids resending a possibly accepted PLACE, at the cost of requiring broker evidence before the cycle can finish.

## Limits

The tests cover only modeled terminal API behavior. They do not verify every MQL5 compiler rule, broker-specific filling/stops behavior, terminal restart recovery, account-specific timing, or all combinations of optional Rev22.2 settings. A native MetaEditor compile and MT5 demo/tester run remain necessary. The 2,000 stress trials exercise broker infrastructure with strategy automation paused; focused strategy tests exercise initial grid creation, asynchronous submission, partial-grid cleanup/retry, SL and position exit.

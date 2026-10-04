# Rev14.03.01 — optional diagnostics

Based on Rev14.03.00. Trading decisions, synchronous requests, retries, grid geometry, lots, SL calculations, cleanup and rebuilding remain unchanged. The existing time gauge and Ctrl+Shift+Q emergency shortcut remain unchanged.

Compile HedgeGrid.mq5 in MetaEditor before running. No compiled EX5 is included.

## Enable the new log

Set `InpEnableFailureDiagnostics = true`. Its default is false. It works independently of `InpEnableTimeGauge` and the dashboard/debug/history inputs.

Diagnostics appear in the Experts log:

- `[DIAG TRADE]`: exact request, returned bool, retcode, broker comment, terminal error, returned order/deal tickets, duration, quote before sending, stop/freeze constraints, widening/retry context and original/adjusted SL values.
- `[DIAG VERIFY]`: failed level, expected prices/lot, existing verifier result and actual live orders.
- `[DIAG SAFETY]`: trigger reason and EA position/order counts before closing/deleting and after those calls, before the existing reset.
- `[DIAG BUILD]`: existing flags and last safety-stop reason when the original code permits building.
- `[DIAG HISTORY]`: history/aggregate read failures and the existing retry number.
- `[DIAG EMERGENCY]`: emergency-close execution started/returned.
- `[DIAG OBJECTS]`, `[DIAG OBJECT PREFIX]`, `[DIAG OBJECT TYPE]`: one-time inventory of open charts. It reads at most 32 objects per timer pass, subject to the remaining cooperative frame budget and a 1 ms inventory allowance. It never changes/deletes chart objects.

First occurrences and new reason/ticket groups print immediately. Additional occurrences in the same group are summarized every 10 seconds by `[DIAG REPEAT]`; `count` is the number suppressed after the prior print. The latest detail is retained. Remaining repeats flush on removal. Routine timer passes stay silent.

Trade snapshots use a fixed 128-record buffer and repeat groups use 128 slots. Snapshot overflow is reported explicitly. Object prefixes are limited to 32 groups, with remaining prefixes counted together. Inventory is incremental, so changes to chart objects during the scan can affect its counts.

These are observations, not fixes. An accepted trade result is a request result, not a new live-state confirmation mechanism. Quotes are captured before the send, not when the broker processes it. The object inventory describes existing objects; it does not identify which program created them. One synchronous API call can still exceed a cooperative time budget.

Keep both Experts and Journal logs from the same run for diagnosis.

## Verification

- Reversing the diagnostic additions and revision label restores all Rev14.03.00 source files byte-for-byte; local include paths resolve.
- A C++ mock harness exercised the actual diagnostic send/grouping code: disabled forwarding, exactly one native send per call, preserved success/failure, captured error/result/quote, repeat suppression and 10-second summaries.
- The mock checks are not an MQL5 compile or an MT5 runtime test. Native MetaEditor/MT5 validation was unavailable here.

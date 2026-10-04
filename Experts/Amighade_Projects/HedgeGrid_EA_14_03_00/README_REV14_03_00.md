# Rev14_03_00 — requested additions only

Based on the uploaded HedgeGrid_EA_14.02_2(2).zip.

## Emergency-close shortcut

Click this EA's chart to give it keyboard focus, then press Ctrl+Shift+Q.
The shortcut queues the existing emergency-close command for the next timer pass.
It works when InpShowDashboard is false. Holding Q does not repeatedly queue it;
release Q before pressing the combination again.
The existing emergency-close implementation and trade behavior are unchanged.

## Optional elapsed-time gauge

Set InpEnableTimeGauge=true to enable measurements and Experts-log reports.
Default: false. When disabled, no diagnostic clocks, accumulation or reports run.
Every 10 seconds, called tasks report Last, Max10s, MaxAll, Avg10s and Calls.
All durations are milliseconds (three decimal places).
MaxAll is retained until EA reinitialization; interval totals reset after reporting.
These are elapsed times including broker/network waiting, not CPU utilization.
Nested timings overlap. Do not add a function's time to its child-call times.
A report can be delayed while a synchronous request blocks the EA.
The gauge measures time; it does not impose new time limits.

Instrumentation pattern: one CTimeGaugeScope line at function entry.
Its destructor records duration at function exit, including early returns.
The diagnostic OrderSend wrapper preserves the original synchronous call/result.
Coverage: scheduler/queue tasks; aggregate updates and fills; grid build,
verification and refills; lot updates; SL calculation, snapshot and application;
cleanup/emergency close; trade requests/retries; broker-count/order-sorting scans;
margin/session checks; dashboard, history logging, persistence and Telegram.
OnTradeTransaction remains unchanged.

## Check of the latest edits against the conversation

The active deal-ticket aggregate function and both checked caller paths match the
supplied code. The old UpdateSideVolumeAggregate_old function and unused openLot,
openPrice and closeLot locals remain; they were not removed. No broader review
or changes to those edits were performed.

## Build and scope

Compile HedgeGrid.mq5 in MetaEditor. This ZIP intentionally excludes the uploaded
old HedgeGrid.ex5, which would not contain the additions. A native MetaEditor
compile and an MT5 keyboard/demo test were not available in this environment.
The MQL5 property version is 14.030; the package revision is 14_03_00.
Local include checks passed. Removing only the authorized additions restores
all original source bytes exactly. Other uploaded files are unchanged.

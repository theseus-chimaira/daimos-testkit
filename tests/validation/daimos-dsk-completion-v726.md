# v726 — Disk completion snapshot in the stalled scheduler workload

Using a private copy of the CLEAN v710 PDP-6 D6FS disk image, the
native test reaches INIT, breaks at `proc_wait_event` (`013235`), and
then at idle (`014102`). The slot-1 disk-request event at `034745`
remains zero at idle. `storage_state` (`020553`) is
`777777777775` (signed -3), consistent with an outstanding transfer.
The clock tick counter (`020632`) was octal `011` at this early snapshot.

The code path for completion is `dsk_pi_idle` -> mark request event ->
`proc_wakeup_event`. The error path `dsk_fail_runtime` also marks the
event and wakes the waiter. The five-second driver watchdog is connected
through `minit_export(..., DSK_X_WATCHDOG)` to the fixed KCORE
`storage_clock_dsk_jump` patch site, reached by `storage_clock_tick`.
That binding exists in source; a working runtime binding and timer
expiration have **not** yet been demonstrated by this test.

No assertion about missing PI completion can be made from the early idle
snapshot. Next capture the active-request pointer/countdown in the relocated
DSK MRES, and sample it across 300 clock ticks, alongside the PI5 completion
path and the KCORE watchdog binding. The full scheduler-pressure test
remains blocked; no kernel changes made.

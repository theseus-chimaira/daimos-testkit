# v717–v719: idle-to-user scheduler selection

All diagnostics execute with private copies of the v710 CLEAN PDP-6
256K D6FS media. None establishes full scheduler-pressure acceptance.

- v717: after breaking at the real idle loop `014102`, a subsequent
  breakpoint fires at `proc_sched_tick_select` (`007750`). PI6 is not
  merely running a timer without reaching process selection.
- v718: stepping 180 instructions after selection enters returns to
  `014102` (`MOVE 1,20614`). `proc_current_slot` remains zero, so this
  selection attempt did not restore a user process.
- v719: the same step test records `proc_runq_head` (`020621`) as zero,
  `proc_high_slot` (`020610`) as octal 2, `proc_sched_cursor` (`020614`)
  as octal 1, and `proc_timer_next` (`020501`) as zero. The run-queue
  head is empty at the capture point even though process slots exist.
  This narrows the failure to process-state/run-queue publication or a
  legitimate sleep/wait state not being woken; the snapshot alone cannot
  decide which. Do not patch selection based solely on this trace.

Next: trace slot-1 creation, state transitions, RUN-queue attach/detach,
and the test INIT's first blocking syscall. Establish that a runnable
process is actually expected before assigning a kernel defect.

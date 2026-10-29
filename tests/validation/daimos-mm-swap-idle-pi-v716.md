# v714–v716: scheduler idle versus swap-victim diagnosis

All tests use an isolated copy of a CLEAN v710 PDP-6 256K D6FS image.
The prior v712/v713 timeouts at `014102` were incorrectly attributed to
`proc_swap_victim` because the latter was the nearest earlier exported
symbol. The actual instruction at `014102` is `MOVE 1,20614`, which
matches `proc_idle_loop: move 1,proc_sched_cursor` in the source; the
linked map places `proc_sched_cursor` at octal `020614`.

- v714: breakpoint `014102` fires following `INIT V1`, with current slot 0,
  scheduler cursor 1, scheduler kick 0 and swap flag clear.
- v715: `proc_sched_pi_tick` entry at `013562` fires during boot; alone this
  does not show clocks continue after idle begins.
- v716: sequential breakpoints establish that `014102` is reached **first**,
  then after resuming execution a `proc_sched_pi_tick` entry at `013562`
  executes. The tick counter was octal `011` (9 decimal) at the second
  breakpoint; cursor remained 1 and current slot 0.

Consequently the system is not hung inside the swap-victim selector, nor
are PI6 ticks completely absent after entering idle. Next investigate the
idle-to-user scheduler selection and restore decisions (especially PI
nesting and whether the pending cursor is runnable). Do not patch victim
selection based on the earlier misattribution. These are breakpoint
diagnostics, **not** full workload acceptance.

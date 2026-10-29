# v713: bounded swap-victim breakpoint diagnostic

Using a private copy of the v710 256K CLEAN D6FS image, the native PDP-6
reached `INIT V1` and ran for the bounded 65-second trace interval. Its
requested breakpoint at `proc_swap_victim` (`013755` in the linked map) did
**not** trigger; timeout (`124`) stopped at octal PC `014102` (`MOVE 1,20614`).
This matches the PC of the first five-minute v712 timeout but is not proof
of entry or of a loop through the nominal function entry.

Observed at termination (all octal): `proc_high_slot` `3`,
`proc_current_slot` `0`, `mm_extent_count` `13`, AC1 `2`, AC12 `40`,
AC13 `0`, AC14 `0`, AC17 `33760`. State was captured *after* the timeout,
not at a breakpoint. Unusual AC values must not be interpreted as
unquestioned `proc_swap_victim` locals without validating the live PC and
instruction ownership. Further targeted instruction-level and loop-entry
tracing is required before changing kernel logic.

The v713 script fails closed when no breakpoint is observed; it retains
isolated media only with `DAIMOS_TRACE_KEEP_V713=1`. This is a diagnostic
failure, **not** full-system scheduler acceptance.

# Native PDP-6 MM bounded-pressure policy v119

Runs the real production `mm_pdp6.s` with instrumented *external* FS and
swap reclaim callbacks. The unsatisfiable allocation returns NOMEM with
exactly two FS callback calls and one swap callback call, does not alter
the output base or descriptor count, and never loops indefinitely.
`mm_alloc_aligned_noreclaim` does not call either reclaim service.

This verifies the native allocator's failure and retry contract, not the
actual process swapping or filesystem reclaim implementation. Native
reclaim success, state rollback, scheduler concurrency and full-system boot
are still open. Run with `DAIMOS_REPO=/path/to/DAIMOS ./run-v119.sh`.

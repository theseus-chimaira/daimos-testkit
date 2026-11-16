# P1-E v1625: original sixth RUN failure stage

Use the unchanged source-built v1624 six-child guest and its complete
48K no-AUX TSFS/PURE image. This replay does not modify DAIMOS kernel,
the executable, installed MRES, PI or MM state. It copies the original
Type-551 root tapes before running SIMH, preserving the originals.

    PURE_RUN_BUILD_V1625=/path/to/v1624/six-child/build \
        sh tests/diagnostics/pure-run-cause-v1625/replay-v1625.sh

The original linked `proc_run.s` symbols, verified against the guest's
actual `kcore.map`, are:

    proc_run_startup_failed 017722
    proc_run_mm_bad         017724
    proc_run_claimed_bad    017725
    proc_run_bad            017727

The physical replay runs the five original children, then breaks at
PC 017725 (`proc_run_claimed_bad`) before the sixth claimed slot is
discarded. AC1 is exactly octal `777777777776`, or -2. Original
`exec_load.s` generates -2 (`EXEC_LOAD_NOMEM`) only when
`vm_space_create` refuses to construct a process VM. This is a
source-linked admission failure, NOT a failure to reach SLEEP,
EXE corruption or process-slot-limit exhaustion. The original
`proc_high_slot` is 010 octal, with `proc_slots` 014 octal.

The output stops before the fifth child's later release and is a
deliberate breakpoint, not a physical end-to-end acceptance guest.
The finer MM reason (insufficient capacity versus fragmentation or
allocation policy) remains UNPROVEN. Inspect live MM arena and
extent geometry before changing allocator code or retry semantics.

The source-backed physical auditor checks exact linked RUN failure
addresses and the unmodified `exec_load.s` and `proc_run.s` control
flow; two test-only mutations (wrong AC1 error and wrong breakpoint
PC) must be rejected:

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_RUN_BUILD_V1625=/path/to/v1624/six-child/build \
    PURE_RUN_TRACE_V1625=/path/to/trace.clean \
        sh tests/diagnostics/pure-run-cause-v1625/run-audit-v1625.sh

No positive RAW reclaim, full parent WAIT, restored mutable-state
ownership or peak/net RAM saving is inferred from this diagnostic.
PURE remains OFF by default; strict 32K optimization stays on HOLD.

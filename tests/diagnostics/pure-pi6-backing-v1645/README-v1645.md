# P1-E v1645: genuine PI6 scheduler progress with five PACKED owners

Date: 2026-11-17. **ACCEPTED** physical source-linked original PDP-6
48K no-AUX/TSFS/PURE guest. This is a daimos-testkit-only C89 guest
and original simulator replay; production KCORE/PURE MRES, MM,
VFS, DTFS, PIPE, scheduler and ABI remain completely unchanged.

## Purpose and controlled guest scheduling

The accepted v1644 guard test proved mutation/unmount refusals
while six sleeping children were PACKED on a writable, mode0777
native DTFS executable at `/MOUNT/COMP` (DTC3/provider5/mount2).
It did not distinguish genuine PI6 scheduling from a sequential
single-process guard test.

This v1645 source-derived test retains v1644's original sixth-
RUN refusal, no-growth BRK, six exact child PID/WAIT/EXIT-057,
private mutable data/PIPE sentinels, native DTFS mode0777,
all actual source mutation/unmount/rename checks, and final
native DTFS unmount. No extra child, privileged syscall,
kernel memory word, process-table field or fake scheduler hook.

The parent first tests backing lifetime while all six children
are still PACKED (first `P`, as in v1644). Then it writes
EXACTLY ONE fixed verified 36-bit token into the shared PIPE
while keeping its writer open (`H`). Each genuine original
child now accepts either that one exact token or the final EOF,
still checks its own writable data and exits with exact 057.
The parent immediately repeats the real original backing
mutation/unmount checks (`P`), then makes a real
`dsys_sleep(0200U)` call. That syscall yields through the
original PI6 scheduler; the one token consumer completes
its checks and exits (`w`) before the parent's `T` marker.
The other FIVE children cannot see EOF because the writer
remains open. The parent repeats all source guards yet again
(`P`) with those five still PACKED, and only then closes
the PIPE writer. All remaining five children run/exit/WAIT,
and the parent finally unmounts the secondary filesystem
(`U`), prints `Z` and HALTs normally.

Complete guest console (line wrapping is editorial):

    aaaaaax[B013470/042501]<010000+010000>
    [A013470/042501]P{013470-013470}LHPwTPwwwwwUZ

## Exact physical findings

The generated DXR2 has original C89 linked TX2 text `001454`
octal words. The original PDP-6 PURE skip is
`(001454+020)&~0177=001400`, so each raw suffix is
`010000-001400=006400` octal words (not v1643's 006600).
The exact original B, A, first-P, post-token and post-T physical
MM tables record source extents, original PI6 clock words and
the currently selected ROOT/secondary mount policy.

| Original physical checkpoint | CLK ticks (decimal) | PACKED owner slots |
| --- | ---: | --- |
| B, six children | 7895 | 2..7 |
| A, six children | 7895 | 2..7 |
| First P, all six protected | 8673 | 2..7 |
| H, one PIPE token sent | 8673 | 2..7 |
| First guard after H | 9098 | 2..7 |
| T, real sleep completed, one w observed | 10364 | 3..7 |
| Second guard after T | 11015 | 3..7 |

The actual original `clk_tick_count` and `proc_timer_clock`
both advance **1691 ticks** between H and T; the former is
incremented only in the qualified real 60Hz clock handler,
not by a software PI6 reschedule request. Between H and
the first post-token P, **425 ticks** already elapsed while
all six original PACKED raw extents remained unpinned.
This is independent, source-linked evidence of real hardware
clock service and process scheduling, not a fabricated tick.

All original source extents remain correct, stable, and
nonoverlapping through the first guard; after T, exactly the
one token consumer's owner has retired. Owners 3..7 still
hold their same untouched, UNPINNED `006400` raw suffixes.
None has a second full APR allocated at the sampled checkpoints.
Original TSFS namespace ROOT always remains provider7/mount1;
native DTC3 is still RW (`vfs_mount_policy=000000000001`).
Original KCORE guards `proc_swap_mount_busy` at PC003431
with AC1=2 and `proc_swap_backing_busy` at PC003322 with
AC1=050202000000 are executed before the staged wake.

Original source audit verifies that an ordinary clock PI6 can
preempt user code but cannot switch a running executive syscall
unless that process explicitly sleeps, and that software PI6
kicks alone do not increment the original CLK hardware counter.
The guest uses such a real sleep while the one awakened child
executes its source-backed recovery. The initial and subsequent
backing guards remain accepted original public syscalls.

Following the final five EOF completions and exact original
WAIT/EXIT checks, native DTFS unmount succeeds. Final U and Z
physical MM samples contain ZERO child PROCESS/PACKED owners
and no child pins; simulator HALTs normally at PC000000.
The source-linked auditor reuses v1644's complete underlying
RW backing/guard oracle and adds strict PI6/timer, single-
token and five-surviving-RAW constraints. Its three negative
controls reject a forged frozen real-clock count, a forged
retained RAW pin, and a forged RO bit on the secondary mount.

The simulator may print its normal `DTC3: writing buffer to
file: ...` flush notification between two guest characters.
The auditor excludes only this simulator diagnostic when
counting actual child `w` output; the original complete MM,
CLK and user outcomes are not changed or hidden.

## Reproduce

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-pi6-backing-v1645/run-v1645.sh

    PURE_PI6_BACKING_BUILD_V1645=/path/to/guest/build \
        sh tests/diagnostics/pure-pi6-backing-v1645/replay-v1645.sh

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_PI6_BACKING_BUILD_V1645=/path/to/guest/build \
    PURE_PI6_BACKING_TRACE_V1645=/path/to/replay/trace.clean \
        sh tests/diagnostics/pure-pi6-backing-v1645/run-audit-v1645.sh

Independent original source safety tests v1086 (PI6/slot0),
v1563 (staged PURE owner), v468 (rename/PI6 mapping contract),
and the original physical v1644 guard test PASS. No production
change and therefore no extra resident KCORE TEXT or RAM.

## Scope

**ACCEPTED:** source-backed partial wake, genuine original PI6
time progression, one restored child with five other stable
PACKED owners, genuine mutation/rename/unmount syscalls both
before and after that wake, all six complete exit/WAIT,
final unmount and no MM leak.

**NOT proved:** the precise instruction-level collision of
DTFS WRITE/UNLINK admission with a *new* PURE EXEC attaching;
the sampled initial guard after H still had six PACKED owners
and no simultaneous full-target allocation. PI6 scheduling
during a sleeping provider operation, uncertain MM rollback,
32K/64K general memory layouts, matched transient peak RAM,
and old standalone DTFS v1522 fixture modernization remain open.
PURE stays OFF by default and strict 32K size optimization HOLD.

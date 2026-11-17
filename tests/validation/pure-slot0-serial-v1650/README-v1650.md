# P1-E v1650: original PDP-6 PI6 serialization of slot-0 FULL service

Date: 2026-11-17. Original-source native PDP-6 test PASS.
Original, previously accepted v1643 48K physical evidence audited PASS.
No production kernel, MM, VFS, scheduler, DTFS or permanent RAM change.

## Result

The slot-0 PURE MRES services a sleeping/runnable PACKED process
through the original `proc_swap_service_one` trampoline.
During its bounded FULL callback, the original PDP-6 scheduler
must not save a slot-0 executive continuation and dispatch a user.
It permits a slot-0 switch only for a saved PI6 PC in
`[proc_idle_loop, proc_idle_loop_end)`, and only if the current
service does not own the swap request (`proc_sched_cursor & 0400`).
The due timer path cannot bypass the interrupted-PC bounds.
Software PI6 rescheduling checks the same bounds and request bit.

The native test extracts the exact original instruction sequence
from `proc_pdp6.s`; only its subsequent selection/fallthrough
continuation is replaced by a counting stub. Importantly, the
production source FALLS THROUGH into `proc_sched_tick_ready`
after testing `proc_sched_cursor`: this exact fallthrough is
preserved in the extracted executable. The fixture counts an
allowed selection but otherwise executes the real guard.

Eleven native cases cover the lower and upper PC boundaries,
the recorded FULL MRES loader PC, due and non-due timer states,
swap-request and non-swap cursors, and allowed idle-loop
dispatches. Three separately assembled guard mutations are
executed and rejected: omitted lower-PC boundary, omitted
upper-PC boundary and bypassed swap-service exclusion.

The independent physical correlation reads the unchanged
v1643 48K simulator trace and original KCORE and PURE MRES
symbol maps. It asserts that the bounded FULL callback at
`035252` octal is outside the idle interval
`017216..017264`. In that SAME original physical checkpoint,
current slot is 0; source owner slot 3 has a pin1 PACKED
RAW suffix `111200..120000` and a separate pin1
PROCESS destination `120000..130000`. Original source code
preserves both pins and the PACKED backing until the bounded
loader and RAW overlay finish. VFS calls the owner scanner
before v1562 DTFS quiescence. The normal failed-read rollback
and final no-leaked-owner stage remain verified.

Two independent manipulated copies of the original trace
(falsely changed FULL current slot; falsely unpinned RAW
source) are rejected by the same physical auditor.

The physical trace is REUSED, not a new simulator run. The
native instruction-level test does NOT execute real interrupt
hardware, and the source review of the software PI6 branch is
not a separate software-PI6 native test. The combined evidence
shows the proposed user UNMOUNT interleaving during a normally
admitted slot-0 FULL MRES callback is prohibited by the original
scheduler; bypassing that exclusion would change the tested
architecture, not expose a naturally reachable race.

## Run

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export DAIMOS_REPO=/path/to/DAIMOS
sh tests/validation/pure-slot0-serial-v1650/run-v1650.sh
export PURE_PHYS_BUILD_V1650=/path/to/original/v1643/build
export PURE_PHYS_TRACE_V1650=/path/to/original/v1643/trace.clean
sh tests/validation/pure-slot0-serial-v1650/check-physical-v1650.sh
```

The full accepted v1643 physical source/DXR/rollback audit
remains a separate requirement; v1650's correlation check
does not replace it. The test outputs and original KCORE maps
are retained in versioned `$TMPDIR` evidence directories.

P1-E remains OPEN for unproven permanently uncertain MM
ownership, complete 32K/48K/64K peak RAM, and the distinct
KA10 VM backend. PURE opt-in/OFF by default and strict 32K
whole-KCORE optimization HOLD.

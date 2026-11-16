# v1616: physical PDP-6 BRK and RAW owner diagnosis

Status: physical diagnostic, NOT production P1-E acceptance.
No kernel image, process structure, MM layout or OOM policy is changed.

The preserved 48K PDP-6 TSFS image uses an actual --pure DXR and
no AUXST1 media. All replays clone the original tape media before
execution. Set PURE_BRK_BUILD_V1615 to the matching build directory.

## Recorded physical experiments

1. run-v1616.sh arms the source-mapped vm_space_brk_current
   entry from the beginning of the run. SIMH confirms the
   execution breakpoint at octal 022104 and stops at the
   initial brk(0) query, with AC1=0 and five PROCESS owners.
   CPU breakpoints from boot are expensive on the simulator.
2. console-stop-v1616.sh instead sets a SIMH console EXPECT
   trigger for the last <010000+020000> marker. It stops
   immediately before the final allocation. The physical
   MM table then contains five PROCESS owners, no PACKED:
   parent 050000..066000 of length 016000, four children
   of length 010000, largest aligned free gap 011577 and
   total free gaps 013402 (all values octal).
3. return-stop-v1616.sh uses the same output trigger, then
   registers an execution breakpoint only at the unique
   instruction AFTER PUSHJ 17,vm_space_brk_current. The
   exact source-map address is 020761 in the preserved
   image; the call instruction, compare and following
   JRST are checked against the actual KCORE DXR words.
   SIMH CONT resumes at the existing PC without rebooting.

The final pressure experiment did NOT hit the return
breakpoint before its controlled timeout. Its asynchronously
interrupted later MM snapshot had no PROCESS owners and
two PACKED owners:

    owner 5: 067000..076000, size 007000, pins 0
    owner 4: 076000..106000, size 010000, pins 1

Current slot was zero; the captured PC was 030762, in the
removable-module address range. This is physical evidence
of actual RAW PACKED MM publications. It does not establish
a successful BRK return, a completed RUN restoration or
positive net RAM benefit.

Importantly, the original mm_pure_claim_prefix_v1384
intentionally changes a pinned PACKED suffix to its full
APR size while a potentially slow VFS prefix reload runs.
It retains PACKED type and the pin until the commit or
rollback. The late owner-4 snapshot matches this
intermediate geometry, but cannot prove that the operation
later committed, rolled back or leaked a pin.

## Source-map-grounded physical audit

Run the offline, read-only audit on the saved guest evidence:

    python3 audit-v1616.py /path/to/build/kcore.map \
        /path/to/before/trace.clean \
        /path/to/interrupted/trace.clean

The audit validates arena boundaries, overlapping ownership,
exact owner types, bases, sizes and pins. It explicitly
refuses to declare the interrupted state a restored process.

The versioned run-audit-v1616.sh wrapper also mutates
the preserved owner-4 metadata to remove its pin.
The physical auditor must reject this unsafe mutation:

    PURE_BRK_BUILD_V1615=/path/to/build \
    PURE_BEFORE_TRACE_V1616=/path/to/pre/trace.clean \
    PURE_AFTER_TRACE_V1616=/path/to/interrupted/trace.clean \
        sh run-audit-v1616.sh

Continue by sampling at a consistent restoration commit/
rollback boundary, with source identity and scheduler mode
checked, then test complete PIPE/WAIT/EXIT. No kernel change
is warranted solely from an interrupted pinned PACKED view.

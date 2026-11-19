# v1617 physical PDP-6 MRES origin and DECtape wait

Status: read-only physical diagnostics, not P1-E production
restore or net RAM acceptance.

The v1616 late CPU PC 030762 was ambiguously described as
being in removable code. The v1617 physical scheduler
trampoline probe and original module DXR identify it
specifically as Type-551 DECtape dtc_search_wait.

The source-linked original exports give PURE MRES base
032027 (octal) and tape MRES base 030431. The tape
instruction at relative offset 000331 is exactly the
physical SKIPN storage_count instruction at 030762.

Three standalone test-only entry points are supplied:

* probe-mres-v1617.sh: stop the actual no-AUX 48K PDP-6
  before the final BRK and examine the original two
  resident scheduler jumps plus the known interrupted
  instruction.
* tape-wait-v1617.sh: after the same console marker,
  defer a CPU breakpoint at the original linked tape
  wait instruction until the guest requests the final
  BRK. Read the live storage timer and MM table.
* run-audit-v1617.sh: compare original KCORE/PURE maps,
  linked tape DXR, tape source and THREE separately
  preserved physical traces. Reject deliberately unsafe
  service-export and tape-countdown mutations.

To run the physical replay wrappers, set
PURE_BRK_BUILD_V1615 to the matching full 48K PURE
TSFS build directory. They preserve a private SIMH
trace and clone writable tape media. Both use the
existing v1615 replay's optional source-checked modes;
the existing v1615/v1616 modes remain available.

To audit the saved physical evidence:

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_BRK_BUILD_V1615=/path/to/build \
    PURE_MODULE_PROBE_TRACE_V1617=/path/to/probe.clean \
    PURE_INTERRUPTED_TRACE_V1616=/path/to/late.clean \
    PURE_TAPE_WAIT_TRACE_V1617=/path/to/tape-wait.clean \
        sh run-audit-v1617.sh

The live tape breakpoint observed storage_state=0200
and storage_count=-05214 octal ticks, the exact initial
45-second Type-551 RBN search timeout at 60 Hz.
The physical MM table had three unpinned 007000-word
PACKED suffixes and a fourth full-size, one-pin
PACKED prefix claim. This is legitimate intermediate
restoration geometry, NOT a leak proof.

The physical timer value was sampled only ONCE. No
clock progression, successful DECtape block read,
prefix commit or rollback, or completed RUN/WAIT
has been demonstrated. Do not use the diagnostic
as a positive net RAM claim or a reason to change
production tape timeout logic.

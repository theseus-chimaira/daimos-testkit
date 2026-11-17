# P1-E v1640: physical FULL memory-refusal/rollback/retry test

This original 48K physical experiment is accepted (2026-11-17).
It continues accepted v1638 successful
compressed-PURE FULL relocation and v1639 physical six-owner RAM
comparison. No permanent KCORE, MRES, MM, VFS or process code is
patched or instrumented. Original 48K PDP-6 core and Type-551
TSFS/no-AUX boot are used.

The guest is derived from the original v1614/v1636/v1637/v1638
C89 source and continues to perform the same six child PIPE
reads, private mutable sentinels, EXIT-057 and exact six parent
PID/EXITED/status-057 WAITs. Only the assignment of source
executables changes: compressed PURE `/SYSTEM/COMP` in slot2,
plain PURE `/SYSTEM/INIT` in slot3, and compressed PURE in slots
4..7. The seventh RUN must refuse under honest memory pressure.

With all six children PACKED, each retains 007000 octal words;
available free space is less than a new 010000-word aligned APR.
If slot2 is chosen for restoration first, v1384 prefix loader
returns UNSUPPORTED for its real compressed DXR2 source. The
genuine v1391 FULL transaction must pin the original suffix,
attempt a separate complete APR via `mm_alloc_aligned_noreclaim`,
return NOMEM and unpin that original suffix without touching
the PACKED extent or incorrectly publishing a runnable image.
The later plain slot3 child can restore in place and exit,
releasing space for legitimate bounded FULL retries.

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-full-refusal-v1640/run-v1640.sh

On success, replay the SAME original guest and private tapes
with read-only, source-authenticated instruction breakpoints:

    PURE_FULL_REFUSAL_BUILD_V1640=/path/to/guest/build \
        sh tests/diagnostics/pure-full-refusal-v1640/replay-v1640.sh

The v1640 replay uses the proven v1638 linker-map/MM snapshot
collector. It also stops at the actual MRES offset 002310,
first instruction after its MM allocation call 002307, and
at offset 000433 after returning from the v1391 transaction.
Both instructions and the later bounded FULL entry at 003224
are source-checked against the compiled original MRES DXR.
The auditor requires, in order, initial B/A six PACKED owners,
the expected MM_ERR_NOMEM -1 with ONLY slot2's suffix pinned,
the same six PACKED extents after genuine rollback with ZERO
pins, a later separately pinned FULL source/destination pair,
and normal exact parent six-WAIT/Z/HALT completion with no
remaining child MM owners.

    PURE_FULL_REFUSAL_BUILD_V1640=/path/to/guest/build \
    PURE_FULL_REFUSAL_TRACE_V1640=/path/to/replay/trace.clean \
        sh tests/diagnostics/pure-full-refusal-v1640/run-audit-v1640.sh

## Accepted original physical results

The complete compressed-first PDP-6 guest produced:

    aaaaaax[B013470/042501]<010000+010000>
    [A013470/042501]{013470-013470}LwwwwwwZ

Original simulator HALT, all six child PIPE/private-data/EXIT-057
and all six exact parent WAIT status checks passed.

At both B and A, there are six distinct, unpinned 007000-word
PACKED owners (slots 7..2), parent 130000..140000. The
source-linked original PC 034336 (instruction after v1391 MM
allocation call) returns `777777777777` (= MM_ERR_NOMEM -1).
At this exact point slot2 still owns physical PACKED suffix
121000..130000, with pin count 1. There is NO separate APR for
it. At original PC 032461, the return from v1391 to the PURE
service, AC1 still holds -1, the exact six PACKED extents have
not moved, and ALL their MM pins are ZERO. Both PCs are from
the installed original PURE MRES and compiled symbol layout.

Later the same physical simulator enters bounded FULL loader
at original PC 035252 for the SAME compressed child slot2.
AC2 = 110000, AC4 = 010000 allocated physical words. Original
MM at that instruction has separate simultaneous pinned owners:

| Child owner | Octal physical interval | Type | Pins |
|---|---|---|---:|
| 2 | 121000..130000 | PACKED_PROCESS suffix | 1 |
| 2 | 110000..120000 | Full PROCESS target | 1 |

The target was allocated only after a different plain child
completed and freed space. The original raw suffix remains
separately owned throughout the late FULL callback. The
simulator continues through all six final WAITs and Z, and
the final MM table has no child PROCESS or PACKED owner.

The full source/MM/opcode/console auditor PASSes. It also
rejects both a forged pin remaining after rollback and an
invented successful return from the failed allocator.

This is a natural resource-refusal and retry test, NOT an injected VFS read error
or a test of corrupt compressed executable payloads. Such a
failure, immutable source loss/unmount, PI6 concurrency and
whole-system transient peak RAM remain independent P1-E gates.
PURE remains OFF by default; strict 32K size optimization HOLD.

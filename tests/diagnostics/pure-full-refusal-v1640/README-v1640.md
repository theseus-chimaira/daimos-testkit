# P1-E v1640: physical FULL memory-refusal/rollback/retry test

This testkit-only experiment continues accepted v1638 successful
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

The testkit also rejects a fake after-rollback source pin and a
forged successful NOMEM allocator return. This is a natural
resource-refusal and retry test, NOT an injected VFS read error
or a test of corrupt compressed executable payloads. Such a
failure, immutable source loss/unmount, PI6 concurrency and
whole-system transient peak RAM remain independent P1-E gates.
PURE remains OFF by default; strict 32K size optimization HOLD.

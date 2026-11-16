# P1-E v1613: non-accepting physical pressure diagnostic

This is a deliberately separate *diagnostic*, not a passing
validation test or an accepted RAW PURE scheduler workload.

The existing `daimos-swap-wait-v1.c` physical DISK test creates
large resident processes until a sleeping pipe reader becomes
nonresident. The v1613 adaptation avoids all BACKSTORE
enabling, boots a 64K PDP-6 TSFS root with no attached DSK/DRM
media, and emits MEMINFO snapshots from the guest.

Two full physical attempts correctly reached the KINIT
`PURE LOADED` witness and started the custom guest, but
both then failed at the third large child RUN (`!e`):

* First image: BSS = 8193 words. Console: `rapbp!e`.
* Second image: BSS = 7169 words. Console:
  `ra[a045020/042522]pb[b067430/042522][c112040/042522]p!e`.

The numeric pairs are octal `MEMINFO.process_words` and
`MEMINFO.resident_words`. The current syscall counts
only VM images with nonzero APR bases; an inactive PACKED
process retains writable physical suffix words that
`MEMINFO.process_words` does not include. The snapshots
therefore must NOT be reported as net reclaimed physical RAM.

The workload requests another large, aligned process extent
before demonstrating that omission of smaller immutable
PURE prefixes can release sufficient contiguous physical
memory. No RAW reclaim, slot-0 restoration, or net positive
RAM benefit was proved. This is not evidence of a compiler
or scheduler defect by itself.

For further diagnostic experiments:

    DAIMOS_REPO=/path/to/DAIMOS KEEP_TEST=1 \
        sh tests/diagnostics/pure-pressure-v1613/run-v1613.sh

The next acceptance design should create sleeping owner
processes that already fit, then apply a smaller, controlled
BRK/MM request that actually forces RAW prefix DROP.
It must observe retained writable suffix ownership, actual
physical words recovered, slot-0 RUN restoration, PIPE wake
and WAIT. Do not count unmapped logical images as fully
freed physical words. Do not change production KCORE to
make this oversized historical DISK workload succeed.

For the accepted v1613 physical **boot** and source-linked
KINIT selection tests, use
`tests/validation/pure-boot-v1613/run-v1613.sh` and
`tests/validation/pure-boot-select-v1613/run-v1613.sh`.

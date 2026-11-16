# P1-E v1636: low BCACHE enables six complete 48K child APRs

This is a physical PDP-6 48K TSFS/no-AUX/GCC/PURE admission and
process-lifecycle test for the single production change to
`system/kernel/storage/bcache_pdp6.s`: allocate the reclaimable
private 0201-word clean slab with `MM_ALLOC_LOW` instead of HIGH.
The cache's owner 6, exact size, two entry identities, invalidation,
recursion-safe no-reclaim allocation, and MM release are unchanged.

The original v1614 child C89 source is transformed in testkit into
a distinct six-child guest with a no-growth BRK, a bounded ordinary
accounting test, and `L` lifecycle-only success marker. The original
per-child PIPE read, both mutable-data sentinels, EXIT status 057,
six exact parent PID/EXITED/status-057 WAITs, parent data sentinels
and final `Z` are unchanged. This does not assert net RAM savings.

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-cache-low-v1636/run-v1636.sh

The genuine source-built 48K simulator completes and HALTs with:

    aaaaaa[B073470/042501]<010000+010000>
    [A073470/042501]{073470-073470}LwwwwwwZ

The continuous console output has six admitted children, six
successful private-data/PIPE markers, and a single parent Z after
the exact original WAIT status checks. The original v1631 PURE-on
high-cache build admitted only five children before rejecting its
sixth. Both use the installed optional PURE MRES and 48K memory.

Replay the SAME original linked image with read-only MM stage
snapshots at parent B, A and final Z:

    PURE_CACHE_LOW_BUILD_V1636=/path/to/guest/build \
        sh tests/diagnostics/pure-cache-low-v1636/replay-v1636.sh

And validate the original source, linked MM symbols, executable
purity, cache low-placement instruction, and actual owners:

    PURE_CACHE_LOW_BUILD_V1636=/path/to/guest/build \
    PURE_CACHE_LOW_TRACE_V1636=/path/to/replay/trace.clean \
    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-cache-low-v1636/run-audit-v1636.sh

The actual original MM snapshots prove:

| Stage | Parent APR, octal | Children | PACKED | Cache | Extents |
|---|---|---:|---:|---|---:|
| B | 130000..140000 | 6 | 0 | low | 025 |
| A | 130000..140000 | 6 | 0 | low | 025 |
| Z | 130000..140000 | 0 | 0 | low | 010 |

The source-linked v1636 physical auditor passes and rejects
a forged low-parent APR and a forged parent success/WAIT marker.
There is no overlapping extent or child owner after successful
WAIT. The original BCACHE v1490 MM-free/write-invalidations
and multi-source cache tests also pass with the changed source.

**Scope limitation:** None of the six children is PACKED at B/A:
this demonstrates recovered full-APR capacity, not restoration
under additional RAW pressure. The separate v1637 seventh RUN
pressure test is required to prove genuine PACKED restoration on
this new placement, followed by wider 32K/64K/BCACHE regression
and full P1-E owner/source/net/peak RAM acceptance. PURE remains
disabled by default; strict 32K whole-KCORE optimization HOLD.

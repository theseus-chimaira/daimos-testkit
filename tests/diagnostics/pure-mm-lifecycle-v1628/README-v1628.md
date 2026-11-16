# P1-E v1628: physical MM owners across successful 64K six-child guest

The original physical v1627 64K PDP-6 no-AUX/TSFS/PURE executable
and four Type-551 tapes are replayed without recompilation or
changing KCORE/MRES/MM/driver code. SIMH console EXPECT samples the
original MM descriptors during parent `B`, `A` and final `Z` phases.
The actual console may concatenate `V1628_STAGE_B` to `[B` because
the monitor stopped mid-line; this is expected and the source-
linked testkit parser uses the unique ECHO markers, not line starts.

    PURE_MM_BUILD_V1628=/path/to/v1627/build \
        sh tests/diagnostics/pure-mm-lifecycle-v1628/replay-v1628.sh

Validate the preserved trace and two unsafe mutations:

    PURE_MM_BUILD_V1628=/path/to/v1627/build \
    PURE_MM_TRACE_V1628=/path/to/physical/trace.clean \
        sh tests/diagnostics/pure-mm-lifecycle-v1628/run-audit-v1628.sh

## Actual original three-stage machine result

All values are octal words. The MM arena stays `042602..200000`
and the parent remains current slot 1 through B/A/Z.

| Point | Extents | PACKED owners | Occupied | Physical free | Largest aligned gap |
|---|---:|---:|---:|---:|---:|
| B | 025 | 0 | 074654 | 040322 | 036000 |
| A | 025 | 0 | 104654 | 030322 | 016000 |
| Z | 010 | 0 | 021556 | 113420 | 071577 |

There are no foreign-owner overlaps, invalid types or stranded
PACKED pins in the original snapshots. All six children finish the
original source-authenticated WAIT/EXIT lifecycle before Z; no
PACKED child owner remains there. Two corrupt physical fixtures
(overlapping MM extent, missing final snapshot) are rejected.

**Important limitation:** the 64K functional profile does not
exercise RAW PURE omission at B or A. The optional PURE MRES is
installed but the children are still ordinary resident PROCESS
owners, so this workload cannot establish actual packed-restore
concurrency or positive whole-system net RAM. These are samples,
not the transient peak. A 48K pressure guest with actual PACKED
owners is required for the next physical lifecycle acceptance.

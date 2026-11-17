# P1-E v1638: source-matched compressed PURE FULL relocation experiment

Status: testkit physical experiment, not an accepted production fix.
No KCORE, MRES, MM or process logic is patched by these tests.

## Why this tests FULL rather than plain in-place reloading

The PDP-6 PURE-prefix loader intentionally returns its documented
UNSUPPORTED result (-2) for a compressed DXR2 PURE source. The
PURE service then tries the separately linked bounded FULL v1391
restore transaction. A valid FULL restoration needs both the
existing pinned PACKED suffix and a separately allocated pinned,
complete 010000-word APR. Merely hitting a branch entry does not
prove that MM owner geometry or publication is correct.

The original v1637 six-child 48K pressure workload packs six
007000-word writable suffixes after a refused seventh RUN. In
that state no additional 010000-word APR fits while the parent
is alive. v1638 therefore keeps the first child as PLAIN PURE;
it can reconstruct in place and exit, freeing a complete APR.
The remaining five children run a COMPRESSED PURE copy of the
identical guest executable from `/SYSTEM/COMP`. A compressed
child must use FULL with a distinct physical destination APR.

## Fixture construction

`prepare-v1638.py` derives the original C89 PIPE/data/EXIT/WAIT
guest from v1614/v1636/v1637; it changes only the child image
selection. Child slot 2 uses `/SYSTEM/INIT` plain, slots 3..7
use `/SYSTEM/COMP` compressed, and the seventh RUN must be
refused cleanly. The parent still checks all six exact child
PID/EXITED/status-057 WAITs, both private-data sentinels and
the final `Z` success marker.

The opt-in testkit-only hook `PURE_TSFS_PRE_SIM_V1638` adds a
COMPRESSED+PURE DXR2 copy of the freshly compiled plain `INIT`
using the original `d6block-v1464` tool. It authenticates the
exact little-endian DXR2 header, PURE/COMPRESSED flags and
payload length, then uses original `mktsfs-v1461` with the
actual compressed low-memory boot image to build three writable
test-copy Type-551 tapes. The original `tsfscheck-v1461` validates
the resulting three-member volume. The installed legacy
`dxrcheck` cannot report compressed DXR payloads; it incorrectly
assumes the plain payload length, so it is not used as the
COMPRESSED-source inspector. It is still used for the plain
installed PURE-MRES opcode map.

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-full-restore-v1638/run-v1638.sh

Save the original guest build directory, then capture actual
MM table snapshots before/after parent checks, at the first
bounded FULL loader invocation and after parent WAIT completion:

    PURE_FULL_BUILD_V1638=/path/to/guest/build \
        sh tests/diagnostics/pure-full-restore-v1638/replay-v1638.sh

The replay authenticates the original linked PURE MRES opcode
and physical address before installing the breakpoint. At the
FULL callback it records AC1..AC4 and MM extents, requiring
a pinned PACKED source and independently pinned PROCESS target
for the SAME process slot, with no overlap or alias. Final Z
must follow all original six WAIT checks and leave no children.

    PURE_FULL_BUILD_V1638=/path/to/guest/build \
    PURE_FULL_TRACE_V1638=/path/to/replay/trace.clean \
        sh tests/diagnostics/pure-full-restore-v1638/run-audit-v1638.sh

The auditor separately rejects a forged FULL target owner and
a forged parent WAIT success marker. Only a passing original
source-linked simulator trace closes this physical path.

This does NOT yet cover failed compressed reads/source loss,
relocation rollback or transient whole-system net/peak RAM.
PURE is disabled by default; strict 32K whole-KCORE optimization
remains on HOLD pending complete P1-E acceptance.

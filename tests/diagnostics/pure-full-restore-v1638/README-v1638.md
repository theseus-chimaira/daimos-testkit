# P1-E v1638: source-matched compressed PURE FULL relocation experiment

Status: source-matched physical successful FULL relocation ACCEPTED
2026-11-17. No KCORE, MRES, MM or process logic is patched.

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
a forged parent WAIT success marker.

## Original physical 48K result

The exact source-built mixed guest finished with the complete
continuous console:

    aaaaaax[B013470/042501]<010000+010000>
    [A013470/042501]{013470-013470}LwwwwwwZ

Normal simulator HALT followed. Both B and A MM snapshots
contain six unpinned PACKED 007000-word suffixes, owners 7..2,
with parent APR 130000..140000, proving actual RAW pressure.
The breakpoint replay then physically stopped at the original
bounded FULL loader `exec_image_full_bounded_v1391`, PC 035252
octal. Its installed opcode `200000000004` matches the original
linked PURE MRES DXR offset 003224. The restore is executing
under scheduler slot zero and the callback's AC2 destination
is 120000, AC4 allocated APR capacity 010000.

The original MM table AT THAT INSTRUCTION contains two
simultaneously pinned, nonoverlapping extents belonging to
the SAME compressed child slot 3:

| Owner | Physical extent (octal) | Type | Pins |
|---|---|---|---:|
| 3 | 111000..120000 | PACKED_PROCESS | 1 |
| 3 | 120000..130000 | PROCESS | 1 |

The writable source suffix was still owned and intact while
the full APR was safely reserved for the bounded compressed
image loader. This is physical v1391 **relocated** restoration;
the ordinary v1384 in-place claim cannot allocate a distinct
MM_TYPE_PROCESS owner for the same process. The first plain
child had already completed, making the replacement APR
available without fabricating memory or changing the kernel.

After loader execution, five remaining `w` markers and the
parent's original Z appear. The final source-linked MM Z table
contains no PROCESS/PACKED child owner 2..7. The original source,
compressed PURE flags, MM and callback opcode audit PASSes;
the two falsified-owner/WAIT test witnesses are rejected.

This test does not claim that every compressed child received
an individually observed PC breakpoint; the physically checked
FULL invocation is slot 3. All six original child data/EXIT
and parent WAIT results nevertheless passed.

This does NOT yet cover failed compressed reads/source loss,
relocation rollback or transient whole-system net/peak RAM.
PURE is disabled by default; strict 32K whole-KCORE optimization
remains on HOLD pending complete P1-E acceptance.

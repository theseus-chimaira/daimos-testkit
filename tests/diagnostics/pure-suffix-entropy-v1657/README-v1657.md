# v1657: actual 48K PDP-6 PURE RAW suffix density

Date: 2026-11-17. Original 48K/no-AUX/TSFS-root
source-built PDP-6 physical simulation, with REAL
secondary DTC3 DTFS compressed PURE executable.
No DAIMOS kernel/MRES/MM/ABI or simulator code was changed.

The program source, original KCORE/MRES symbol maps,
original v1654 real secondary-media read/rollback
trace and unchanged boot image are the inputs.
The testkit uses the original v1638 source-linked MM
parser on the accepted v1654 B snapshot to derive
the physical addresses/owners of six separately
owned, unpinned PACKED_PROCESS suffixes in slots2..7.
It does not guess their address or truncate
the raw representation to a BSS-only range.

The new simulator run copies the unchanged four
physical Type-551 DTFS/TSFS reels privately and
boots the original 48K PDP-6 guest. At the original
six-child pressure marker it examines every retained
36-bit word for every one of the six source-derived
006600-octal (3,456-decimal-word) RAW extents.
It then continues all original PIPE/EXIT-057/WAIT
operations through normal PC000000 HALT.

The independent testkit auditor checks all 20,736
physical words by exact address, 36-bit word width,
per-process SHA256 and exact word count; constructs
the bitmap-v1451 representation as a 36-word group
presence mask followed by every nonzero literal,
reconstructs all physical source words exactly,
and asserts the source-derived mask/literal size.
Slot2 has three private words different from the
identical slots3..7, giving TWO distinct original
source-specific SHA256 checksums. Equal encoded
sizes do not imply identical private mutable data.

## Source-real 36-bit word counts

| Physical source | RAW words | Nonzero | Bitmap words | Difference |
| --- | ---: | ---: | ---: | ---: |
| Slot2 | 3,456 | 65 | 161 | 3,295 |
| Slot3 | 3,456 | 65 | 161 | 3,295 |
| Slot4 | 3,456 | 65 | 161 | 3,295 |
| Slot5 | 3,456 | 65 | 161 | 3,295 |
| Slot6 | 3,456 | 65 | 161 | 3,295 |
| Slot7 | 3,456 | 65 | 161 | 3,295 |
| **TOTAL** | **20,736** | **390** | **966** | **19,770** |

Each 3,456-word source has 96 bitmap words
(3,456 / 36) and 65 nonzero literals. This
is exactly the already validated v1451 30-word
PDP-6 assembly zero-bitmap codec's data format.
The physical source has 3,391 zero words
per owner, not a guessed sparse workload.

Three independent false physical witnesses are
rejected: a changed slot2 retained word,
one missing RAW address, and a forged normal
HALT. Mutations are testkit-only and never
entered the running original simulation.

## Reproduction

Use the original v1654 physical PDP-6 48K source
build and the matching accepted v1654 DTC3 source
fault trace (which contains the original B MM table):

    export TMPDIR=$HOME/tmp
    export PDP10_PREFIX=$HOME/cross
    export PURE_SUFFIX_BUILD_V1657=/path/to/guest/build
    export PURE_SUFFIX_TRACE_V1657=/path/to/v1654/trace.clean
    sh tests/diagnostics/pure-suffix-entropy-v1657/run-v1657.sh

## Important limits

The 19,770-word number is **only** the hypothetical
RAW-to-bitmap data reduction, NOT a realized production
allocation saving. The v1451 encoder requires separate
nonoverlapping MM source/destination extents, correct
length and capacity; its tested MRES code adds 30
instructions and a package image, and proper
MM storage mode3, ownership/PI, safe refusal,
EXEC/EXIT/unmount and decode/restore transactions
have not been implemented or accepted.

v1651 measured only six original MM table snapshots,
not continuous whole-machine peak. The observed
161-word encoded candidate would fit its 883-word
largest B free gap, but that ALONE does not prove
an MM allocation/commit, adequate descriptor space,
all failure rollback paths or final net reduction.
The measured data supports implementing a separate
optional compression prototype with actual
source-linked native/physical evaluation rather than
accepting NO COMPRESSION without examination.

P1-E optional compression and complete physical
high-water remain OPEN; 32K boot/size acceptance
is explicitly DEFERRED.

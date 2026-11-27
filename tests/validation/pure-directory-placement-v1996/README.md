# v1996 bidirectional directory placement

Actual source commit DAIMOS 1f973524 (v1995 topic parent 383dd118).
The optional directory MRES reuses its exact pinned DROP lease and
existing descriptor. Low placement is unchanged; upward placement is
selected only when the lowest fitting sector gap's leading fragment
can contain the complete bitmap without using a full aligned APR.
The MM leaf validates both disjoint directions and moves intervening
sorted descriptors with no temporary owner or fallible post-copy step.

## Reproduction

Run tests/validation/pure-bitmap-placement-v1985/run-v1985.sh for each
PURE_TEST_COMPILER_V1984=gcc/kcc, with DAIMOS_REPO and PDP10_PREFIX set.
Repeat with PURE_DIRTY_DROP_V1993=1. Build the v1983 package matrix with
run-build-v1983.sh from tests/validation/pure-directory-package-v1983.
Build fresh 48K and 64K strict TSFS directory images using the options
in the v1995 lifecycle README (64K BOOT_CORE_WORDS=0200000). Run the
same lifecycle wrapper with BUILD directory 48 or BUILD directory 64.
The comparison takes the three actual build/replay/source triples:

    python3 compare-v1996.py --raw RAW_BUILD RAW_REPLAY RAW_SOURCE \
        --lower LOWER_BUILD LOWER_REPLAY LOWER_SOURCE \
        --both BOTH_BUILD BOTH_REPLAY BOTH_SOURCE \
        --check-64 BUILD64 REPLAY64 SOURCE64

It reruns the independent lifecycle oracles, compares all three guest
image hashes, exact fixed KCORE bytes, physical owner consolidation,
free/aligned words and actual linked code costs. It requires a 48K
admission increase and preservation of the 64K fixture ceiling.

## Results

GCC/KCC each PDP6/KA10 33 placement, 5 FULL and 4 terminal calls,
9 placement mutants rejected per compiler. Upward tests include full
MM table, one/multiple foreign owners, overlap, no whole-APR sacrifice,
refused/false/lost replies, original APR overwrite then FULL and
terminal retry. Dirty DROP v1993: 25 cases per CPU/compiler, 6 mutants
per compiler. The first test incorrectly used the old three-descriptor
candidate oracle in a six-descriptor fixture; corrected to exact
candidate bytes and sole pinned owner, no production defect proven.

Source-built GCC RAW/directory 3258/5493, KCC 3885/6540 resident words,
zero BSS. Directory grows 33/36 words. Both directory->RAW->directory
switches reproducible and conflicting combinations refused. GCC RAW
package and both per-mode KCORE images match v1995 byte for byte.

Physical 48K identical INIT/COMP/POST: RAW/lower/bidirectional admit
5/5/8; free4950/16088/6691; descriptors18/18/25; aligned span
2560/3584/3584. New five251-word bitmap owners at 070000,070400,071600,
110000,110400; one RAW3584, two resident4096. Four direct compressed
TERM; six exact stopped WAITs; actual FULL/EXEC4096->2048, all eight
child waits, final MM/HALT and root tape integrity, eleven trace
mutants rejected. 64K retains twelve-child fixture ceiling, four251
bitmap/one RAW/seven resident, MM33, free1758, aligned512; three direct
compressed TERM, ten stopped waits, FULL/EXEC and all12 waits/final
MM/HALT/unchanged tapes; eleven trace mutants rejected. No claim of
maximum capacity or general real DSH/RT/K16 acceptance.

Evidence relative TMPDIR: pure-bitmap-placement-v1985.SGjJz3 (GCC),
.z6hrao (KCC), .6uV4V7 (GCC dirty), .EpRYNV (KCC dirty);
pure-directory-package-v1983.2tdjZh; pure-k15-bidirectional-v1996.FmgoHG
(includes compare-v1996.json); pure-directory-lifecycle-v1995-48-directory.c4OcX1
and pure-directory-lifecycle-v1995-64-directory.OeRbC3.

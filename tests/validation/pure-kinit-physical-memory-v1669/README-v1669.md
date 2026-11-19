# v1669: actual 48K/64K PDP-6 MM geometry at pre-reclaim KINIT

Exact DAIMOS parent v1668:
`d2c9ed455966d4be611048afb63abc7566ba2be5`.

This stage adds **no permanent KCORE, kernel feature or guest-side
probe**. Its purpose is to reconcile the v1668 1,877-word GCC
lowmem *link image* saving with the actual words available to MM
in a physical 48K or 64K PDP-6 before late KINIT cleanup.

## Live sampling contract

`run-physical-v1669.sh` independently builds (or accepts explicit
source-built paths to) the general ROOT=tape/PURE and dedicated
ROOT=tape/PURE/strict v1668 GCC lowmem images. Both images are
built from the same source. Each is run on a real SIMH PDP-6
with the same three-member TSFS root media and no attached DSK
or DRM backing, first with 48K and then 64K physical core.

The runner stops at the actual `kinit_late_start` instruction
from the image's own KINIT linker map. Before releasing KINIT
code/source, the unmodified kernel has already installed its
selected PURE service and its initial dynamic system objects.
The simulator examines the original physical MM globals:

* `mm_core_words` and `mm_extent_capacity`;
* `mm_arena_count`, `mm_arenas` (all three physical arena words);
* `mm_extent_count` and the allocated `mm_extents` descriptors;
* `sys_resident_words_immediate` (permanent resident low words).

`measure-v1669.py` checks unique symbol addresses against the
actual linker maps, real breakpoint execution, CPU core size,
PURE selection, maximum table capacity, physical arena bounds,
descriptor ordering/type/owner size and absence of overlapping
extents. It computes allocated/free core by subtracting each
real MM extent from its enclosing managed arena. In each image,
`managed words = physically free words + MM allocated words`
must hold exactly. This is not extrapolated from KINIT image end.

`compare-v1669.py` requires source-matched general and strict
images at each physical core size to have identical MM extent
allocations, installed resident low words and descriptor count.
It checks the *actual* live free/reserved difference against the
linked displacement of `__kinit_late_begin` and the largest
contiguous free-run difference against the linked image-end
displacement. This detects wrong arena accounting even when a
naive image-end-only assertion would report expected savings.

Three unsafe measurement variants are actually executed and
rejected: impossible physical MM arena geometry, removal of
the physical extent count and forged strict-image free totals.

## Evidence: source-matched pre-reclamation KINIT checkpoint

| Installed core | General free | Strict free | Free change |
| --- | ---: | ---: | ---: |
| 48K | 21,947 | 22,013 | **+66 words** |
| 64K | 38,299 | 38,365 | **+66 words** |

| Installed core | General largest | Strict largest | Change |
| --- | ---: | ---: | ---: |
| 48K | 10,022 | 11,899 | **+1,877 words** |
| 64K | 26,406 | 28,283 | **+1,877 words** |

The general and strict snapshots contain exactly the SAME MM
allocated extent totals: **598 words at 48K**, **614 at 64K**,
in six allocations. Real resident low occupancy is also equal
within each pair: **17,725 words** at 48K and **17,741** at 64K.

The observed physical distinction is caused by KINIT layout
relocation. The high arena grows by 1,877 words as the KINIT
image end moves down. However the earlier free arena shrinks by
1,811 words because KINIT's late/source layout shifts. The
net allocator-free increase at this pre-reclamation checkpoint
is therefore only 66 words. This 66-word value matches the
actual general-vs-strict `__kinit_late_begin` shift.

**Critical limitation:** these four physical readings represent
one precisely named KINIT *checkpoint*, not continuous temporal
peak memory consumption. No real compressed-mode3 process is
created, and source-image reclamation/INIT loading occur after
this checkpoint. Runtime changes after the breakpoint and all
intermediate MM allocations are not sampled. Do not report
1,877 words as additional free MM total, or 66 as guaranteed
steady-state/process peak savings. Continuous peak remains OPEN.

## Reproduction

    DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-kinit-physical-memory-v1669/run-physical-v1669.sh

For an already source-built pair, provide `V1669_GENERAL_BUILD`
and `V1669_STRICT_BUILD`. With `KEEP_TEST=1`, four simulator
transcripts, four original-MM JSON snapshots, comparison proof,
all mutation refusals and exact generated SIMH configs remain
under `$TMPDIR`. Every output is plain ASCII.

`run-runtime48-v1669.sh` is a separate sustained strict 48K
physical smoke test: the same 64K-capable TSFS image runs with
SIMH core changed to 48K, all AUXSTORE media detached. Require
`MEM 48 K`, `DTC OK`, `PURE LOADED` and `INIT V1`, and a guest
alive until the controlled timeout, with no SWAP/INIT errors.
The direct source-built 48K run reached INIT V1 and remained
running for 85 seconds in the initial physical acceptance.

48K/64K measured stage sizes do not establish the strict 32K
build gate. Real source/codec compression, RUN/EXIT/WAIT/PI6,
runtime pressure comparisons and continuous KINIT/VM/MM high-water
are explicitly deferred until suitable safe instrumentation.

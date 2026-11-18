# v1662 native PDP-6 prepared PURE bitmap commit and MM retirement

Parent: pushed DAIMOS v1661 `2fe9d857b1152a6d1eeb35e91c57116fc2ae5627`.

Run:

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-bitmap-commit-v1662/run-v1662.sh

The runner first executes v1661, v1660 and v1659 original native
regressions. `V1662_SKIP_BASELINE=1` skips that only during local
debugging; it MUST NOT be used for final acceptance evidence.

Actual original source-extracted PDP-6 MM allocator, fit, insert,
pin/unpin, free/delete/find and fixed mode2 expectation assembler
are linked. Neither the MM allocator nor MM descriptor deletion is
simulated in C. A controlled PI-state stub and one injectable
retirement-refusal wrapper permit native fault injection.

The v1657 retained RAW suffix consists of 3,456 PDP-6 words with
65 nonzero words in 96 bitmap groups; the 30-word original v1451
codec produces exactly 161 encoded words. The original real MM
allocator reserves the 161 words from the historical 883-word gap,
at octal `050122`. The C commit validates the entire canonical
stream and exact MM process ownership. The optional new assembly
leaf consumes the RAW owner's one pin as it deletes that descriptor,
and the C caller immediately publishes mode3 before PI restoration.
After the commit, actual original MM allocation of a separate
02000-octal-word KERNEL_DYNAMIC owner at the original RAW address
`040000` verifies that formerly pinned RAM is reusable. The v1660
decoder reconstructs every RAW word and the v1661 terminal leaf
then releases the exact compressed owner.

The additional native cases check 24 prepared-wrapper refusals and
21 direct MM-leaf refusals, preserving MM descriptors, mode and
source pins. Accepted cases cover both descriptor orderings, a
separate same-numeric-ID MODULE owner and a full 136-entry MM
table. Independently executed source mutations (bypassed stream
verification and ignored extra PACKED_PROCESS owner) are rejected.
Expected mutant errors are inspected in native `p10run` reports;
build/link failures are never counted as successful mutant rejection.

Unlinked prototype size: C89 prepared commit 606 TEXT words, new
PDP-6 assembler MM leaf 125 TEXT words, both zero DATA/BSS.
No production mode3 dispatch, scheduler service, FULL restore or
physical 48K/64K compression is installed. The native tests verify
real MM reuse in an isolated fixture, not an accepted booted guest.
PURE remains OFF by default; strict 32K physical acceptance deferred.

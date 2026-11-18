# v1664 native PDP-6 bounded compressed PURE FULL APR restore

Parent DAIMOS: pushed v1663 commit
`640be3b6d37cba9082cf6f60f24e6b8d90e3ceef`.

Run in daimos-testkit:

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-bitmap-restore-v1664/run-v1664.sh

The default runner executes v1663 -> v1662 -> v1661 -> v1660 ->
v1659 original native baselines before its new tests. The option
`V1664_SKIP_BASELINE=1` is for interactive debugging ONLY and must
not be used to create the release evidence archive.

This is a test-only source-linked build: the exact original PDP-6
no-reclaim MM allocator, descriptor search/insertion, pin, unpin,
free and deletion routines are extracted mechanically from the
DAIMOS sources and assembled. The existing fixed mode2 check,
v1451 30-word bitmap codec, v1660 bounded decoder, v1661 terminal,
v1662 MM commit, and v1663 compressor all run under PDP-6. Native
fixture code controls PI-state observations and MM/callback fault
injection; the loader is a capacity-bounded test callback and is
NOT a real VFS executable loader.

The v1663 frontend first creates mode3 from 3,456 authoritative
RAW words (65 nonzero, 96 mask groups, 161 encoded words), retaining
the compressed source under TRANSITION. A new managed physical
arena provides an exact 4,096-word, 02000-octal-aligned APR target
at octal `0100000`. The v1664 restore pins both source and APR,
calls the bounded loader and v1660 preflight/decode, then finishes
with the new MM ASM leaf and nonfallible PI-excluded publication.

On success the native oracle checks EVERY full APR word: the
loader-derived immutable prefix and completely decoded RAW suffix,
the sole unpinned PROCESS MM owner, process APR base, cleared PURE
backing, resident mode0 and cleared TRANSITION. Success cases cover
an all-zero RAW suffix (96 bitmap masks), an independent MODULE
owner sharing the process slot's numeric ID, and SRUN restoration
performed by slot 0.

The direct MM tests prove source-before-target and
target-before-source descriptor ordering, unrelated MODULE owner,
and a full 136-descriptor MM table. They refuse every mismatched
owner, type, pin, APR alignment/size, bitmap size, disjointness,
descriptor count/capacity and extra PROCESS/PACKED_PROCESS owner.

The 62 native test cases comprise 38 FULL wrapper cases (including
four successful restores) and 24 direct MM cases (four successful
commit geometries), yielding 54 refusal/corruption states. These
exercise loader failure after writes, invalid compressed masks
and literals, actual MM NOMEM/descriptor refusal, false MM pin or
unpin outcomes, refused/false-success free, missing backing or
mount, unexpected APR, mode and TRANSITION changes, and a stale
RUN owner. An ordinary failure leaves only the exact unpinned
compressed mode3 owner; an uncertain failure leaves surviving
extents quarantined rather than guessing how to repair ownership.

An independently compiled mutant bypassing the v1660 decoder
and an independently assembled MM mutant ignoring an extra packed
owner are both executed on PDP-6. A mutation only passes if the
normal native oracle detects its incorrect state; build or
simulator failure is NOT accepted as a successful mutant test.

Standalone unlinked sizes: C89 restore 969 TEXT words, PDP-6 MM
finish 133 TEXT words, each zero DATA/BSS. The fixed KCORE remains
unchanged and continues to refuse mode3. Physical guest VFS,
scheduler, terminal EXIT/WAIT and 48K/64K full-system compression
acceptance have NOT yet been performed. PURE default OFF, strict
32K physical acceptance deferred.

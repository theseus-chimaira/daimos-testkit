# v1663 bounded native PDP-6 PURE bitmap compressor frontend

Parent DAIMOS v1662 commit `06f34cc23d4e5a16e6c735801930089bf0583e5f`.

Run from the testkit worktree:

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-bitmap-compress-v1663/run-v1663.sh

By default the runner first executes the entire original
v1662/v1661/v1660/v1659 source-linked native regression chain.
`V1663_SKIP_BASELINE=1` is allowed for iterative debugging but
must not be used to generate release evidence.

The runner extracts and assembles the **unchanged original** PDP-6
MM allocation, fit, insert, find, pin, unpin, free and delete
functions, together with the original KCORE mode2 expectation.
It links these with the unchanged 30-word v1451 bitmap codec, the
v1660 bounded decoder, v1661 compressed terminal, v1662 atomic
commit/MM retirement, and the actual new C89 v1663 compressor.
The testkit only injects MM return-value/descriptor anomalies and
observes PI exclusion; it does not emulate the real MM allocator.

The frontend takes a noncurrent stopped/sleeping TRANSITION owner
in mode2 with an exact unpinned RAW suffix and immutable executable
backing. It pins RAW, counts nonzero words, uses the exact bitmap
capacity, allocates an exact shorter HIGH candidate with no
reclamation, verifies both MM descriptors before writing, encodes
with the original native codec, unpins the candidate, and calls the
fully verified v1662 commit. Mode3 publication does not unlock the
process. On ordinary refusal the candidate is freed before RAW
unpin and post-operation owner proofs reject false MM success.

Native positive cases:

1. The original 3,456 RAW / 65 nonzero / 161 encoded geometry.
   The real 883-word free gap accepts 161 words at octal `050122`.
   After mode3 commit the real allocator reuses the former RAW base
   at `040000` for an independent 02000-octal-word MM owner. The
   bounded decoder reconstructs all RAW words; terminal release
   correctly frees the final compressed owner.
2. Same sparse image with an unrelated MODULE MM owner carrying the
   same numeric ID, demonstrating distinct MM owner namespaces.
3. Completely zero-filled RAW requires precisely 96 bitmap masks,
   with exact HIGH placement at octal `050223`; full decode,
   reclaimed-RAW allocation and terminal release all succeed.

41 additional no-gain, admission, MM and fault cases check exact
output, RAW content, retained TRANSITION, MM descriptors, pin
counts and storage mode. These include dense RAW with zero
allocation, actual MM NOMEM and descriptor exhaustion, invalid
mount and saved backing, invalid or duplicate owner, corrupt
encoder output, false allocator success/failure, false pin and
unpin success/failure, candidate free refusal/false success,
process mode corruption and overlap. Ordinary cleanup must leave
one unpinned RAW MM owner in mode2; uncertainty must never unlock.

Independently compiled source mutations that disable candidate
geometry validation or skip the actual target unpin are executed
on PDP-6; the independent native oracle must reject both. Build,
link or simulator failures are not counted as mutant rejection.

Standalone frontend costs 776 TEXT words, zero DATA/BSS. These
are test-only; KCORE/MRES footprint and physical guest peak are
not measured. Mode3 FULL APR restore, live scheduler and terminal
dispatch remain absent; PURE default OFF, strict 32K deferred.

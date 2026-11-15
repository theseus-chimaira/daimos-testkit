# P1-C v1602: original D6FS write-through failure and clean BCACHE isolation

Date: 2026-11-15. This is a source-linked **native PDP-6** execution
test. It is NOT a whole-guest physical controller-detach test. Only the
terminal Type-270/Type-236 transfer completion is test-controlled; the
original selected-reader commit, original clean BCACHE, direct DSK/DRM
FS_BACKING adapter, and critical-root-vs-secondary error gate are linked
from the exact DAIMOS checkout without replacing their implementation.

## Production ordering verified

`d6fs_reader_commit_cache` must first invalidate its own shared
`fs_block_workspace` clean tag. It then invokes the original
`fs_backing_write`, which routes the physical request to the selected
Type-270 or Type-236 adapter. **Only after a successful authoritative
WRITE** may it refresh BCACHE from the modified workspace. On failure
it calls the original `kcore_root_fs_io_failure_v1538` with the actual
writing reader's provider=6 and public mount ID. A secondary mount
returns a negative ordinary filesystem error; the selected root
remains a critical reason-1 HALT (already independently executed by
v1538/v1544 and physically characterized by v1540/v1543).

BCACHE is **clean-only**. There is no dirty-list, flush daemon or
write-back owner. Thus the relevant P1-C fault is an incomplete or
failed authoritative WRITE with the prior clean tag already invalid,
not a fictional dirty-cache flushing transaction. Independent cached
blocks must retain exact identity and every data word.

## Executed native PDP-6 test

`daimos-p1c-write-through-cache-v1602.sh` extracts the unmodified
`d6fs_reader_commit_cache`, restore epilogue, direct `fs_backing.s`
adapter, exact root-service failure classifier, and the **complete**
`bcache_pdp6.s` source. The fixture pre-seeds an existing 0201-word MM
BCACHE lease, with a distinct preexisting clean block for a different
D6FS mount; it deliberately refuses any unexpected new MM allocation
or free. It primes the shared workspace as another valid clean key,
modifies its data, and calls the original D6FS write entry. The final
low-level adapter completion either fails or succeeds, recording whether
the original cache invalidation had preceded the physical WRITE.

All **four** cases passed: DSK270 failed WRITE, DSK270 successful
WRITE, DRM236 failed WRITE, and DRM236 successful WRITE. Each checks
the original adapter-controller selection and one attempted physical
request. The original failed operation returns -1 with the workspace
tag invalid, no clean cache publication and no selected-root halt;
a successful operation returns zero and publishes the newly committed
key with the expected transferred content. In **every** case the
private cache entry keeps its original key, complete 128-word contents
and successful subsequent `bcache_fetch` readback.

Five **executed** deliberately unsafe source changes were rejected:
skip prewrite invalidation; invalidate unrelated private clean slab;
forge failed authoritative WRITE as success; misclassify secondary
mount as selected root; and publish a valid clean cache key after
failed backing I/O. An initial proposed bypass of the owner classifier
was behaviorally equivalent for a *secondary* mount (both returned
-1), and was replaced with a genuinely unsafe false-publication
mutation; that diagnostic was never counted as a rejected mutant.

Final successful native run (including all 0200 private data words):
`$TMPDIR/daimos-p1c-write-through-v1602.zCG0oI`, final runner output
`$TMPDIR/daimos-p1c-write-through-v1602-run5.log`.

Reproduce:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1602_KEEP_WORK=1 sh \
  tests/validation/daimos-p1c-write-through-cache-v1602.sh
```

This result complements but does **not** replace existing authentic
physical v1545 secondary DSK/DRM media-loss tests, v1590 live D6FS
cache during an actual LOGSTORE torn physical WRITE and retry, v1596
high DTFS loss with independent MEMFS writes, and v1599/v1600 fatal
BACKSTORE PI2 while two genuine PI6 owner wakes are in progress.
Loaded whole-guest PI6/cache repeatability must be accepted separately
before claiming final P1-C feature closure. No production code,
resident data, ABI, allocator or media-format modification is made.

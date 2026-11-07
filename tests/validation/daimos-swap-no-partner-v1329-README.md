# v1329: source-authentic, pinned-resident 256K PDP-6 guest

The previous test-only owner reservations were attempted late,
after all 18 additional 24K-word pressure children had been
admitted. Both v1322 (8K words) and v1323 (1K words) failed their
**owner admission** (`!t`) with no swap-in MM allocation failure or
no-partner cooldown. A guest that has no free APR-aligned extent
cannot allocate even an additional synthetic kernel-dynamic owner;
repeatedly reducing the reservation does not test swap-in recovery.

This versioned v1329 guest instead uses the separately committed
testkit v1326 source injector. The injector exercises actual PDP-6
`mm_pin` on resident process extents, excluding the requester; the
real MM allocator and swap service must determine whether they can
reclaim or exchange any remaining eligible resident process. INIT
remains a real runnable process and later calls production `mm_unpin`
after its clock-driven wait. The original process, provider, BRK OOM,
storage-mode, swap and final accounting checks are not replaced.

The full-guest wrapper invokes v1326's original disposable source
generation unchanged, then switches its host-only read-only SIMH
sampler from v1324 to v1326. The latter removes simulator `sim> `
prompts from both the running guest's milestone text and post-HALT
examine records, preserving all raw PTY bytes in a separate log;
it does not fabricate any kernel result.

Preflight without launching SIMH:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
make test-daimos-swap-physical-pinned-v1329-preflight \
    DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
```

Full 256K guest:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export KEEP_TEST=1 DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-swap-no-partner-fullguest-v1329.sh
```

`v1303` strictly rejects absent or fabricated typed allocator
failure, unbalanced cooldown/exchange, unfinished guest or nonzero
backing counts. If no genuine no-partner event occurs, the wrapper
reports **NOT EXERCISED**, not an acceptance. If a guest milestone
or resource cleanup fails, the wrapper exits nonzero. All source
changes are confined to the disposable guest build; production
KCORE/MRES footprint and the rejected v1208/v1211 swap fallback
remain unchanged.

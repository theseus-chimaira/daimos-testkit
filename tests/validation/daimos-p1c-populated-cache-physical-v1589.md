# P1-C v1589: original populated D6FS cache reclaimed during physical swap

Date: 2026-11-15. Two genuine 128K KCC PDP-6 cold boots using four
real Type-236 DR0..DR3 D6FSR2 root VOLUME members, original BLOCKSET
INTERLEAVE mapped BACKSTORE, MEMFS/XIP, LOGSTORE, normal PI6 scheduling,
and the v1588 post-DMA checked-release rollback. This acceptance is
about **reclaiming an initially populated, valid D6FS cache without
stale identity or lost swap ownership**. It is NOT an acceptance of
cache-data preservation when the cache is not reclaimed.

## Genuine D6FS cache population and discovered reclaim

The test-only XIP parent launches four real, independently swapped
24K-word children and waits until they are sleeping. Immediately
before its privileged HALT request, the parent uses ordinary VFS
OPEN and two 128-word READs on `/CONFIG/XIP1469.TEST` from the
physical D6FS root. The real D6FS reader and original clean BCACHE
load a valid 0201-word MM-managed private slab. The snapshot-entry
observer copies the 128 original cache words and records the source
tag and slab address; it does not create a fake cache entry, perform
hidden provider I/O, or cross a removable module link boundary.

The first attempt to call the D6FS MRES reader directly from the
MEMFS snapshot MRES failed during the partial module link: the two
removable modules have separate symbol/link boundaries. That
experiment was discarded as a wrong test design, not worked around
by adding a production dependency. The corrected test uses normal
userland D6FS I/O and a read-only snapshot observer.

The initial two-boot cache-survival hypothesis was **rejected**.
Both physical boots had a valid D6FS private cache at snapshot entry,
but `bcache_state` was zero at the later swap-rollback boundary;
the original `bcache_fetch` correctly missed. The unchanged v1588
physical rollback and two-boot snapshot recovery still passed.

The final v1589 observer therefore follows the original
`bcache_reclaim` function and records only a call that matches the
exact previously observed slab, 36-bit D6FS source/block key, and
active snapshot. It checks **every one of the 128 real cache words
before the original invalidation**, then observes the original MM
free success or refusal. It also records the number of independently
started slot-0 swap-ins at that exact boundary. After the separate
post-DMA BACKSTORE release refusal, the original cache must be gone
and an original `bcache_fetch` of the former key must MISS, without
copying any of the previous physical payload. No MM allocator, cache
policy, scheduler, provider or controller routine is shortcut.

## Accepted original physical results

The full two-boot runner exited successfully. Each boot preserved
the first boot's complete media across a fresh CPU/RAM restart;
the second boot restored previous MEMFS/XIP data and LOGSTORE,
and appended/read a new LOGSTORE record. Both native privileged
HALTs were normal at octal `022004`.

| Original linked witness | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Original MM-backed BCACHE private slab | `0307577` | `0307577` |
| Original 36-bit D6FS source/block tag | `100100001010` | `100100001010` |
| Nonzero words in exact 128-word physical D6FS block | 28 | 28 |
| Actual original BCACHE reclaim matched that owner/key | 1 | 1 |
| Independent slot-0 swap-ins already started at reclaim | 1 | 1 |
| Differences in all 128 cache words BEFORE reclaim | 0 | 0 |
| Actual original BCACHE/MM free succeeded | 1 | 1 |
| Original BCACHE/MM free refused | 0 | 0 |
| Original BCACHE reclaim left in flight | 0 | 0 |
| Old private source returned a HIT after reclaim | 0 | 0 |
| Cache slab owned at separate post-DMA rollback boundary | 0 | 0 |
| Controlled v1588 checked-release refusal | 1 | 1 |
| Original process MM rollback extent count | 20 to 19 | 20 to 19 |
| Real mapped physical swap READs | 4 | 4 |
| Matching Type-236 swap READ PI2 completions | 896 | 896 |
| Successful DISK-to-RESIDENT publications | 3 | 3 |
| Original process swap ownership across rollback | `01650` unchanged | `01650` unchanged |
| Original BACKSTORE bitmap words changed | 0 of 29 | 0 of 29 |

The independent physical oracle verifies the valid MEMFS v2 commit
header at DR3 sector `017777`, a 3,648-word pool, 282 other nonzero
BACKSTORE sectors and the unchanged four-member D6FSR2 layouts.
The v1589 cache verifier rejects 14 false tag, owner, data,
reclaim, scheduling and stale-hit witnesses. It also reruns the 34
inherited physical/swap/MM/BCACHE rollback negative controls from
v1588: **48 intentionally corrupted cases rejected in total**.
The original v1588 physical rollback oracle independently rechecks
successfully on the same retained media and transcripts.

## Scope and remaining P1-C

This is real D6FS cache data loaded via VFS, and a real original
BCACHE reclaim/MM free during independent PI6 scheduling. The
post-DMA checked BACKSTORE release refusal remains test-induced,
not a naturally damaged disk. Original owned-BACKSTORE physical
errors continue to take the mandatory fatal path. Cache contents
are validated immediately before their **legitimate MM reclaim**;
they are not claimed to survive once the original kernel has
relinquished the slab. The independent post-read rollback then
preserves the process's DISK record, authoritative backing owner and
all bitmap words without resurrecting old D6FS cache data.

P1-C remains OPEN for a case where an actually populated BCACHE
entry remains allocated through an unrelated provider rollback,
simultaneous owner transitions, mixed provider faults and the
outstanding loaded-timing/repeated-run stability observation.
P1-D/E, VERSION 0.5, original production KCORE end `024364` octal
and strict 32K/optimization HOLD remain unchanged. All cache and
rollback instrumentation is confined to disposable test kernel
copies and opt-in userland; production RAM, ABI and disk layout
do not change.

One legacy `daimos-bcache-reclaim-io-v1490.sh` native fixture remains
separately blocked at link: its extracted DTFS DTC write veneer now
references the source-authentic `dtfs_intent_mount_gate_v1561` that
the old standalone fixture does not include. No stub or bypass of
the production gate was added. Repair of that legacy test setup is
separate from the accepted v1589 full-guest evidence.

Retained physical evidence:
`$TMPDIR/daimos-p1c-populated-cache-v1589.LkkpE8`, including both
post-HALT transcripts, all four drum members, original KCORE map
and `v1589-physical-verification.txt`.

Reproduce from daimos-testkit:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
V1589_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-populated-cache-physical-v1589.sh
```

# P1-C v1590: live D6FS clean cache across physical LOGSTORE refusal/retry

Date: 2026-11-15. This test accepts the previously missing case of
an **allocated, valid, populated D6FS private BCACHE entry remaining
unchanged** during a recoverable operation by a different provider.
It then retains the independent physical v1588 BACKSTORE swap/MM
rollback and the two-boot MEMFS/LOGSTORE persistence proof.

## Original components and physical workload

Each boot is a complete 128K KCC PDP-6 running original KCORE,
four real Type-236 DR0..DR3 D6FSR2 VOLUME members, BLOCKSET
INTERLEAVE mapped BACKSTORE, D6FS, MEMFS v2/XIP and LOGSTORE.
The optional XIP userland guest uses ordinary VFS OPEN and two
128-word READs from the real root `/CONFIG/XIP1469.TEST` immediately
before LOGSTORE APPEND. This populates the original D6FS private
BCACHE slab through the actual physical filesystem reader. It does
not invent cache data, cache tags, provider callbacks or a mock
hardware completion. The observed original BCACHE slab is `0377577`
octal and its valid SOURCE12,,BLOCK24 D6FS key `100100001010`.

The disposable test kernel retains the source-authentic v1577
LOGSTORE torn-record fault injector. On the first eligible append,
the original LOGSTORE write path performs an actual mapped Type-236
write to the original physical LOGSTORE slot with its commit trailer
cleared, restores the user's original scratch and returns a
**test-induced** completion error. The original LOGSTORE producer
must NOT advance its cursor. The caller examines the real physical
uncommitted record via LOGCTL, then retries the same slot and reads
back its successfully committed record.

The v1590 observer captures the real original private cache tag,
MM slab owner and all 128 36-bit data words at the original first
eligible append. Immediately after the actual failed physical
write and immediately after the successful same-slot retry, it
compares the original cache slab, tag and every one of those 128
data words. Both times it additionally calls original `bcache_fetch`
into an independent test scratch block and compares all 128 fetched
words. An original cache HIT is mandatory in each case, proving the
valid cache entry was neither silently invalidated nor reclaimed.

Only after this mixed-provider transaction does the guest create
four genuine 24K-word children, wait for real SLEEP and issue its
privileged HALT. During the snapshot the original PI6 timer wakes
an independently selected DISK-backed child. The original slot-0
swap-in completes its actual mapped BACKSTORE READ and Type-236 PI2,
then the separately controlled v1588 checked-release refusal invokes
original MM rollback, retaining exact DISK owner and bitmap. This
later memory-pressure phase may legitimately reclaim the clean cache;
v1590 does **not** demand its retention through that distinct phase.

## Accepted two-cold-boot evidence

The full runner `daimos-p1c-live-cache-logfault-physical-v1590.sh`
exited zero after two separate CPU/RAM boots against the same four
original physical members. Both original privileged HALTs occurred
normally. The second boot restored the first boot's MEMFS/XIP data
and previous LOGSTORE record before producing its next record and
new snapshot.

| Linked original/test observer | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Valid populated D6FS private cache at LOGSTORE append | 1 | 1 |
| Nonzero words of all 128 actual cached data words | 28 | 28 |
| Genuine physically written uncommitted LOGSTORE record | 1 | 1 |
| Failed-append cache witness observed | 1 | 1 |
| Committed same-slot retry cache witness observed | 1 | 1 |
| Cache tag/slab/full-data changes at failed append | 0 | 0 |
| Cache tag/slab/full-data changes after committed retry | 0 | 0 |
| Original BCACHE fetch after torn physical write | HIT | HIT |
| Original BCACHE fetch after committed retry | HIT | HIT |
| Differences in both full 128-word fetched blocks | 0 / 0 | 0 / 0 |
| Independently scheduled physical BACKSTORE READs later | 4 | 4 |
| Matching real Type-236 swap READ PI2 completions later | 896 | 896 |
| Successful RESIDENT publications later | 3 | 3 |
| Changed original BACKSTORE bitmap words across rollback | 0/29 | 0/29 |
| Process-owned DISK backing blocks retained on refusal | `01650` | `01650` |

The independent host verifier checks original KCORE linked symbols,
post-HALT transcripts, raw four-member physical media and the inherited
two-boot v1588 MM/owner/PI2/snapshot checks. The valid persistent
MEMFS v2 commit header is at DR3 physical `017777`, with a 3,648-word
MEMFS pool and 280 other nonzero physical BACKSTORE sectors.
Boot 2's original LOGSTORE scan confirms the previously committed
record and its new
same-slot retry commits another record. The verifier rejects **47
deliberately corrupted witnesses**: 13 v1584 physical/PI/scheduling,
21 v1588 MM/backing/BCACHE ownership and 13 new v1590 live-cache,
physical-torn, failure/retry and full-data/fetch controls.

The separate legacy v1490 source-linked BCACHE/DTC native regression
was repaired earlier in v1590 by linking the **authentic** production
DTFS write-intent gate instead of supplying an artificial success
stub; its positive and two mutation negatives pass independently.

## Limits and outstanding P1-C

The physically uncommitted LOGSTORE block write is genuine; only its
return as a completion error is test-induced. This is **not** proof of
recovery from an actual owned-BACKSTORE controller failure. Owned
BACKSTORE physical I/O failure remains fatal under the original
v1541/v1586 policy. BCACHE data is proven live and unchanged during
the mixed D6FS/LOGSTORE failure/retry *before* the later swap MM
pressure, not throughout the separate post-DMA swap rollback.

P1-C remains OPEN for simultaneous independent owner transitions,
later-position provider/media failure timings and loaded-simulator
repeatability including the isolated v1585 timeout. P1-D/P1-E remain
OPEN. Production KCORE code/RAM/ABI/disk format is untouched;
VERSION 0.5, original KCORE low end `024364` octal and strict 32K/
optimization HOLD remain unchanged. All probes are disposable test
kernel sources and explicitly enabled opt-in userland.

Retained evidence:
`$TMPDIR/daimos-p1c-live-cache-logfault-v1590.jhggKy`, especially
`v1590-physical-verification.txt`, `v1590-negatives-output.txt`, both
SIMH post-HALT transcripts, linked KCORE map and physical DR images.

Reproduce in daimos-testkit:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
V1590_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-live-cache-logfault-physical-v1590.sh
```

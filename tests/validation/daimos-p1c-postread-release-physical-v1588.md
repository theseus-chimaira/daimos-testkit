# P1-C v1588: recoverable post-DMA checked-release refusal during PI6 snapshot

Date: 2026-11-15. Two full physical 128K KCC PDP-6 cold boots using
the original four-member DR0..DR3 Type-236 D6FSR2 root VOLUME,
BLOCKSET INTERLEAVE, mapped BACKSTORE, MEMFS v2/XIP and LOGSTORE.
An independently scheduled swap-in completes its actual mapped
BACKSTORE READ and MM unpin, then a disposable one-shot provider
refusal tests the original post-I/O rollback before the disk owner
or RESIDENT state is published. This is a **controlled checked-release
refusal**, not a physical media failure, and is distinct from the
v1587 pre-I/O MM-pin refusal.

## Original transaction and injection boundary

The runner `daimos-p1c-postread-release-physical-v1588.sh` makes
a disposable copy of the production kernel and adds source-authentic
v1584 independent swap/Type-236 PI2 observers and the v1585 PI6
timer wakeup. Four original 24K-word private children become
nonresident with genuine backing ownership. The test re-times one
existing sleeping DISK process to the next original 60 Hz clock tick
at MEMFS snapshot entry, without forcing process RUN, scheduler
selection, swap-in calls or physical DMA completion. The original
PI6 timer and slot-0 service independently restore it.

The v1588-only source observer is armed at snapshot entry. It selects
the first original slot-0 swap-in for which the physical mapped
BACKSTORE READ succeeded **and the real MM unpin completed**.
Immediately before the checked release it snapshots the allocated
MM extent, process DISK record/mode, complete original backing bitmap,
original process ownership, BACKSTORE count and BCACHE metadata.
Exactly once, the original `backstore_free` provider entry returns a
*test-induced* refusal before changing its bitmap. All other calls
use the unchanged original provider. The original
`proc_swap_in_free_fail` then executes original `mm_free`, clears
the `TRANSITION` bit, leaves the DISK owner intact, and normally
reports refusal to the scheduler, which issues the TERM event.
The test compares the same state immediately after cleanup, before
later process termination can legitimately discard disk ownership.

The observer reuses the previously accepted exact 29-word bitmap
comparison, in a **new v1588 namespace**, and checks the newly
allocated VM base is absent from the true MM extent table. Its
temporary bitmap copy is 64 words maximum. All instrumentation
and additional words exist only in disposable test kernel sources,
never production KCORE. No production source, RAM footprint, ABI,
disk format or scheduler policy changes are required.

## Two complete physical cold-boot results

The full runner exited zero after two independent CPU/RAM boots
against the same original physical DR0..DR3 media. Both native
privileged HALTs reached octal `022004` normally, rather than the
fatal BACKSTORE HALT, and original logical storage errors remained
zero. Boot 2 restored the first boot's persistent MEMFS XIP/data
and previous LOGSTORE record, then appended/read back the next.

| Original linked witness | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Selected original PI6 wakeup | 1 | 1 |
| Checked release refusals after real DMA | 1 | 1 |
| Original post-unpin MM rollbacks | 1 | 1 |
| Original TERM notifications for failed owner | 1 | 1 |
| Independent slot-0 swap-ins entered | 4 | 4 |
| Actual completed mapped BACKSTORE READ requests | 4 | 4 |
| Genuine matching Type-236 swap READ PI2 completions | 896 | 896 |
| Actual successful resident publications | 3 | 3 |
| Original MM extent count, before/after failure | `024` / `023` | `024` / `023` |
| Newly allocated aligned physical VM base | `0220000` | `0220000` |
| New extent remaining after original MM free | 0 | 0 |
| Process swap blocks owned before/after failure | `01650` / `01650` | `01650` / `01650` |
| Original BACKSTORE blocks allocated before/after | `01734` / `01734` | `01713` / `01713` |
| Original 36-bit bitmap words examined | 29 | 29 |
| Changed original BACKSTORE bitmap words | 0 | 0 |
| DISK record and process descriptor fields | preserved | preserved |
| TRANSITION bit, authoritative storage mode | cleared, DISK | cleared, DISK |
| BCACHE slab pointer/workspace/private tags | unchanged | unchanged |

Each physically valid v2 snapshot commit header resides at DR3
sector `017777` on the same four-member root with a real 3,648-word
MEMFS pool and 275 other nonzero BACKSTORE sectors. All on-drum
D6FSR2 member descriptors remain intact. The independent oracle
`daimos-p1c-postread-release-verify-v1588.py` reads the actual linked
KCORE map, both original post-HALT transcripts and every physical
36-bit member file, and rejects **34 deliberately falsified**
physical/PI/MM/bitmap/owner/record/mode/BCACHE witnesses (13
inherited from v1584, 21 new post-DMA controls). The retained
accepted v1587 MM-pin rollback and v1586 real physical fatal
swap-READ fault regressions also independently PASS.

## Exact limits and remaining P1-C

The physical swap READ and matched Type-236 PI2 are genuine, but the
checked release refusal is deliberately returned at the original
provider entry before its bitmap mutation: the test does not claim
a spontaneously corrupted BACKSTORE bitmap or a natural checked
release failure. Actual owned-media I/O faults continue to take
the mandatory fatal path. It does not demonstrate restored BCACHE
*data* following a filled cache slab: the observed slab pointer is
zero and the workspace tag is invalid. Only exact unchanged BCACHE
metadata is checked across this particular transaction.

P1-C remains OPEN for mixed provider/BCACHE data and valid-tag
cases, simultaneous owner transitions, later-sector failure timing,
and repeated-load stability (including the isolated v1585 timeout).
P1-D/P1-E are unchanged, VERSION 0.5 and the strict 32K/optimization
HOLD remain in force; production fixed KCORE end remains `024364`
octal.

Retained accepted evidence:
`$TMPDIR/daimos-p1c-postread-rollback-v1588.qWn8Gy`, including
`v1588-physical-verification.txt`, both SIMH transcripts, original
linked symbols and the physical disk images.

Reproduce from daimos-testkit:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
V1588_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-postread-release-physical-v1588.sh
```

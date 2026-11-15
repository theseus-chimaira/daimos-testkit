# P1-C v1587: recoverable MM-pin rollback during physical PI6 snapshot overlap

Date: 2026-11-15. Full-profile 128K KCC PDP-6, four actual Type-236
DR0..DR3 D6FSR2 root VOLUME members, original BLOCKSET interleaving,
mapped BACKSTORE, MEMFS v2/XIP, LOGSTORE and independent PI6/slot-0
swap scheduling. This is acceptance of a **controlled pre-I/O MM-pin
refusal and original transaction rollback**, NOT post-I/O recoverable
BACKSTORE failure or reconstruction of a modified BCACHE data block.

## Actual original kernel path

The disposable v1587 test kernel reuses the exact source-authentic
v1584 physical swap observer and v1585 independent timer/PI6 wakeup.
The real guest creates four 24K-word private processes with positive
original disk ownership. Their long timed SLEEP is observed before
the original privileged HALT starts MEMFS snapshot shutdown. A
disposable snapshot hook aligns one already sleeping, nonresident
child's existing deadline with the next real 60 Hz PI6 clock tick;
it never sets RUN, enters a run queue, calls swap-in or manufactures
a PI request or DMA completion.

After the original PI6 service wakes that process and the original
slot-0 scheduler invokes `proc_swap_in`, original MM performs a real
aligned process extent allocation. The test rejects **exactly one
subsequent MM pin** with synthetic `MM_ERR_BUSY` (-5), before any
physical swap READ for that refused restore. This is a deliberately
controlled test failure, NOT a real hardware/MM pin overflow. The
unmodified original `proc_swap_in_pin_fail` handler must use the
original `mm_free`, discard its result local, clear `TRANSITION`,
return a nonfatal refusal and leave original DISK ownership intact.
Original slot-0 scheduling must issue the normal TERM event. Other
swapped processes can still be restored, and the same snapshot
must finish correctly; no direct fatal BACKSTORE HALT is acceptable.

The v1587 original transaction observers record values immediately
after the successful MM allocation but before the refused pin, and
again immediately after original `mm_free` and transition unlock,
**before subsequent TERM process cleanup can legitimately change
backing ownership**. They record the complete BACKSTORE bitmap
bit-for-bit (up to 64 test-only words, 29 used in this configuration),
original MM extent count, exact allocated base and absence from the
post-rollback extent table, original packed disk backing record word,
original process descriptor words, counters, authoritative DISK
storage-mode check, BCACHE slab pointer, workspace and private tags.
The original BCACHE implementation, MM allocator/free, BACKSTORE
bitmap and process storage-mode implementation are unmodified.

## Accepted two-boot results

Two full 128K PDP-6 cold boots completed original privileged HALTs
at `022004` octal on the same physical four-member Type-236 root;
the second boot used fresh CPU/RAM, recovered MEMFS/XIP and the
previous LOGSTORE record, then appended a new record successfully.

| Original linked witness at transaction boundary | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Selected independently woken process slot | 6 | 6 |
| One controlled MM pin refusal | 1 | 1 |
| Original completed MM rollback | 1 | 1 |
| Original normal TERM event for selected slot | 1 | 1 |
| Newly allocated aligned MM base | `0220000` | `0220000` |
| Original MM extent count before/after | `024` / `023` | `024` / `023` |
| Allocated base still present after real MM free | 0 | 0 |
| Original process swap blocks before/after | `01650` / `01650` | `01650` / `01650` |
| BACKSTORE blocks used before/after | `01734` / `01734` | `01713` / `01713` |
| Exact BACKSTORE bitmap words compared | 29 | 29 |
| Changed backing bitmap words | 0 | 0 |
| Original DISK record and other process words | unchanged | unchanged |
| Process transition bit | cleared | cleared |
| Original authoritative storage mode | DISK | DISK |
| Original BCACHE slab pointer/two cache tags | unchanged | unchanged |

The original post-HALT physical oracle additionally confirms four
independently selected swap-in starts and **three successful
DISK-to-RESIDENT publications** per boot, with 672 matching original
Type-236 PI2 DR_DONE swap READ completions per boot. Thus the one
refused MM pin does not prevent the other physical restore requests.
The original logical storage error count remains zero. The valid
MEMFS v2 commit header is physically DR3 sector `017777`, the actual
MEMFS pool is 3,648 words, 275 other backing sectors contain nonzero
physical data, and the four D6FSR2 member layouts remain intact.

`daimos-p1c-pin-rollback-verify-v1587.py` independently reads the
real linked KCORE map, both post-HALT guest transcripts and four
original 36-bit physical drum members. **33 false evidence variants
were rejected**: 13 original physical/swap/PI2/commit negative
controls inherited from v1584, and 20 new MM, owner, bitmap, process,
TERM, DISK mode and BCACHE-metadata mutations. The v1585 strict
two-boot physical overlap and v1586 physical fatal swap-READ fault
oracles still independently pass on their retained real data.

## Limits and remaining P1-C work

Only the MM pin failure return is test-synthetic. This is not a
natural MM-pin saturation event and does not alter production
process lifetime, kernel source, MM data structures or BCACHE.
The BCACHE metadata equality checks prove the pre-I/O failure does
not damage those three metadata words; they **do not** prove
restoration of corrupted/partially-written BCACHE data after real
physical I/O. The exact backing bitmap is compared immediately at
the rollback boundary, before ordinary process TERM cleanup.

P1-C remains OPEN for post-I/O recoverable transactional owner/MM/
BCACHE rollback, multi-stage restore failures, simultaneous owner
changes and the v1585 intermittent timeout stability investigation.
Active/owned BACKSTORE physical I/O faults intentionally fail-stop
under the v1541 policy and cannot be turned into recoverable errors
by an alternative path. P1-D/E, VERSION 0.5 and strict 32K/
optimization HOLD remain unchanged. The production fixed KCORE low
end remains `024364` octal, with no production RAM/ABI growth.

Source-authentic test-only instrumentation and executable runner:
`daimos-p1c-pin-rollback-v1587.py`,
`daimos-p1c-pin-rollback-physical-v1587.sh` and
`daimos-p1c-pin-rollback-verify-v1587.py`, all in daimos-testkit
`tests/validation/`. Accepted retained original four-member physical
evidence: `$TMPDIR/daimos-p1c-mm-pin-rollback-v1587.b37MyN`.

Reproduce:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
V1587_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-pin-rollback-physical-v1587.sh
```

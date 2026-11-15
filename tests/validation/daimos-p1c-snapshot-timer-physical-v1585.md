# P1-C v1585: independent PI6 swap-in overlaps physical MEMFS snapshot

Date: 2026-11-15. Full 128K KCC PDP-6 guest, original four-member
Type-236 root VOLUME and mapped BACKSTORE. The real PI6 timer service,
the original slot-0 scheduler, real BACKSTORE READ/DRM236 DR_DONE PI2,
actual DISK-to-RESIDENT publication, original MEMFS snapshot WRITE and
subsequent complete cold-boot restore were all observed together.

## Controlled external scheduling, not a synthetic swap call

`daimos-p1c-snapshot-timer-physical-v1585.sh` makes a temporary copy
of the actual production kernel and assembles the source-authentic
v1584 observers with the additional v1585 timer instrumentation.
The two cold boots load identical, unmodified production KCORE and
MRES logic except for opt-in disposable instrumentation. The backing
images are the four genuine DR0..DR3 8,192-sector Type-236 D6FSR2
members, connected by production BLOCKSET INTERLEAVE. Both boots use
the same physical images, with fresh CPU/RAM and no rebuild between.

The original v1580 user program starts four large private processes
and verifies all four reach genuine long timed SLEEP. The real
`proc_swap_blocks_used` must be positive when privileged snapshot
shutdown begins. Exactly once, the test-only v1585 snapshot entry
scans original process descriptors for a timer-tagged **sleeping,
nonresident, disk-backed** process, and updates only that process's
original timer deadline to the next 60 Hz clock tick. It also updates
the existing nearest-timer frontier if appropriate. **It never calls
`proc_swap_in`, changes the process to RUN, adds it to the run queue,
issues a PI request or simulates a controller completion.** The
original independent hardware PI6 timer must mark the expired child
runnable and the original scheduler/slot-0 swap service must then
restore it by genuine Type-236 physical I/O.

The v1584 original-driver source observers separately record genuine
slot-0 swap-in starts, original completed DISK-to-RESIDENT publishes,
real mapped swap READ calls, matching actual DRM236 DR_DONE PI2
completions, and all snapshot-window DR_DONE completions. The v1585
observers record one timer arm, original PI6 timer wake, selected
sleeping slot, and elapsed original 60 Hz scheduler ticks. Original
post-HALT memory is examined with SIMH against linked KCORE symbols;
the host oracle independently validates both transcripts and the
four actual 36-bit physical media files.

## Accepted physical results

| Original post-HALT witness | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Timer armed | 1 | 1 |
| Actual original PI6 timer wake | 1 | 1 |
| Selected sleeping disk-backed slot | 6 | 6 |
| Original independent slot-0 swap-ins | 2 | 2 |
| Actual DISK-to-RESIDENT publications | 2 | 2 |
| Genuine mapped swap READ requests | 2 | 2 |
| Matched original DRM236 swap READ PI2 completions | `0700` | `0700` |
| All original snapshot-window DRM DR_DONE PI2 | `01311` | `01311` |
| Snapshot elapsed original clock ticks (decimal) | 2,129 | 2,137 |
| Remaining original `proc_swap_blocks_used` (octal) | `0750` | `0750` |
| Remaining original BACKSTORE blocks used (octal) | `01034` | `01013` |
| Original snapshot active/descriptor/read marker after HALT | 0 | 0 |

The surviving process swap ownership is original
`proc_swap_blocks_used=0750` octal at both HALTs, whereas the
original `backstore_blocks_used` is `01034` and `01013` respectively.
The latter counts both active backing allocation and snapshot
reservation, and falls when swapped processes are actually restored.
The original KCORE `mfsdev_storage_errors` counter is zero at each
HALT. Both original normal privileged HALTs occur at octal `022004`.

Boot 2 physically restores the previous MEMFS/XIP data and previous
LOGSTORE record, then appends and reads a new record. After its new
snapshot the independent raw-media oracle finds the valid v2 MEMFS
commit header at **DR3 physical block `017777`**, real 3,648-word
MEMFS pool, 275 other nonzero BACKSTORE sectors, valid original
`075774` octal VOLUME data span/`02000` tail capacity, and intact
four D6FSR2 member layouts. No backing/controller redirection is
faked by the test.

The strict independent `daimos-p1c-snapshot-timer-verify-v1585.py`
oracle accepts both boots only if the original physical snapshot
recovery, PI6 timer wakeup, genuinely selected slot-0 restore,
matching original DRM PI2 and successful swap-in publication ALL
occur during the same real shutdown window. The test rejects 17
deliberately corrupted evidence variants: 13 inherited v1584 physical
PI/ownership/media/restore controls and four new PI6 timer controls.
The v1584 verifier was corrected to use the strict overlap contract
when its original two-boot evidence really has positive completed
overlaps. The earlier healthy v1584 baseline (both overlap counts
zero) remains accepted and strict mode still rejects its claimed
overlap. This fixes a real negative-test oracle defect rather than
loosening the v1585 acceptance.

## Scope and outstanding P1-C

The timer deadline is **deliberately advanced** at the snapshot
boundary in a disposable guest; thus this test proves the original
independent scheduler and controller overlap under controlled
timing, not the probability of two unrelated natural deadlines
coinciding. The original scheduler, swap I/O, PI2 completion and
publication remain authentic and were not shortcut. Neither an
actual hardware-media failure *during* this overlapping workload,
nor exact recoverable owner/MM/BCACHE transaction rollback is
asserted by this test. P1-C remains OPEN for these combined/failure
cases. P1-D/P1-E, VERSION 0.5 and the strict 32K optimization HOLD
remain unchanged. No permanent production KCORE/source/RAM/ABI or
persistent disk-format change is made.

Retained first accepted physical evidence:
`$TMPDIR/daimos-p1c-snapshot-timer-v1585.hfCA5o`, including
`v1585-physical-verification.txt`, the original post-HALT transcripts,
four on-media D6FSR2 members, and all linked KCORE symbols.

### End-to-end rerun and bounded timeout observation

After correcting the strict-negative oracle, one independent rerun
exceeded the earlier 180-second command probe during its first
snapshot. Its raw physical backing files had an invalid commit header
and partial writes, as expected before an incomplete shutdown, but
there was no captured CPU-state evidence establishing whether the
cause was unusually slow simulator execution or a genuine scheduling
stall. This run is **not** counted as an acceptance pass and is not
claimed to have identified a production bug.

A subsequent complete source-identical two-boot rerun, with optional
SIMH timeout CPU/PC capture enabled, succeeded end to end under the
original 180-second limit. Original PI6 wakeups=1, independent
swap-in starts/publications=2/2, and matching PI2=448 on **each**
boot; observed clock durations 2,136 and 2,140 ticks respectively.
The full testkit runner, including all 17 negative controls, exited
zero. Retained fully passing runner evidence:
`$TMPDIR/daimos-p1c-snapshot-timer-v1585.xYkqo8`.

Because this workload performs hundreds of additional real drum DMA
completions, the v1585-only command budget has been increased to a
bounded 300 seconds with CPU/PC capture on timeout; the older test
budgets remain unchanged. This is test harness scheduling tolerance,
NOT a workaround or production change. Additional repeated-load
stability trials and fault/overlap combinations remain worthwhile;
the single bounded timeout does not establish the absence of a
timing-sensitive bug.

Reproduce from daimos-testkit:

```
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export TMPDIR=${TMPDIR:-$HOME/tmp}
V1585_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-snapshot-timer-physical-v1585.sh
```

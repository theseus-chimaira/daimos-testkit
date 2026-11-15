# P1-C v1592: genuine two-owner PI6/swap overlap with isolated rollback

Date: 2026-11-15. Two full 128K KCC PDP-6 cold boots on real D6FS
root VOLUME composed of four Type-236 DR0..DR3 physical members,
original BLOCKSET INTERLEAVE mapped BACKSTORE, MEMFS v2/XIP and
LOGSTORE. This is a physical owner-concurrency acceptance slice,
not production scheduler code. All source instrumentation lives
in a disposable kernel copy.

## Experiment and original process boundaries

The accepted v1584 instrumentation marks the original synchronous
MEMFS snapshot and independently scheduled slot-0 swap-in entries;
v1585 originally retimed one real sleeping disk-backed process to
the next timer tick; v1588 returned one controlled checked-release
refusal after a real swap READ, MM pin/unpin and genuine Type-236
completion. v1592 extends only the **test-only timer observer** to
select **two distinct** original SLEEP/timer-tagged/VM-on-DISK
descriptors with positive original backing records. It retimes
both to the next original PI6 clock tick and preserves the existing
frontier. It neither changes their state nor manually queues RUN,
starts swap service, injects PI6 or supplies disk completion.

The original `proc_timer_service` independently increments a
per-slot witness for each real PI6 wake during the snapshot. The
v1588 source-linked post-DMA selected release refusal operates on
one actual independently scheduled swap-in; original MM frees the
new extent, preserves the DISK record, bitmap, stable u-area and
storage mode, clears TRANSITION and delivers TERM. Other genuine
swap-ins continue on the original scheduler.

## Physical results

Full original two-cold-boot runner and independent verifier PASS.
Both boots executed the original privileged nonfatal HALT, and the
second boot restored first-boot persistent MEMFS/XIP/LOGSTORE before
performing its own snapshot. Exact original physical D6FSR2 member
descriptors and mapped v2 snapshot header DR3 `017777` were checked;
the committed persistent MEMFS pool is 3,648 words, with 277 other
nonzero backing sectors.

| Actual independent source-linked observation | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Original timed, sleeping DISK slots selected | 6 and 7 | 6 and 7 |
| Actual PI6 timer-service wakes (slot 6 / slot 7) | 1 / 1 | 1 / 1 |
| Selected failed post-DMA owner | 6 | 6 |
| Controlled checked BACKSTORE release refusals | 1 | 1 |
| Original MM rollback completions | 1 | 1 |
| Original TERM notifications | 1 | 1 |
| Original full bitmap differences after failure | 0 | 0 |
| Original independent slot-0 swap-ins started | 5 | 5 |
| Original physical mapped swap READs | 5 | 5 |
| Genuine matching Type-236 swap READ PI2 | 1,120 | 1,120 |
| Other successful DISK-to-RESIDENT publications | 4 | 4 |

The original v1588 rollback captures exact process/record state,
MM extent release, preserved `PROC_TRANSITION` semantics, 29-bitfield-
word backing bitmap comparison and BCACHE metadata. The v1592
verifier checks all these critical invariants against original
linked addresses, not offsets guessed from an older binary.

The strict `--self-test` independently rejects **16** false
v1592 PI6/owner/rollback/bitmap/TERM witnesses, and the inherited
v1584 physical verifier rejects **13** false mapped snapshot,
member-layout, scheduler and PI2 witnesses: **29 negative cases**.
No original kernel source, MRES, RAM, ABI or media format changed.

Retained evidence:
`$TMPDIR/daimos-p1c-two-owner-v1592.Qwz8Ix`:
`v1592-physical-verification.txt`, `v1592-verifier-output.txt`, two
actual post-HALT transcripts, four physical drum members, linked
maps and full build log.

Reproduce:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1592_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-two-owner-physical-v1592.sh
```

## What this does not prove

The two selected owners are independently and physically woken, and
slot 6's checked-release failure is observed with exact rollback.
The other four aggregate RESIDENT publications are real, but the
instrumentation does not individually label the successful published
slot. It therefore does **not** prove by itself that timer-woken
slot 7 specifically published RESIDENT; that per-slot ownership
witness remains a separate targeted follow-up.

This is test-controlled recoverable checked release refusal, not an
owned-media controller error (which correctly remains fail-stop).
Remaining P1-C scope includes independently identified successful
counterpart ownership, real mixed DEVICE/VOLUME/DTFS media errors,
dirty/write-through fault paths and repeated-loaded-simulator timing
including the isolated earlier v1585 timeout. P1-D hardware inventory
and KA10-aware P1-E planning are separate. VERSION 0.5, strict
32K/size optimization HOLD.

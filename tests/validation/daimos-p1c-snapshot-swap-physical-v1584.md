# P1-C v1584: healthy mapped VOLUME snapshot and cold-boot recovery

Date: 2026-11-15. Accepted real 128K KCC PDP-6 full-guest persistence
baseline. **Independent PI-driven process swap-in during snapshot DMA
is NOT demonstrated by this test.** P1-C remains OPEN for that gate.

## Source-authentic physical experiment

`daimos-p1c-snapshot-swap-physical-v1584.sh` builds a disposable copy
of the current full-profile kernel. The original production DR0..DR3
Type-236 D6FS root, four-member INTERLEAVE BLOCKSET, mapped BACKSTORE
tail, persistent MEMFS/XIP and original LOGSTORE execute unchanged.
The ordinary XIP v1580 workload creates four independently scheduled
24K-word children with original real backing owners. V1584 alone
allows one of the children to wake periodically while the other three
retain the accepted long-sleep behavior. It never invokes swap-in or
snapshot writes directly from the children.

The v1584 disposable source observer preserves the original register
save before recording `proc_swap_in` entries that occur during the
actual `memfs_snapshot_shutdown` and are selected by the original
slot-0 scheduler. It observes the actual `backstore_read` transaction,
the true Type-236 DR_DONE PI2 matched to the live READ descriptor, and
the original successful DISK-to-RESIDENT publication. Separate snapshot
DR_DONE events are counted even when no swap-in is seen. Nine fixed
diagnostic words are added **only to the temporary kernel copy**;
production code, RAM and ABI are unchanged. The disposable snapshot
MRES also requires actual `proc_swap_blocks_used > 0` on entry.

The opt-in v1477 testkit harness extends its original snapshot
verification with a physical post-HALT witness list. Two genuinely
new CPU/RAM cold boots use the **same unchanged physical DR0..DR3
files**, with no rebuild between them. The existing MEMFS test checks
the restored XIP and data, and the real LOGSTORE test checks the
previous boot's record and a new valid append/readback.

## Accepted physical result

Both physical boots completed the original privileged HALT at octal
`021777` and retained original process swap ownership. The on-media
four-member v2 snapshot is valid after boot 2:

| Physical witness | Boot 1 | Boot 2 |
| --- | --- | --- |
| Physical snapshot DR_DONE PI2 events | `051` octal | `051` octal |
| Snapshot active after successful HALT | 0 | 0 |
| Independently scheduled swap-in starts during snapshot | 0 | 0 |
| Swap-in committed during snapshot | 0 | 0 |
| Matching swap READ PI2 during snapshot | 0 | 0 |
| Actual `proc_swap_blocks_used` at HALT | `01310` octal | `01310` octal |
| BACKSTORE blocks still owned | `01374` octal | `01374` octal |

The final header is at physical **DR3 block `017777`**, with the real
3,648-word effective MEMFS pool, and 271 other nonzero BACKSTORE
tail sectors across the four physical units. All four original
D6FSR2 member descriptors remain unchanged. Boot 2 explicitly
emits `XIP-SNAPSHOT-RESTORED` and `P1C-LOGSTORE-PREVIOUS-BOOT`.
The real native device driver recorded no `mfsdev_storage_errors`
at its examined base counter.

The independent postflight oracle
`daimos-p1c-snapshot-swap-verify-v1584.py` rejects ten corrupted
evidence variants: missing snapshot DR_DONE, active snapshot after
HALT, stale device descriptor, stale READ marker, no swap owner,
invalid VOLUME data range, unexpected storage error, missing root
VOLUME, invalid physical committed header and corrupt D6FSR2 layout.

Original accepted retained workdir:
`$TMPDIR/daimos-p1c-swap-overlap-v1584.kR7MBC`, including
`v1584-physical-verification.txt`, the two cold-boot SIMH transcripts,
physical media and linked KCORE map. The full two-boot runner exits 0.

## What remains unproved

**All three independent overlap counters were zero on both boots.**
This run must not be cited as proof of a process swap-in concurrent
with the snapshot despite the live backing owner, independent waking
child and 41 actual PI2 completions per snapshot. The optional
`--require-overlap` verifier mode correctly rejects this evidence.
The successful cold-boot recovery is the v1584 acceptance, not an
attempt to close the independent scheduling gate. P1-C also still
requires remaining exact nonfatal owner/MM/BCACHE rollback. P1-D/E,
VERSION 0.5 and the 32K/optimization HOLD are unchanged.

Reproduce from daimos-testkit:

```
DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross" \
    V1584_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-snapshot-swap-physical-v1584.sh
```

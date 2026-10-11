# D6FS staged-growth backing-I/O fault matrix (2026-10-11 v1)

**Status:** test design and source contract only; device write-fault injection
has not been implemented or executed. Do not count this as a passing fault test.

The existing `D6FSCK_TEST_FAULTS` / `D6FSCK_TEST_ABORT_WRITE` hook in
DAIMOS `tools/host/d6fsck.c` triggers after a durable *fsck repair* write.
It cannot simulate failure in the live D6FS provider. A correct harness
needs a fault hook below `fs_backing_write` (or in the SIMH disk device),
with test-controlled write number, target logical block, and a mode for
returning an I/O error versus power cutting immediately after durability.
Production builds must contain no active test-only fault state. The harness
and fault tests belong in daimos-testkit, with only the smallest necessary
upstream interface in DAIMOS.

| Fault point | Expected recovery/observable assertion |
| --- | --- |
| First zeroed/reserved data block | Write fails; original FCB size unchanged; fsck repairs any leaked map blocks |
| First allocation-map write | Write fails; no new readable EOF; no live overlapping ownership |
| Data block within existing reserved capacity | Write fails; original FCB remains; previously committed tail may have changed (not crash-atomic) |
| First data block of cross-block append | Write fails; no new EOF; no leaked live reference |
| Second data block after first succeeds | Write fails; no new EOF; old tail content may change |
| Last payload block succeeds | No EOF until successful FCB publication |
| FCB publication returns error | Outcome ambiguous: must not free possibly live blocks |
| Power loss before FCB | Old EOF must remain readable; fsck repairs orphaned allocation |
| Power loss after successful FCB | New size/data must be readable following fsck/reboot |
| Repeated writers after recovered failure | No overlapping extents, silent data loss or duplicate append |

Run each scenario on separate cloned D6FS disks. After every interrupted
image, run check-only `d6fsck`, then repair where permitted; reboot and
read exact raw words. Preserve the interrupted disk as a test artifact.
A fault while updating an already allocated tail block does not preserve
old data, so ordered V2 growth must not be represented as a transaction.

The host contract `tests/host/daimos-d6fs-staged-rollback-contract-20261011-v1.sh`
checks control-flow structure only. The existing native 444-word readback
and dual-descriptor append regressions cover successful writes only.

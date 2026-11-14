# v1557: exclusive physical Type-551 unit ownership when DTVOL2 is mounted

Date: 2026-11-14. Source-linked native PDP-6 production DTFS feature,
not a writable-volume durability acceptance.

## Original hole

The common `dtfs_dtc_write` API uses physical DECtape UNIT/BLOCK/BUFFER,
not a published VFS mount ID. Legacy DTFS historically permits two
different mount slots to refer to one physical DTC unit. That ambiguity
cannot be permitted once one of the mounts uses the DTVOL2 write-ahead
transaction and the other can write without carrying the original 72-bit
durable identity. An additional V1 mount of an existing V2 unit can
otherwise defeat the intended volume-owner association, and a second
V2 mount would be just as ambiguous.

## Actual source change

Production `dtfs_mount_unit` now calls the versioned native PDP-6
`dtfs_v2_mount_exclusive_v1557.s` immediately after verifying the
physical native RBN0 record and before publishing the VFS slot.
Under the existing serialized filesystem provider lease, the helper
scans the actual published VFS DTFS root and MM-backed media tables
by physical unit. It refuses a V2 candidate whenever ANY other
published DTFS mount references the same unit, whether V1 or V2.
It also refuses a legacy V1/zero candidate whenever an existing V2
mount references that unit. V1/V1 multiple mounts retain their
existing behavior, as do unrelated units, D6FS/TSFS roots, and
retired slots whose media slab contains stale tags.

The helper rejects a missing mount-table pointer or invalid physical
unit and changes no existing owner, slot, MM metadata, or tape block.
It adds no fixed KCORE RAM, no allocation, and no public syscall ABI.
The implementation is included in the normal optional DTFS MRES
source concatenation; no new MRES registration or exported address
is needed. Its decision is made under the provider lease so another
filesystem mount cannot be published between the check and the
existing `vfs_mount_prevalidated` call.

This invariant is a prerequisite for future per-mount first-write
identification. It does NOT authorize writes to DTVOL2; the existing
production read-only guard remains in effect and unchanged.

## Executed tests

`daimos-dtfs-v2-mount-exclusive-v1557.sh` links and executes the
ACTUAL helper on the PDP-6 with controlled VFS root/media slabs.
**26 native cases PASS, eight unsafe source mutations rejected.**
Cases include V2/V1 and V1/V2 conflict in both mount slots,
existing V2, unaffected V1/V1 mounts, other physical units,
foreign provider, retired stale V2 entries, invalid selector,
missing MM/VFS base pointers and zero mount capacity. The native
test checks that helper refusal does not mutate any mount slab.

The expanded source-linked `daimos-dtfs-v2-ro-admission-v1555.sh`
uses real host `mkdtfs` DTVOL2 and DTVOL1 physical RBN0 and
directory records and now runs **24 native mount scenarios PASS,
11 unsafe source mutations rejected**. The nine new scenarios
exercise the ACTUAL `dtfs_mount_unit` call to the versioned helper,
including V2-over-V1, V2-over-V2, V1-over-V2, later-slot
conflicts, unrelated units, retired stale tags and V1/V1
compatibility. New mutations bypassing either V2 or V1 helper
call are explicitly rejected before VFS publication.

Historical source-linked v1519 direct-mount and v1520 72-bit
identity/target-MKFS regressions PASS with empty previously
mounted VFS/MM slabs and the actual helper linked. The full
KCC generated DTFS MRES assemble/fold/link also PASS.

Reproduction from daimos-testkit:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-v2-mount-exclusive-v1557.sh
sh tests/validation/daimos-dtfs-v2-ro-admission-v1555.sh
sh tests/validation/daimos-dtfs-mount-native-verify-v1519.sh
sh tests/validation/daimos-dtfs-volume-id-v1520.sh
```

## Outstanding safety requirements

P0-B remains OPEN. v1557 removes the ambiguous physical-unit
mount association but does not yet provide a retained MM scratch
owner to the provider, mandatory v1551-v1554 DIRTY-before-data
authorization, or a sleeping exclusive final CLEAN/unmount
transaction. Current production DTVOL2 mounts are still CLEAN
and READ-ONLY; all physical data writes remain refused by the
common write veneer.

The independent hardware controller/guest partial-write,
reinsertion, replacement and cold-boot tests remain pending,
as does the removable-media exchange time-of-check/time-of-use
boundary. P0-A closed, P0-B OPEN, P1-C separate. No optimization.

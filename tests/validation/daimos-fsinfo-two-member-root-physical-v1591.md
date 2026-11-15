# P1-D v1591: real two-member TSFS root publishes eight VFS slots

Date: 2026-11-15. Full 256K KCC PDP-6 test-only acceptance against the
original, installed KCORE FSINFO, KINIT MM mount slab and native DTFS
provider. This is a distinct physical hardware/root-membership inventory
from v1532/v1533's seven-slot three-member TSFS root. No production
kernel, userland ABI, MM, driver or media-format change.

## Source-authentic setup

The v1591 opt-in flag in the reusable v578 physical TSFS harness
formats the actual test root with **two** instead of three members.
DTC0 and DTC1 contain full physical TSFS tape images; the private
DTC2 attachment is explicitly empty (zero bytes), not a stale third
member copied from the prebuilt image. The original TSFS boot scanner
discovers the two-member set and publishes its exact member mask to
KINIT. Eight available DTC transport positions plus MEMFS provide
`1 root + (8 - 2) spare DTC + 1 MEMFS = 8` VFS mount slots.

The same physical test independently formats four nonroot DTVOL1
Type-551 tape images for DTC3, DTC4, DTC5 and DTC6. The established
v1533 harness checks unique, valid 72-bit identities and attaches all
four actual transports before the PDP-6 boots. The KCC root test probe
uses the production `dsys_fsinfo`, `dsys_dtfs_mount` and `dsys_unmount`
entry points, not a simulated FSINFO or mocked provider.

## Physical observations

The original guest booted successfully, ran its PID1 test and emitted
all required ordered CTY markers:

```
FSINFOINV V1591 START
FSINFOINV V1591 CAPACITY8
FSINFOINV V1591 MOUNTED5
FSINFOINV V1591 HOLE_STABLE
FSINFOINV V1591 RETIRED
FSINFOINV V1591 PASS
```

The test checks null-record capacity `8`, real TSFS root provider 7
and public ID 1, native DTFS providers on IDs 2..5 with exact path
identities, empty slots 5..7, invalid slot 8 and 9, and stable capacity.
It retires the middle DTC4 mount while requiring the DTC6 high-ID
mount to retain ID 5; remaining mounts retire cleanly and all seven
nonroot slots become empty with an intact TSFS root.

Physical test runner exit 0; source and medium checks passed.
The original one-pass KCC compile reported an unused `rc` local in
the test-only v1591 probe. That local was removed immediately after
the run; it did not affect emitted code or any execution path. A
source-level follow-up compiler check is required before declaring
the warning-free corrected probe independently rebuilt.

Retained isolated-media evidence:
`$TMPDIR/daimos-dtfs-secondary-mounted-v1525-15821`, with CTY log,
original two physical member files, empty DTC2 and four independent
native DTFS tapes; runner log `$TMPDIR/daimos-fsinfo-v1591-run1.log`.

Reproduce:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
export DAIMOS_TSFS_PREBUILT_BUILD=$TMPDIR/daimos-v1572-operator-build-r1
sh tests/validation/daimos-fsinfo-two-member-root-physical-v1591.sh
```

## Remaining P1-D scope

The seven-slot v1532/v1533 and eight-slot v1591 physical profiles
now PASS. Source-linked v22 native disk/drum/tape root membership and
maximum nine-slot inventories already PASS. Physical alternatives
with actual D6FS disk/drum selected root and different installed
controller service sets, including provider-failure enumeration, are
still separate P1-D qualification work. Do not claim the representational
26-slot bound is a tested hardware inventory, nor invent 26 devices.

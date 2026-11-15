# P1-C v1583: physical four-member mapped snapshot PI2 fail-stop

Date: 2026-11-15. Full PDP-6 hardware-simulator integration with
real D6FS/Type-236 DR0..DR3 root VOLUME and original BACKSTORE mapping.
This is **not** a natural damaged-medium error or proof of an
independently scheduled swap-in overlapping snapshot DMA.

## Test design

`daimos-p1c-mapped-snapshot-pi2-physical-v1583.sh` builds a disposable
copy of the actual 128K full-profile KCC PDP-6 kernel and the
unchanged v1580 privileged MEMFS/XIP/LOGSTORE/swap workload. The
v1477 and v1469 testkit harnesses have a strictly opt-in
`XIP_V1583_VOLUME_DRM=1` switch to use `BOOT=drm ROOT=drum ROOTSET=1`
instead of their original disk-root/AUXSTORE setup. In this profile
the normal production mkdsk/mkd6fs recipe makes four distinct
8192-sector DR0..DR3 physical D6FS member images, a mapped BLOCKSET
BACKSTORE tail and LOGSTORE on the root set, without an AUXSTORE
descriptor. All ordinary v1477 modes are unchanged.

The disposable MEMFS MRES refuses snapshot shutdown unless original
KCORE `proc_swap_blocks_used` is positive. The accepted v1581 test
selector marks ONLY the first one-block invalid snapshot commit-header
WRITE to the final logical BACKSTORE block. It captures the actual
Type-236 DR request descriptor and redirects its genuine PI2 DR_DONE
event to the original driver PI error publication, not an artificial
gateway return. The unchanged original v1541 BACKSTORE gateway then
enters the original v1515 reason-2 HALT. The actual HALT and live
counter values are examined by SIMH after the CPU stops.

The independent `daimos-p1c-mapped-snapshot-verify-v1583.py` reads
all four raw 36-bit sector images and their D6FSR2 sector-zero
descriptors. It derives per-member physical start/usable/tail counts,
matches them to real KCORE `volume_data_blocks`,
`backing_region_count`, `backstore_blocks` and the packed D6FS root
member configuration. From the actual logical snapshot-last index it
calculates exactly which physical member and block receive that
write, then checks the selected Type-236 hardware-group address,
the physical invalid header, independent nonzero swap payload,
the original driver error accounting, retired descriptor and actual
reason-2 HALT PC. Test-only postflight descriptor byte comparison
protects every physical D6FSR2 layout. Because the guest has an
abrupt fatal HALT, `d6fsck` after the fault is permitted to report
a DIRTY superblock; requiring a clean unmount would be an invalid
acceptance assumption.

The verifier also deliberately corrupts the linked evidence,
mapping, root members and physical media to ensure the checks fail.

## Accepted evidence

One fresh source-matching full guest and all 12 independent negative
evidence controls PASS. The real CPU HALTed at original BACKSTORE
reason-2 PC octal `004011`; the actual PI2 error counter and the
original Type-236 error counter both equal `1`, the selected active
descriptor and arm are cleared, and `01374` octal process swap
blocks remain owned. Live runtime `volume_data_blocks=075774`,
`backing_region_count=02000`, `backstore_blocks=02000`,
`device_region_map=400000000000`,
`mfsdev_d6set_members=032104` and D6FS root vnode
`060101000000` prove the original mapped controller and root.

All four raw DR0..DR3 members have physical base `1`, data span
`017377`, BACKSTORE tail `0400`, last sector `017777`. The exact
snapshot-relative `01777` maps to DR3 block `017777`, Type-236
hardware group `777770` on the actual controller request. Its
physical commit header remains invalid (zero); 248 other nonzero
tail sectors attest genuine physical swap payload. Each member's
D6FSR2 descriptor remains byte-identical to its preboot value.

The 12 deliberately falsified evidence sets are all rejected:
missing selected PI2, missing production driver error, no real
owned blocks, faked direct DEVICE, incorrect VOLUME capacity, wrong
hardware group, stale descriptor, incorrect fatal PC, bad four-member
configuration, wrong root vnode, falsely committed media header and
corrupted one-member D6FSR2 descriptor. The accepted full guest
runner returned 0 and wrote `v1583-physical-verification.txt`.

Retained accepted test workspace (when using the documented
`V1583_KEEP_WORK=1`):
`$TMPDIR/daimos-p1c-mapped-snapshot-v1583.hL3hvA`.

## Limits

This is a selected artificial PI2 error branch at the end of a
*real hardware-simulator DMA*, not naturally failed physical media.
One fatal BACKSTORE HALT does not demonstrate independent scheduler
PI swap-in DURING snapshot I/O, nonfatal BCACHE/MM rollback or a
healthy VOLUME member's post-fault continuation. P1-C remains OPEN
for those acceptance cases; P1-D/P1-E are unaffected. All source
injection and diagnostic counters live in disposable copies, never
the permanent production kernel. No ABI, persistent format or fixed
KCORE/RAM change is made.

Reproduce from daimos-testkit:

```
DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross" \
    V1583_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-mapped-snapshot-pi2-physical-v1583.sh
```

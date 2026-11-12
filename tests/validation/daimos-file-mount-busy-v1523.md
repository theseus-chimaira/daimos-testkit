# DAIMOS v1523: native FILE/cwd mount lifetime admission

Date: 2026-11-12. Actual PDP-6 source-linked VFS and FILE owner
verification. This tests **KCORE** process/mount lifetimes, not a
replacement FILE subsystem or a general userland feature.

## Real production source under test

`daimos-file-mount-busy-v1523.sh` extracts actual
`file_mount_busy_v1523` from `system/kernel/fs/file_runtime.s`
and actual `vfs_unmount` and associated owner checks from
`system/kernel/fs/vfs.s`. The native PDP-6 fixture provides
genuine three-word process table records and stable u-area
layout, including cwd at 025 and sixteen two-word FILE records
from 026 through 065 (octal). It has independent current,
swapped (no user VM), and unowned processes, plus mount slots.
Only PIPE, SWAP owner-call boundaries and provider SYNC timing/
failure are controlled.

The test establishes that a mount with any current or remote
FILE/cwd reference refuses unmount without SYNC or retirement;
that FD15 and swapped-process u-areas count; and that stale
unowned u-area content does not count. It verifies a physical
SYNC refusal preserves the mount, and a remote FILE opened
during sleeping SYNC is caught by the second precommit check.
After the final owner leaves, the VFS mount is retired once
while the independent namespace root survives.

All seven deliberately unsafe *executed* source mutations
are rejected: skip FILE check, ignore remote process, ignore
cwd, omit final descriptor, recompute wrong mount ID after
PIPE for SWAP, recompute wrong ID for FILE, and omit the
post-SYNC/PREPARE ownership check. This also identifies and
corrects a real old AC2 clobber dependency.

## Other results and limits

The v1514 physical-nonroot missing-media/return VFS unmount
source-linked regression PASSES with its three unsafe
mutations rejected. The separate v1522 DTFS identity gate
already passed seven executed negative mutations.

An isolated 256K KCC tape-root kernel/image builds and links,
including the optional DTFS/TSFS provider. A controlled
identical-objects, independent-fold-plan old/new comparison
from committed v1522 changes fixed KCORE by **+54 instruction
words**, with **no new permanent DATA words**.

The full-guest DTC3 secondary media test is distinct from
these source-linked checks. A prebuilt 256K tape-root image
boots to DSH; initial short diagnostic attempts did not
complete target MKFS.DTFS or FSCK.DTFS on DTC3 within their
timeouts. This cannot establish complete physical P0-B
acceptance. Do not claim the test passed without an actual
mount, cwd denial, post-close retirement and surviving
independent root in the guest transcript.

Full source status and remaining work:
`DAIMOS/design/kcore-file-mount-lifetime-v1523.md`.

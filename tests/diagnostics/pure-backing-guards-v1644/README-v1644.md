# P1-E v1644: physical immutable PURE backing guard on writable DTFS

Date: 2026-11-17. **ACCEPTED** in an original, source-linked,
fully booted PDP-6 48K TSFS/no-AUX/PURE guest. The KCORE, MM,
DTFS, VFS, PURE MRES and public ABI are UNMODIFIED.

## Why the filesystem must be writable

A read-only mount refuses every modification independently of
the executable-backing guard. This test deliberately uses
native DTC3 DTFS public mount2 read/write and sets mode 0777
on `/MOUNT/COMP`, so the refusal of actual content alteration
is attributable to PURE backing ownership, not filesystem
mode or RO policy. The separate selected TSFS namespace ROOT
remains provider7/mount1, physically attached DTC0..2.

`prepare-v1644.py` builds on the accepted original source-derived
v1643 C89 guest: it copies the same immutable source-compressed
DXR from `/SYSTEM/COMP` into DTC3, checks FSINFO provider5/
mount2, closes all initial file descriptors, performs a checked
CLEAN DTFS unmount, then remounts the authenticated same reel RW.
The original six-child PIPE/private data/EXIT-057/exact PID-WAIT
workload and seventh-RUN refusal are retained. Only the new
parent-side backing-lifetime checks are added.

## Actual checked user syscalls while all six children are PACKED

Immediately after original parent memory snapshot A, and before
releasing the PIPE writer, original kernel syscalls check:

| Request | Result | Rationale |
| --- | --- | --- |
| `dsys_unmount("/MOUNT")` | Refused | Six PURE children still own mount2 |
| `dsys_unlink("/MOUNT/COMP")` | Refused | Referenced executable vnode still busy |
| `dsys_truncate("/MOUNT/COMP", 0)` | Refused | Immutable executable data retained |
| `dsys_open("/MOUNT/COMP", O_WRONLY|O_TRUNC)` | Refused | OPEN cannot bypass TRUNCATE guard |
| `dsys_open(..., O_RDWR)` and `dsys_write_words` | Open succeeded; WRITE refused | Every subsequent data write checks the vnode |
| Rename `COMP` -> `SAFE` -> `COMP` | Both succeed | Native DTFS changes NAME in the SAME file slot |
| `dsys_unlink("/MOUNT/SAFE")` while renamed | Refused | Guard is on vnode identity, not spelling |

The parent prints `P` only after all these original user-visible
results pass and the same executable can still be STATed. The
rename is intentionally ALLOWED: native `dtfs_rename` updates
the existing name in-place, not the immutable data or file slot.
All six original PACKED children later run and EXIT-057 normally.
Following six exact PID/WAIT/status checks the parent unmounts
the secondary DTFS volume successfully (`U`), confirms FSINFO
no longer publishes mount2, prints `Z`, and reaches normal HALT.

## Source-linked physical MM and guard execution

The source-built guest console ends:

    aaaaaax[B013470/042501]<010000+010000>
    [A013470/042501]P{013470-013470}LwwwwwwUZ

The compiled DXR2 TX2 contains `001420` octal text words.
The ORIGINAL `vm_pdp6_pure_range_v1604.h` floor-sector rule
calculates `skip=(001420+020)&~0177=001400` octal words;
each child retains `010000-001400=006400` octal raw words.
Thus v1644 MUST NOT claim v1643's `006600` or v1638's
`007000` words, which were different source-built executables.

Source-linked physical B/A, mount-guard-entry, vnode-guard-entry
and post-guard P MM snapshots contain exactly six distinct
unchanged, unpinned PACKED_PROCESS child owners:

| Owner | Physical words (octal) | Pins |
| --- | --- | ---: |
| 7 | `051400..060000` | 0 |
| 6 | `061400..070000` | 0 |
| 5 | `071400..100000` | 0 |
| 4 | `101400..110000` | 0 |
| 3 | `111400..120000` | 0 |
| 2 | `121400..130000` | 0 |

Physical breakpoint PC `003431` is the original KCORE
`proc_swap_mount_busy`, entered with AC1=`000000000002`;
PC `003322` is original `proc_swap_backing_busy`, entered with
AC1=`050202000000` (provider5/mount2/file slot0).
At each snapshot `vfs_mount_policy=000000000001`: only the
selected ROOT has the RO bit, and secondary mount2 is RW.
The published ROOT remains TSFS provider7/mount1 throughout.

After six WAITs and successful secondary unmount, the U and Z
MM snapshots each contain eight system/parent extents and **zero
child PROCESS/PACKED MM owners**. No child pin survives, no
child executable backing is prematurely retired or reallocated.

The exact-source auditor PASSes and independently rejects three
mutated physical witnesses: a false RO-policy bit, a forged
retained RAW owner pin, and a false secondary mount argument.
Source checks cover the original VFS write/truncate/unmount
and `file_remove` PURE guards and DTFS in-place rename behavior.

## Commands

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-backing-guards-v1644/run-v1644.sh

    PURE_BACKING_GUARDS_BUILD_V1644=/path/to/guest/build \
        sh tests/diagnostics/pure-backing-guards-v1644/replay-v1644.sh

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_BACKING_GUARDS_BUILD_V1644=/path/to/guest/build \
    PURE_BACKING_GUARDS_TRACE_V1644=/path/to/trace.clean \
        sh tests/diagnostics/pure-backing-guards-v1644/run-audit-v1644.sh

This closes the **sequential** physical content-mutation and
backing-mount lifetime test at RAW PACKED pressure, plus safe
native DTFS same-slot rename. It does NOT prove concurrency
under PI6 interleavings or uncertain MM rollback, nor physical
32K/64K variants or complete time-resolved system peak RAM.
PURE remains disabled by default; strict 32K optimization HOLD.

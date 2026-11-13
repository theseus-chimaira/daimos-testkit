# Booted PDP-6 physical DTFS media-return and volume-isolation gate v1527

Date: 2026-11-13. Scope: **KCORE feature completion**.
Production source: `system/kernel/fs/dtfs_runtime.s`.
No MRES policy changes or simulator shortcuts.

## Guest and real media

`daimos-dtfs-media-return-fullguest-v1527.sh`
reuses the already accepted v1525 full-guest
TSFS-root launcher. Only the disposable test
root and executable differ. The source-linked
`tests/target/daimos-dtfs-media-return-v1527.c`
is compiled with production KCC userland
runtime and started as real PID1 after
`KINIT` reports `DTFS LOADED`. The same
KCORE, optional DTFS/TSFS provider and
PDP-6 Type-551/136 physical controller run
throughout. Normal disk-selected root
provider-refusal policy is unchanged.

The harness uses current native host `mkdtfs`
to prepare **three** distinct correctly
stamped DTFS media. It verifies each
complete DTVOL1 marker, two nonzero
36-bit identity halves, complement and
pairwise distinct identity before boot:

- DTC3: initial mounted native volume
- DTC4: independent mounted native volume
- replacement: a different stamped DTC3 tape

A test-only TSFS `/MOUNT/DT1` directory
provides the second physical mount target.
The guest opens a real FILE on the DTC3
directory and retains its vnode throughout
the physical read failure and identity
exchange. A second loaded DTFS directory
forces shared cache transitions. No
mock provider, FILE layer or raw read
callback is used in this guest.

## Physical sequence and real guest assertions

The host waits for target output
`READY_DETACH`, then sends Control-E to
the real SIMH monitor, detaches DTC3
*only*, resumes the PDP-6, and signals
the target via a real blocking CTY
READCHAR. The target checks that DTC3
FSINFO and old FILE operations fail
but independent DTC4 FSINFO continues
to succeed (`OFFLINE_REFUSED`).

At `READY_SWAP`, the monitor attaches
the different stamped volume to DTC3.
The target requires DTC4 FSINFO to
succeed before, during and after the
original DTC3 FSINFO and open FILE
identity rejection; it reports
`DTC4_PREPROBE_OK`,
`DTC4_AFTER_INFO_OK`,
`REPLACEMENT_REFUSED`. An error in
any assertion is a hard test failure;
the harness does not accept a raw
directory STAT as proof of a mount.

At `READY_RESTORE`, the host detaches
the replacement and attaches the
**original, identical DTC3 image**,
without exposing an intermediate
target request. The guest then requires
the actual physical reserved RBN0 ID,
checksum, both persisted 36-bit halves
and directory to revalidate and the
old FILE to remain safe and usable.
DTC4 remains healthy; closing FILE
permits both secondary mounts to be
unmounted and FSINFO slots 1 and 2
to disappear. Target reports
`RETURN_VERIFIED`, then final `PASS`;
the host script exits with status 0.

The corrected KCC guest PASS is recorded
in the versioned runtime log
`$TMPDIR/daimos-v1527-physical-hot-swap-bcache-fixed-r11.log`.
The independent v1526 full physical
cross-process FILE/cwd regression
was also rerun successfully on the
new v1527 KCORE/MRES image.

## Root cause and negative regression

Before the production fix, the physical
guest showed real DTC3 error refusal
and different-volume rejection, but
unrelated DTC4 FSINFO/STAT returned
-1 after the DTC3 raw RBN0 read,
with **no new DTC4 controller call**.
Live MM/lease inspection confirmed
the provider lock free, DTC3 marked
READ_SUSPECT, and DTC4 mount slot
intact with **no** suspect/uncertain
bits. The raw DTC3 RBN0 read had
overwritten `fs_block_workspace`
without invalidating BCACHE slot 0's
tag, producing a false TSFS metadata
cache hit. The production fix calls
the existing `bcache_workspace_invalidate`
immediately before this raw read.
It adds **one optional MRES instruction
word** and no additional state.

The corrected native `v1522`
source-linked fixture now uses the
**real** BCACHE BSS symbols, exercises
the shared slot-0 tag and rejects a
new executable source mutation removing
the invalidation, in addition to
all seven prior unsafe mutations.

The optional DTFS/TSFS MRES image
changes from octal `003746` text
to `003747`, BSS unchanged
`000002`; fixed KCORE untouched.
This is not a strict 32K acceptance
or optimization.

## Not yet accepted

An actual physical partial/failed
**write** and fail-atomic
WRITE_UNCERTAIN administrative
recovery are still P0-B. The read
failure demonstrated here does not
prove permanent selected root or
BACKSTORE loss (P0-A). P1 mixed
fault, FSINFO capacity and PURE
swapless lifecycle work remain.

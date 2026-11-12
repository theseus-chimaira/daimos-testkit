# DAIMOS v1524: disk-selected root DTC3 physical format, no DTFS MRES

Date: 2026-11-12. This is an explicit **negative** guest
policy regression; it is not proof of actual mounted-DTFS
recovery. In `ROOT=auto BOOT=dsk`, DTFS/TSFS MRES is
present in the built package but deliberately **not
installed** by `module_minit.c` after DSK is selected
as root. Hardware DTC3 still has a functional physical
block service for transient native MKFS/FSCK tools.

An actual 256K disk-root boot under the corrected Type-551
simulator completed target `MKFS.DTFS -O NATIVE
/DEV/DTC3` and printed `FSCK.DTFS NATIVE OK`.
The subsequent `MOUNT.DTFS` correctly returned an
error. An earlier v578 runner nevertheless printed
PASS because it checked a STAT on the existing D6FS
directory `/MOUNT/DT0` and a shell ECHO, ignoring
the actual `MOUNT.DTFS:` and `UNMOUNT:` errors.
This was an **incorrect old test oracle**, not a
successful mounted provider.

The v578 testkit now requires genuine post-MOUNT
FSINFO/MOUNT publication for positive acceptance,
rejects any MOUNT/UNMOUNT command errors, and
requires the mount to disappear after unmount.
`daimos-dtfs-diskroot-provider-refusal-v1524.sh`
expects the disk-root refusal explicitly and checks
that the mount was not published.

A first rerun on previously used scratch disk-root
media halted before LOGIN with `?RT`; that
attempt is inconclusive. After rebuilding the
scratch D6FS root and rerunning the exact
negative-policy test, the full guest **PASSED**:

- target physical DTC3 `MKFS.DTFS` returned;
- `FSCK.DTFS NATIVE OK` appeared;
- `MOUNT.DTFS: /MOUNT/DT0` confirmed refusal;
- the real `MOUNT` inventory printed D6FS and
  MEMFS but **no DTFS**.

The test output is in
`$TMPDIR/daimos-v1524-diskroot-provider-refusal-clean-r3.log`.
This is explicitly a negative provider-policy guest
PASS, not a positive DTFS-mount or recovery result.

True P0-B physical mounted FILE/cwd, media return,
replacement and write-uncertain recovery require a
run with the **DTFS provider actually installed**,
currently a DTC-selected root. No production
module-installation policy change is requested.

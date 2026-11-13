# KCORE v1528: physical WRITE_UNCERTAIN containment

Date: 2026-11-13. Scope: noncritical secondary
DTFS physical **write failure**, not a simulator-only
source-linked reply. The real PDP-6 256K tape-root
guest runs unchanged v1527 fixed KCORE and installed
DTFS/TSFS MRES through corrected SIMS Type-551.

## Physical guest sequence

The new test-only PID1 program
`tests/target/daimos-dtfs-write-uncertain-v1528.c`
uses actual native syscalls and the existing
v1525/v1527 boot harness.

1. Physically mount a valid 72-bit stamped native
   DTC3 **read/write**; check FSINFO provider 5.
   CREATE `/MOUNT/DT0/FAULT` as a real FILE,
   WRITE one native word, CHMOD to seed a real
   metadata write, and STAT its size.
2. At the `READY_DETACH` guest checkpoint,
   pause the running SIMH monitor via CTY,
   DETACH only DTC3, resume and signal PID1.
3. Attempt another real CHMOD on the same
   DTFS file, requiring a negative return.
   It updates directory metadata through the
   production DTFS write/commit path.
4. At `READY_RESTORE`, pause SIMH and ATTACH
   **the original identical stamped DTC3 image**.
   Resume and require that FSINFO and STAT
   continue to refuse despite same-volume return.
5. Attempt CLOSE twice: both fail, preserving
   the FILE descriptor as `file_close`
   requires a successful `vfs_sync` before
   relinquishing an owner. UNMOUNT must also
   refuse and preserve the mount.

The production `dtfs_dtc_write` sets the
per-mounted-unit `WRITE_UNCERTAIN` bit
(octal `0400000`) after a raw negative
write; unlike `READ_SUSPECT`, its next
`dtfs_load` never clears it based on the
same 72-bit identity. The native v1522
source-linked test independently verifies
the exact write-bit and fail-closed behavior.
The physical guest `PASS` after return
demonstrates the observable sticky boundary.

Actual runner:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export DAIMOS_TSFS_PREBUILT_BUILD=$TMPDIR/daimos-v1527-bcache-fixed-taperoot-build-r1
export DAIMOS_TSFS_SIMH=$PDP10_PREFIX/bin/pdp6-v1524
sh $HOME/git/daimos-testkit/tests/validation/daimos-dtfs-write-uncertain-fullguest-v1528.sh
```

Observed guest stages:

```text
DTFSWRITE V1528 START
DTFSWRITE V1528 READY_DETACH
DTFSWRITE V1528 WRITE_FAILED
DTFSWRITE V1528 READY_RESTORE
DTFSWRITE V1528 WRITE_STICKY
DTFSWRITE V1528 PASS
```

Full guest host exit status was zero. Revisions
were driven by actual results: the first guest
correctly failed its incorrect expectation that
FILE CLOSE would succeed on an unverified DTFS;
the final oracle expects and verifies retention.
The live PID1 never bypasses production I/O.

## Precisely what remains unproved

The medium is detached **before** the failing
write. The test proves actual physical transport
failure and conservative sticky WRITE_UNCERTAIN,
but **does not** prove an interrupted write
after some of a 128-word block has already
reached physical media. Nor does it implement
or claim administrative cleanup.

An administrator must not be able to clear
WRITE_UNCERTAIN by a matched-ID read. The
present path intentionally refuses CLOSE and
UNMOUNT because each invokes filesystem SYNC.
Safe recovery needs a separate explicit
authenticated procedure: handle retained
FILE/cwd owners, prove repair or replacement,
and retire the old mount only without live
references. Normal unmount, stale vnode/FILE
reuse and reformat-on-error are not substitutes.

No DAIMOS source, KCORE fixed image, MRES,
disk/tape format, on-media field or permanent
RAM change is made by this test. Strict 32K
gate remains HOLD.

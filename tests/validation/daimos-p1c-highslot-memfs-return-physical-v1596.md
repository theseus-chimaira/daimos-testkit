# P1-C v1596: independent writable MEMFS while two physical DTFS reels fail

Date: 2026-11-15. Full 256K KCC PDP-6 physical guest, original
installed TSFS/DTFS/MEMFS/VFS/FSINFO, 2-member Type-551 TSFS root
on DTC0/DTC1 (empty DTC2), four independently stamped native DTFS
mounts DTC3..DTC6 (public IDs 2..5), plus a fifth writable MEMFS
mount `/MOUNT/RAM` at public ID 6. All permanent kernel code,
resident MM, media formats and userland ABI unchanged.

## Original media failure and independent provider work

The already accepted v1527 live physical DTC3 detach, different
72-bit reel rejection, same original return and held-FILE retry
occur with independent high-slot ID4/ID5 native DTFS volumes and
MEMFS. The original guest verifies root and all exact slot IDs
and paths, fails FSINFO on a *published but physically unavailable*
DTC3 without converting the slot into an empty record, and proves
all unaffected providers survive both failure and wrong-identity
replacement. DTC3 returns correctly with original identity.

The host then uses a second actual SIMH monitor episode to DETACH
**DTC6**, the live highest-mounted native Type-551 volume with
public mount ID5. Original FSINFO must refuse slot4, while DTC3,
DTC4, DTC5 and the independent writable MEMFS still answer.
During physical DTC6 absence, the original guest rewrites one
word of `/MOUNT/RAM/KEEP`, rereads all three original expected
words and checks the MEMFS FSINFO provider and mount ownership.
The same original DTC6 reel is then reattached; original DTFS
must physically revalidate its complete 72-bit identity and allow
the original published high slot again. All mounts retire and the
two-member TSFS root and capacity eight remain valid.

## Differential Type-551 simulator diagnosis

The original installed PDP-6 simulator v1524 and unmodified
DAIMOS kernel passed **all** DTC6-offline and MEMFS-write checks,
but after returning the same valid physical DTC6 image, the
original FSINFO for that exact slot still returned -1 (diagnostic
`HIGH_RETURN_DIAG_V1596` = `6`). Repeated 256K guest runs
reproduced it; the physical 128-word RBN0 still held a valid
DTVOL1 magic, distinct 72-bit identity and complement checksum.
This was NOT accepted as v1596 success and was NOT bypassed by
changing the test or ignoring the high slot.

The PDP-6 Type-551 simulator source (`sims/PDP10/pdp6_dtc.c`)
restored the file buffer and tape `pos` on reattach but left old
per-unit `CMD`, `DSTATE` and `DELAY` values from the removed reel.
An isolated source build resetting these transport fields on
attach and detach was compared against the unmodified original:
the exact same v1596 guest, real physical tape images and same
FSINFO/mount/MEMFS assertions now completed **PASS**. The fix
was committed and pushed to `theseus-chimaira/sims` as
`fe97912` (v1598), without modifying DAIMOS. A versioned binary
was installed as `$PDP10_PREFIX/bin/pdp6-v1598`; the former
`pdp6-v1524` remains available and the normal `$PDP10_PREFIX/bin/pdp6`
symlink now selects v1598.

The isolated patched-simulator run and independent raw-media
oracle both PASS. Every actual original CTY stage is observed:
`RAM_SEEDED_V1596`, `MOUNTED5_V1595`, `OFFLINE_REFUSED`,
`REPLACEMENT_REFUSED`, `RETURN_VERIFIED`,
`READY_HI_DETACH_V1596`, `HIGH_OFFLINE_RAM_WRITE_V1596`,
`HIGH_RETURNED_V1596`, `RETIRED_ALL_V1595`, and `PASS`.
The oracle authenticates both physical root reels, DTC2 empty,
five **distinct** 72-bit-stamped DTFS tapes with intact RBN0
checksums, all ordered source-linked stages, and absence of
SIMH/provider error. **Eight** deliberately corrupted media,
root, identity, return-stage and RAM-progress witnesses rejected.

Retained accepted differential evidence:
`$TMPDIR/daimos-dtfs-secondary-mounted-v1525-22104`,
`$TMPDIR/daimos-p1c-v1596-patched-sim-v1598-run1.log`,
`$TMPDIR/daimos-p1c-v1596-patched-physical-verify.txt`,
and `$TMPDIR/daimos-p1c-v1596-patched-oracle.log`.
Original simulator failures are retained in
`$TMPDIR/daimos-p1c-v1596-run1.log`, `-run2.log` and `-run3.log`.

Reproduce using the installed corrected simulator:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
export DAIMOS_TSFS_PREBUILT_BUILD=$TMPDIR/daimos-v1572-operator-build-r1
sh tests/validation/daimos-p1c-highslot-memfs-return-physical-v1596.sh
```

This is true mixed high-slot provider-unavailability and healthy
MEMFS forward progress; it does NOT inject a physical D6FS
BACKSTORE owner failure (critical fail-stop remains mandatory),
nor does it combine process swap under the same exact DTC6
failure. P1-C still needs those distinct combined cases.
P1-E remains on hold for KA10 architecture and 32K optimization
remains on hold. No source or RAM changes in production DAIMOS.

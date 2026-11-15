# P1-D v1595: real unavailable DTFS mount is not an empty FSINFO slot

Date: 2026-11-15. Full 256K KCC PDP-6 physical guest using the
installed TSFS/DTFS/FSINFO providers and a genuine two-member Type-551
root (DTC0 and DTC1, DTC2 explicitly empty). The reusable accepted
v1527 CTY checkpoint transports all physical detach/attach operations;
the v1533 fixture supplies four native, independently 72-bit-stamped
DTFS reels on DTC3..DTC6, at real public VFS mount IDs 2..5. No
production kernel, MRES, media format, ABI or resident RAM changes.

The original guest first verifies FSINFO capacity **8**, TSFS root
provider 7/mount ID1, all four occupied DTFS slot records and paths,
three empty upper slots and invalid indices 8/9. The host then
DETACHes actual DTC3 during a CTY-blocked process checkpoint.
The DTC3 mounted slot1 must return FSINFO **-1**, never zero (which
would incorrectly mean an empty slot), and the held original FILE
must refuse I/O. Slots 2..4 (public IDs 3..5) must continue returning
their exact identities while the missing DTC3 is not retired. The
host next ATTACHes a **different valid 72-bit-stamped physical reel**
to DTC3; the original mount and FILE still reject it, while all
independent high slots remain alive. Finally the host returns the
**same original physical DTC3 tape**, and the original provider
revalidates the original identity and permits the held FILE again.
All four mounts retire, all seven nonroot slots become empty and
the original TSFS root plus FSINFO capacity 8 remain intact.

Original CTY markers observed in the real physical run:

```
DTFSMEDIA V1527 START
DTFSMEDIA V1527 MOUNTED5_V1595
DTFSMEDIA V1527 READY_DETACH
DTFSMEDIA V1527 OFFLINE_HIGH_STABLE_V1595
DTFSMEDIA V1527 OFFLINE_REFUSED
DTFSMEDIA V1527 READY_SWAP
DTFSMEDIA V1527 REPLACEMENT_HIGH_STABLE_V1595
DTFSMEDIA V1527 REPLACEMENT_REFUSED
DTFSMEDIA V1527 READY_RESTORE
DTFSMEDIA V1527 RETURN_ALL_STABLE_V1595
DTFSMEDIA V1527 RETURN_VERIFIED
DTFSMEDIA V1527 RETIRED_ALL_V1595
DTFSMEDIA V1527 PASS
```

The full physical simulator and source-linked guest returned zero.
An additional independent host oracle verified both actual TSFS root
members and absent DTC2, the physical DTVOL1 RBN0 records for all
four mounted reels and different replacement, **five distinct
72-bit IDs and correct complement checksums**, the ordered stages,
and the absence of provider FAIL or simulator errors. Five unsafe
controls were rejected (missing high mount, false replacement
rejection, duplicate real ID, invalid stamp checksum and secretly
nonempty DTC2).

Evidence: `$TMPDIR/daimos-dtfs-secondary-mounted-v1525-26085`,
`$TMPDIR/daimos-fsinfo-v1595-run1.log`,
`$TMPDIR/daimos-fsinfo-v1595-physical-verify.txt` and
`$TMPDIR/daimos-fsinfo-v1595-verifier-output.txt`.

Reproduce using a previously validated complete 256K KCC TSFS
production image as immutable input:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
export DAIMOS_TSFS_PREBUILT_BUILD=$TMPDIR/daimos-v1572-operator-build-r1
DAIMOS_TSFS_KEEP_WORK=1 sh \
    tests/validation/daimos-fsinfo-high-media-return-physical-v1595.sh
```

This accepts P1-D real mounted-provider error versus empty slot,
high-slot owner isolation, exact identity recovery and unchanged
capacity. It does NOT prove high-slot DTC6 itself can disappear and
return, failed controller-service publication at KINIT, or genuine
concurrent process swap. P1-C and P1-D still have those separate
acceptance tasks. VERSION 0.5, strict 32K optimization HOLD.

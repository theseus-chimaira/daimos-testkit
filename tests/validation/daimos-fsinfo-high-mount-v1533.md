# KCORE v1533: physical occupancy above historical four mounts

Date: 2026-11-13. Real 256K PDP-6, full KCC fixed KCORE
and installed DTFS/TSFS MRES. Testkit only.

The v1532 test established KINIT's seven-slot runtime inventory
but physically occupied only slots 0 and 1. This test proves
the native VFS allocator, DTFS MM media and 72-bit identity
tables, FSINFO records and retirement all function with
public mount ID **5**, beyond the former fixed four entries.

The disposable physical harness generates four separately
stamped native Type-551 tapes for DTC3, DTC4, DTC5 and DTC6.
It checks every RBN0 DTVOL1 marker, both nonzero 36-bit
identity halves, complements and pairwise distinct IDs
before boot. Every tape and the headless SIMH do-file is
private to its own run (v1530 invariant); the production
KCC boot image is read-only input. The SIMH DTC4-DTC6
transports are enabled and physically attached before GO.
The actual TSFS root manifest includes independent empty
directories `/MOUNT/DT0` through `/MOUNT/DT3`.

PID1 uses production `dsys_dtfs_mount` to mount all four
valid volumes read-only, confirms each FSINFO slot provider 5,
the exact target pathname and public IDs 2, 3, 4 and **5**.
Slot 0 remains root TSFS provider 7. FSINFO then enumerates
slots 0 through 6, with five live mounts and two empty holes;
index 7 is invalid. The guest unmounts the **middle**
DTC4 volume first, confirms its slot is empty and the
higher DTC6 mount retains public ID 5 and its exact pathname.
The other three mounts then retire in reverse order.
Afterward slots 1..6 all report empty, root still works
and capacity still reports seven.

The complete real PDP-6 guest and host pass:

```text
PASS v1533: four independent stamped DTFS volumes
FSINFOHI V1533 START
FSINFOHI V1533 MOUNTED5
FSINFOHI V1533 SCANNED7
FSINFOHI V1533 HOLE_STABLE
FSINFOHI V1533 RETIRED
FSINFOHI V1533 PASS
```

The v1532 single-DTC3 physical guest remains a regression
on the same generic harness. No production changes are
necessary. A real 26-volume/full-inventory physical
configuration remains unproved: 26 is the validated
**representational/planner maximum**, not current hardware
availability. No per-slot permanent RAM or fixed KCORE
growth, VERSION 0.5 and 32K/optimization HOLD.

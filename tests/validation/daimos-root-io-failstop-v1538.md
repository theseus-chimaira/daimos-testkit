# v1538: source-linked PDP-6 root-I/O fail-stop acceptance

Date: 2026-11-13. KCORE feature gate, after user-selected policy
change: a completed negative I/O on an already mounted, selected
root filesystem must HALT. A secondary mounted filesystem returns
an error and retains ownership. An ordinary EOF, rejected argument,
invalid TSFS record, or successfully retried hardware operation must
not HALT. BACKSTORE has an independent policy and is not changed.

## Production source and validation

`daimos-root-io-failstop-v1538.sh` takes the actual D6FS block reader,
write-through code, generic backing dispatcher, new KCORE gate and
v1515 no-return leaf. The native PDP-6 executes 11 cases: root READ
and WRITE failure (exact root-specific HALT PC), secondary failures,
unpublished or different root, invalid block/mount and successful
root/secondary operations. Five modified actual-source mutant branches
are rejected (missing read gate, missing write gate, wrong mounted
owner, wrong root compare, wrong fatal reason).

`daimos-tsfs-io-failstop-v1538.sh` extracts the actual optional
TSFS FILE/EXTENT table path and stored/BLOCK data path and the same
fixed gate. Twelve cases execute: selected-root physical metadata,
stored and BLOCK read errors all HALT at the root PC; secondary
metadata/data errors return without HALT, as do invalid records,
unpublished/different root, valid metadata/data and zero-length
reads. Four unsafe actual-source mutations are rejected.

Both test groups exercise PDP-6 instructions through `p10run`. Only
the low-level physical I/O outcome, unrelated dynamic MM glue and
simple BCACHE behavior are supplied as test oracles. The native
tests do not claim a real 256K booted root-medium detach.

The v1513 D6FS independent nonroot-media test was adapted to link the
real v1538 gate. Historical standalone TSFS v15 slab and v1
multi-extent fixtures now link the same gate from production source
using `daimos-root-io-gate-extract-v1538.py` instead of duplicating
its behavior. Existing v1515/v1516/v1517/v1537 validations PASS.
The legacy TSFS D6LZ v1 test still references a removed
`system/kernel/core/d6lz_pdp6.s`; that stale missing source is
unrelated to root fail-stop and is not counted as accepted.

## Actual full-guest physical acceptance

A full 256K KCC tape-root image and matching D6FS/TSFS optional MRES
production links have been built.

`daimos-mixed-storage-fault-fullguest-v1534.sh` PASSes on the new
image. With an actual detached DTC3/failed native DTFS WRITE and
subsequent original-medium return, the selected TSFS root and
independent DTC4 native DTFS plus writable MEMFS stay operational.

`daimos-root-outage-fullguest-v1538.sh` PASSes against the same
256K KCC tape-root KCORE with a root-specific test PID1:

1. STAT `/SYSTEM/INIT`, `/SYSTEM`, `/CONFIG` successfully while
   the real DTC-root media is attached.
2. At `ROOTLOSS V1538 READY_DETACH`, the simulator host detaches
   physical DTC0, DTC1 and DTC2, then resumes with queued CTY input.
3. PID1 opens and reads actual `/SYSTEM/INIT` root file **data**.
   Root failure must not be returned to userspace.
4. Physical PDP-6 HALT occurs at octal PC **`003743`**. The harness
   compares this against `kcore_critical_device_lost_v1515+3` from
   the current KCORE map and the actual source's root-HALT layout,
   rejecting a swapped reason, unexpected low-core crash, no HALT,
   multiple HALTs and explicit userspace failure markers.

Early nonaccepted runs found and fixed two testkit problems: the
hot-swap SIMH ini failed to retain its interactive monitor, and
metadata-only STATs could all be satisfied without a new physical
transfer after detach. Requiring a genuine root *data* read proved
the HALT behavior without changing KCORE.

P0-A as a whole remains open for physical D6FS disk/drum-root
unavailability, isolated multi-tape root-member failure and separate
BACKSTORE critical-failure policy/acceptance.

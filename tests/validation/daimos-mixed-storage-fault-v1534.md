# KCORE v1534: actual mixed TSFS / DTFS / MEMFS fault isolation

Date: 2026-11-13. P1-C feature acceptance, testkit-only. The
production KCORE and loaded DTFS/TSFS/MEMFS providers are exactly
the fresh v1532-v1533 256K full KCC build.

## Test environment and physical media

The v1530 isolated full PDP-6 physical runner boots genuine
TSFS root from DTC0-DTC2. Two separately formatted native DTFS
volumes with nonzero, distinct, complete 72-bit DTVOL1 stamps
are physically attached on DTC3 and DTC4. An otherwise empty
TSFS root manifest contains three independent mount points:
`/MOUNT/DT0`, `/MOUNT/DT1`, and `/MOUNT/RAM`.

The real PID1 invokes production native DTFS mount on DTC3 and
DTC4 read/write and production INIT-only MEMFS mount at
`/MOUNT/RAM` with 4096 words. The MEMFS mount veneer is
compiled from the existing `userland/init/memfs_mount.s`
**only for this test**, not moved into libc or KCORE.
The running guest has root TSFS, two independent DTFS volumes
and MEMFS in four live VFS slots.

It creates a real one-word DTC3 FILE and holds its descriptor,
a distinct two-word DTC4 FILE and a three-word MEMFS FILE.
It verifies the healthy files by real STAT/OPEN/READ/CLOSE and
checks provider identities, distinct mount paths and seven-slot
KINIT capacity.

## Physical fault and cross-provider checks

After the healthy reads, PID1 performs STAT on **DTC3 last**
while that medium is still attached. This is mandatory:
the DTFS/TSFS shared directory cache may otherwise have been
displaced by the preceding DTC4 reads. With DTC4 cached last,
the first original test incorrectly suffered a physical
DTC3 *read* failure on CHMOD; same-ID return was then
legitimately accepted as READ_SUSPECT recovery. That
experiment does **not** demonstrate WRITE_UNCERTAIN failure.
The test did not weaken the oracle: it restored the intended
precondition for an actual metadata write.

At `READY_DETACH`, the host pauses the real Type-551 simulator
and physically DETACHes only DTC3, leaving DTC0-DTC2, DTC4 and
other providers untouched. PID1 attempts CHMOD on the warmed
DTC3 FILE. Its actual metadata WRITE now fails. Ordinary
CLOSE and UNMOUNT refuse without releasing the poisoned
FILE/mount. The DTC3 FSINFO refuses as well.

While DTC3 is still physically absent, PID1 successfully
checks TSFS root FSINFO, DTC4 native DTFS FSINFO and **exact
two-word file data**, MEMFS FSINFO and **exact three-word
file data**, and the original seven-slot capacity.

The host physically reattaches the **identical 72-bit stamped**
DTC3. The guest now checks the DTC3 FSINFO, pathname STAT and
CLOSE still refuse, proving WRITE_UNCERTAIN is sticky rather
than an automatically cleared READ_SUSPECT condition. A new
real native DTC4 CHMOD metadata write succeeds, and the
independent DTC4/MEMFS/TSFS file-content/FSINFO checks all
pass again.

Finally, DTC4 and MEMFS UNMOUNT successfully, their VFS slots
become empty, TSFS root remains active and DTC3 stays
quarantined with its FILE owner still unresolved.

The actual guest and host report:

```text
PASS v1534: independent physical DTC3/DTC4 volume identities
MIXEDIO V1534 START
MIXEDIO V1534 READY_DETACH
MIXEDIO V1534 WRITE_FAILED
MIXEDIO V1534 HEALTHY_DURING
MIXEDIO V1534 READY_RETURN
MIXEDIO V1534 HEALTHY_RETURN
MIXEDIO V1534 RETIRED_HEALTHY
MIXEDIO V1534 PASS
```

No test-mocked provider or altered fixed KCORE path is involved.
Every physical tape and SIMH command file is private to this
runner. The failed old tape is never rewritten or declared
repaired. A new MEMFS mount tests independent volatile MM
storage but **does not** prove LOGSTORE snapshot persistence
or concurrent process-swap backing.

## Explicit limits

This closes one P1-C mixed-provider physical write-fault
isolation gate: root TSFS + poisoned DTC3 + healthy DTC4 +
writable MEMFS. It is not closure of the broader mixed
DSK270/DRM236/DTC DEVICE/VOLUME mapper, real BACKSTORE
faults, LOGSTORE snapshot plus process swap or concurrent
remote-owner rollback matrix. P0-A permanent critical
device-loss classification and P0-B durable old-media
re-admission also remain separate.

There is **no production KCORE/MRES/data or RAM change**.
VERSION 0.5, strict 32K/optimization HOLD.

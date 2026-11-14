# v1576 P1-C: physical persistent MEMFS and LOGSTORE in one guest

Date: 2026-11-14. **PASS** on a full 128K KCC/PDP-6 disk-root
configuration with real backing-device reads and writes in both boots.
This is a completed **subset** of P1-C, NOT simultaneous process swap.

The test reuses the current production `daimos-xip-launch-v1469.c`
guest and `daimos-memfs-snapshot-reboot-v1477.sh` through a test-only
`XIP_P1C_LOGSTORE_V1576` option. It changes no production DAIMOS
kernel, driver, syscall, on-media layout, KCORE RAM or MRES.

Boot 1 mounts configured `/TEMP` MEMFS PERSIST, creates the exact
`XIPSAFE` executable and `SNAPDATA` containing three 36-bit words,
checks real RUN/WAIT and the MEMFS file. The same guest then calls
the actual root-only LOGCTL STATUS/APPEND/READ_BLOCK sequence. It
records the current sequence and ring slot, appends an LSREC1 record
with unique code `0157601`, reads the exact physical logical LOGSTORE
block `slot+2`, compares the full 36-bit magic, sequence, code and
payload, and verifies the producer cursor advanced by exactly one.
Only then is the shell's ordinary `HALT` allowed to commit snapshot.

Boot 2 initializes **new CPU RAM**, retains precisely the original
backing DSK and 8 MiB AUXSTORE drum images, and remounts the
persisted MEMFS. It checks restored MEMFS file contents, executable
and RUN/WAIT; scans the actual LOGSTORE ring through root's privileged
READ_BLOCK for exactly one prior `0157601`/payload record; and
appends/reads a new `0157602` event, checking sequence increment.
The v1484 AUXSTORE descriptor checks run after each boot, and the
final descriptor is compared with the pre-boot original bytewise.

Guest markers:

```
MEM 128 K
LOGSTR LOADED
P1C-LOGSTORE-APPEND-READBACK
XIP-SNAPSHOT-WRITTEN
```

Then, after an independent cold boot:

```
MEM 128 K
LOGSTR LOADED
P1C-LOGSTORE-PREVIOUS-BOOT
P1C-LOGSTORE-APPEND-READBACK
XIP-SNAPSHOT-RESTORED
```

Both probe programs returned STATUS:0. The physical drum's AUXSTORE
partition descriptor remained unchanged:

```
BACKSTORE 5770+10000
LOGSTORE 5370+400
CACHESTORE 15770+2010
D6FS 1+5367 SUPER 0/1
```

Existing relevant independently rerun accepted components:
`daimos-snapshot-swap-reserve-v1536.sh` (KINIT v1/v2 snapshot
reservation, real PDP-6 BACKSTORE alloc/free, seven rejected unsafe
mutations); `daimos-swap-in-real-transaction-v1316.sh` (real PDP-6
MM pin/restore/free and three rejected unsafe mutants but TEST-controlled
backing read); `daimos-logstore-append-v1.sh` and
`daimos-logstore-direct-read-native-v706.sh` (PDP-6 native LOGSTORE
commit-last and device ABI). These are separate component proofs.

## Limits and next P1-C acceptance

The MEMFS snapshot and LOGSTORE use real physical backing within the
same full guest, but **no simultaneous physical swap-in/restoration
and MEMFS snapshot commit** was demonstrated, and no in-flight
DSK270/DRM236/DTC loss/return or LOGSTORE write-fault injection was
performed. A source-linked swap-in is not a concurrently swapped
physical full guest. P1-C remains OPEN. P0-A/B remain closed under
their documented contracts; P1-D/E separate. VERSION 0.5, 32K HOLD.

# v1566: native and physical Type-551 DTVOL2 exclusive CLEAN acceptance

Date: 2026-11-14. P0-B remains OPEN. Production DTVOL2 stays READ-ONLY.

## Production source under test

The DTFS provider now links actual `dtfs_intent_clean_v1566`, the
existing v1552 pinned MM lease extended with
`dtfs_intent_owned_clean_v1566`, and the mounted-owner guard
`dtfs_intent_mount_seal_v1566`. A private DTFS MRES op 027 is reached
from VFS UNMOUNT only when a published DTVOL2 mount is both QUIESCING
and INTENT_ARMED. The v1555 universal DTVOL2 read-only mount/write
veto is unmodified and prevents ARMED from being reached by normal
production guests.

The physical CLEAN leaf reads RBN0 through actual raw Type-551 I/O,
requires a complete WRITE_INTENT record with both saved ID halves,
changes only the on-media state and salted checksum, writes the full
128-word RBN0, and physically rereads and validates exact CLEAN and
both original ID halves. The MM scratch is allocated and pinned for
the entire transaction, never as fixed resident RAM. The owned clean
entry publishes sticky WRITE_UNCERTAIN before the first raw I/O.
The mount owner guard releases that uncertainty only after physical
CLEAN readback, MM free and original root/media/policy/identity proof.
VFS then repeats owner and MM scans, releases QUIESCING and retires
without scheduling. An uncertain I/O retains both mount and barrier.

## Native source-linked PDP-6 checks

Run from the `daimos-testkit` checkout:

```sh
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-clean-native-v1566.sh
sh tests/validation/daimos-dtfs-seal-owner-v1566.sh
sh tests/validation/daimos-dtfs-owned-clean-v1566.sh
sh tests/validation/daimos-dtfs-seal-unmount-v1566.sh
```

| Native boundary | Accepted cases | Unsafe mutants rejected |
| --- | ---: | ---: |
| Actual raw CLEAN + real DTVOL2 validator, physical-I/O oracles | 18 | 11 |
| Actual mounted owner and seal guard, MM completion oracle | 37 | 10 |
| Actual pinned-MM shared CLEAN wrapper, strict MM and I/O oracles | 11 | 7 |
| Actual resident VFS unmount/quiescence, provider completion oracle | 18 | 6 |
| **Total** | **84** | **34** |

The native tests cover wrong 72-bit ID halves, invalid seals and
padding, CLEAN instead of expected DIRTY, read failures, false-short
successes, torn/partial writes, false write acknowledgments, corrupted
readback, mandatory cache invalidation, sticky uncertainty, failed
MM pin/free, owner change during I/O, RO-policy change, final owner
rescan and post-CLEAN false-success refusal.

Previous v1552 native shared-MM tests, v1554 verify-MM, v1555
RO admission and write veneer, v1556 mounted recovery, v1561 mounted
intent, v1562 owner/quiescence and VFS unmount, and v1563 executable
attach PASS after the new code was linked. The two older v1552
standalone MM test fixtures declare the v1566 CLEAN and poison entry
as deliberately unreachable so their original ARM-only oracle remains
unchanged. Complete production full 256K KCC KCORE/DTFS MRES
assemble/fold/link/image PASS.

## Real full-guest physical Type-551 acceptance

Production RO-only full physical DTVOL2/CLEAN and DTVOL2/WRITE_INTENT
cold boots continue to PASS on v1566. In particular, the original
RO/CLEAN mount/unmount never writes the physical tape, and a previously
DIRTY tape remains unmountable.

To physically exercise dormant v1566 CLEAN without lifting the v1555
read-only veto in the production checkout:

```sh
sh tests/validation/daimos-dtfs-clean-physical-v1566.sh
```

The runner builds a source-matched 256K KCC physical TSFS-root image
and copies it to a disposable directory; optionally an exact current
build directory can be supplied through `DAIMOS_V1566_BASE_BUILD`.
The runner refuses a stale base. It appends the test-only op 030
`dtfs_test_physical_arm_v1566` to that copied DTFS MRES alone and
adds a test-only invocation in the copied VFS immediately after real
v1562 quiescence acquisition. This invokes **real production v1551/
v1552 physical DIRTY arm/readback** on the specifically selected
DTC3 secondary DTVOL2/CLEAN image. Only after a successful DIRTY
arm and MM release does the disposable test grant its current VFS
slot a temporary RW policy and set RAM INTENT_ARMED. The normal
unmodified production v1566 UNMOUNT path then performs the full
physical CLEAN/readback and retires. The existing v1564 real-guest
two-process physical lifecycle exercises the mount/unmount twice.

The full booted guest and independent complete-tape SHA-256 oracle
PASS. Both test symbols were independently verified in the linked
KCORE/MRES maps. The entire physical image has its original bytes
after the test, providing a full-media end-to-end restoration check.
This is an actual Type-551 physical write and reread, not a simulated
driver callback. The temporary RW cutover **exists exclusively in the
disposable test image**; it is never built by the production Makefile.

## Accepted size and remaining gates

Production fixed KCORE `__kcore_low_end` moved from octal `024330`
(v1565) to `024364` (v1566), **28 additional TEXT words** and zero
additional permanent DATA/BSS or process/mount table words. CLEAN
runtime resides in optional movable DTFS MRES. The strict 32K
placement gate stays on HOLD.

**Not accepted:** actual Type-551 media exchange between verified
DIRTY and DATA/CLEAN writes, intentionally interrupted physical
DATA/DIR writes, torn RBN0 CLEAN/partial write and subsequent
reinsertion/cold boot, and safe production writable DTVOL2 mounting.
Until those are proven, the v1555 V2 read-only veto remains mandatory.
P0-A complete, **P0-B OPEN**, P1-C/D/E unchanged. VERSION 0.5.

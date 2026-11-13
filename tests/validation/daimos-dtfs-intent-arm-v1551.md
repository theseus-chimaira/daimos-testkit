# v1551: PDP-6 DTFS DTVOL2 write-ahead RBN0 arming

Date: 2026-11-13. P0-B incremental implementation, feature still OPEN.

## Source implemented

The genuine production-source module
`system/kernel/fs/dtfs_intent_arm_v1551.s` is an independent
PDP-6 assembly entry with an explicit physical-block ABI:

```
AC1 = physical Type-551 DTC unit
AC2 = original 36-bit high volume-ID half
AC3 = original 36-bit low volume-ID half
AC4 = independent caller-owned 0200-word RBN0 scratch buffer
result AC1 = 0 only after verified dirty on-media readback;
             -1 on refusal or physical error
```

The caller is responsible for a serialized DTFS provider lease,
independent MM scratch ownership, mount admission and dirty-lifetime
tracking. It MUST NOT use the shared filesystem pending-data buffer
or directory storage as scratch. The service is not currently linked
into the live DTFS mount/write provider. There are no new permanent
data words or additional resident KCORE instructions.

The service reads RBN0 directly through the production raw DTC
read entry, validates full DTVOL2/CLEAN using the v1550 genuine
native record parser, and compares both ID halves to the caller's
previously admitted identity. It updates only words 4 and 5 to
WRITE_INTENT plus its checked seal, invalidates both clean BCACHE
tags, and sends the full 128-word record through the raw Type-551
write interface. It then clears all 128 scratch words to ensure
that the independent raw readback cannot accidentally use a stale
copy, rereads the physical record, and requires exact DTVOL2/DIRTY
with matching ID and zero padding before returning success.

An uncertain/partial write, failed readback, torn seal, malformed
new volume record or wrong media identity can never return success.
If the marker write was attempted, any subsequent failure invokes
the real DTFS `dtfs_mark_unit_suspect_v1522` ABI with the existing
WRITE_UNCERTAIN bit. The entry never frees mount/file/PIPE/swap
owners or attempts to reset the seal to CLEAN. An initially DIRTY
volume is refused, not silently repaired or accepted for writing.

## Native acceptance and mutation guards

`daimos-dtfs-intent-arm-v1551.sh` builds current host `mkdtfs`
output, decodes actual 36-bit DTVOL1/CLEAN and DTVOL2/CLEAN
records, and executes the real v1551 arm and v1550 validator
instructions under `p10run --machine pdp6` with only the raw
physical I/O completion and mount-poison/cache boundaries mocked.
Its 14 cases verify successful clean-to-dirty physical block
publication, retryable prior refusal, DTVOL1/dirty rejection,
wrong upper/lower identities, missing scratch, initial read
failure, partial marker write, physical readback error, false
write acknowledgement, torn header, changed volume ID after
write, and an independent repeated complete transaction.

Every case asserts the exact returned status, number of raw reads,
raw writes, WRITE_UNCERTAIN poison events and BCACHE invalidations,
and that the original pending filesystem data word is unchanged.
**14 of 14 pass.** Eight mutations to actual helper source are
rejected by the native CPU: skip clean admission, skip either ID
half check, skip readback state, skip poison, skip cache invalidation,
skip physical readback, and ignore a raw write error.

Test development found and corrected source-fixture mistakes:
Python's obsolete `0200` numeric spelling, MACRO-10 `.word`
comma-separated data, an initial missing wrong-low-ID scenario,
and the mandatory 36-bit octal literal prefix. These were test
fixture errors; the production helper is validated without
loosening its checks. No speculative Type-551 device-error bits
or manufactured kernel HALT decisions were introduced.

Reproduce:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-intent-arm-v1551.sh
```

## Remaining integration

This **does not yet prove full-guest physical Type-551 durability**.
The raw device completion is test controlled. The production
DTFS provider still has its old DTVOL1 runtime admission and
write code. The remaining work is a versioned, optional MM-owned
scratch lease; serialized mount/write admission with exactly-once
intent arming before any file/directory write; a race-free,
owner-checked CLEAN seal during final unmount; then real Type-551
partial write/reinsertion/cold-boot/changed-volume tests.

P0-A stays closed. P0-B OPEN. P1-C and optimization untouched.

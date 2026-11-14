# v1558: fail-closed short/zero Type-551 physical admission reads

Date: 2026-11-14. Source-linked PDP-6 production mount/replacement
acceptance and unlinked write-intent helper safety correction.
**P0-B durable writable DTFS remains OPEN.**

## Bug and physical trust boundary

An uncached Type-551 controller callback can report success even if a
fault left some or all of its intended 0200 words unwritten in RAM.
Invalidating BCACHE removes only the clean TAG, not the old 128-word
transfer buffer. Before v1558, real `dtfs_mount_unit` and poisoned-
volume `dtfs_verify_replacement_v1531` reused that buffer across
independent raw directory RBN0144 and identity RBN0 reads. The
standalone `dtfs_intent_arm_v1551` also read its independently MM-
owned scratch before initializing it, unlike its later readback.

The dangerous case is the legacy volume format: **an all-zero RBN0
is valid legacy DTFS**. Simply prezeroing the raw mount workspace
would itself turn a false-successful *zero-byte* RBN0 read into an
apparently valid legacy header. A full 128-word transfer of a genuine
legacy zero block must remain mountable; an incomplete transfer
must never become a trusted volume.

## Production changes

The actual optional DTFS `dtfs_runtime.s` now contains one shared
`dtfs_workspace_clear_v1558`/`dtfs_workspace_poison_v1558` leaf:
it initializes **all 128 words** with either zero or all-one poison,
using only scratch AC4..AC6. No extra static RAM, dynamic allocation,
controller read, cached record or permanent state is added.

- Before a physical native **directory** RBN0144 read in both
  initial mount and poisoned-volume replacement, zero all workspace
  words. A false-successful partial directory cannot retain the
  previous correct owner map, trailer magic or native tags.
- Before initial native **identity** RBN0 admission, fill every
  word with **all ones**. Full legitimate V1/V2 records and full
  all-zero legacy records overwrite the sentinel. An absent or
  partial transfer leaves nonzero garbage in at least one reserved
  word, so the original strict V1/legacy validator or V2 validator
  refuses. This prevents false legacy admission on zero-byte success.
- Before poisoned-volume replacement physical RBN0, likewise use
  the all-one sentinel; in addition, replacement already explicitly
  rejects an old all-zero legacy or unchanged 72-bit identity.
- The v1551 standalone first-write helper now clears its own pinned
  independent MM scratch **before the first raw RBN0 READ** as well
  as before its final independent RBN0 readback. Both calls share
  one exact-length helper. It cannot write a DIRTY marker on the
  strength of an old CLEAN stamp left in the MM scratch extent.

All raw reads remain under existing provider serialization; the
actual pending DATA buffer, saved mount 72-bit ID, sticky error bits,
and default V1/legacy policy are unchanged. The standalone v1551
arm remains intentionally UNLINKED from production DATA writes.

## Executed native PDP-6 acceptance

`daimos-dtfs-intent-arm-v1551.sh` links the real production-source
v1551 helper and v1550 parser to genuine V2 `mkdtfs` media words.
It now seeds scratch with a complete *old valid CLEAN* header before
each call and simulates initial no-byte or three-word false-successful
reads and no-byte false-successful final readback. **17 cases PASS;
10 unsafe source mutations rejected**, including omission of either
scratch clear. No prohibited initial marker write occurs, and the
original raw write-failure poison/cache-invalidation tests still pass.

`daimos-dtfs-v2-ro-admission-v1555.sh` now uses genuine host V2/V1
RBN0 and directory records for **28 native mount cases PASS, 13
unsafe source mutations rejected**. Four new cases simulate no-byte
or three-word false-successful physical reads of the directory or
RBN0. The suite seeds the shared buffer with a previously valid
directory. New negative mutations detect both skipped directory
initialization and **using zeros instead of nonzero poison before
RBN0**, which would silently turn missing media bytes into valid
legacy format. Correct legacy zero-media mounting remains accepted.

`daimos-dtfs-replace-raw-preflight-v1558.sh` uses genuine independently
formatted V1 identity records, a V2 record and native directory bytes.
It source-links the actual `dtfs_verify_replacement_v1531`, shared
initialization leaf and V1 parser. **20 native cases PASS, six unsafe
source mutations rejected**. A false-successful zero-byte or partial
directory read cannot admit a replacement from stale directory data.
Other cases cover unreadable RBNs, torn stamps, corrupted ownership,
the original same identity, zero legacy, mismatching V2 and genuinely
different replacement identities. No retired VFS mount or on-media
repair is performed by this test.

The full actual KCC **DTFS MRES assembly/fold/link PASS** with the
revised production routines. Historical v1519 physical mount and
v1520 identity/probe/target-MKFS native regressions PASS. The v1555
write-guard and v1556 mounted recovery tests remain separate
compatibility checks; neither permits writable V2 by this stage.

Reproduce in `daimos-testkit`:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-intent-arm-v1551.sh
sh tests/validation/daimos-dtfs-v2-ro-admission-v1555.sh
sh tests/validation/daimos-dtfs-replace-raw-preflight-v1558.sh
sh tests/validation/daimos-dtfs-mount-native-verify-v1519.sh
sh tests/validation/daimos-dtfs-volume-id-v1520.sh
sh tests/validation/daimos-dtfs-v2-ro-write-guard-v1555.sh
sh tests/validation/daimos-dtfs-v2-revalidate-v1556.sh
```

## Incomplete durability and remaining risk

Native PDP-6 source-linked cases use controlled Type-551 completion;
they are **not** a full-guest physical tape, DMA, interrupt or cold
boot acceptance. A physically malicious or defective controller
which fabricates data matching the full checked record is a separate
hardware issue. v1558 makes false-successful no-data and short-data
reads fail closed at the kernel parser boundary.

The v1551-v1554 MM-owned DIRTY gateway is not connected to live
DTFS data/directory writes, no provider-retained failure owner
handle has been installed, and no exclusive CLEAN/unmount with
FILE/cwd/PIPE/swap quiescence exists. Production V2 remains
read-only. Hardware media exchange between RBN0 verification and
later data writes is also unresolved. P0-A complete; P0-B OPEN;
P1-C separate. No optimization.

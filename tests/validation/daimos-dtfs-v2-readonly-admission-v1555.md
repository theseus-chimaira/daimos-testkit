# v1555: production DTFS V2/CLEAN read-only mount and write refusal

Date: 2026-11-14. Source-linked KCORE feature test, **P0-B OPEN**.

## Scope and safety contract

The real DTFS MRES mount-control routine now understands the same
v1550 six-word DTVOL2 header as the experimental host formatter.
The production native directory at RBN0144 and physical reserved
RBN0 are read directly from the device before a mount is published.
Only an exact DTVOL2/CLEAN record with nonzero checked 72-bit ID,
correct state/seal, and all 122 zero padding words may mount, and
ONLY when the caller explicitly requests VFS_MOUNT_RDONLY.

DTVOL2/WRITE_INTENT is NOT healthy admission, even as RO.
Read-write DTVOL2/CLEAN is NOT yet admitted. A malformed or torn
record cannot be silently interpreted as the old all-zero format.
Legacy DTVOL1 and all-zero pre-extension volumes keep their
existing mount and identity behavior. The validated V2 mount
publishes DTFS_MEDIA_FORMAT_V2_V1553 in the existing per-mount
MM media word while preserving its unit, personality, and 18-bit
UID/GID. Its two saved 36-bit identity halves use the existing
TSFS-only per-mount shape and extent words, not extra memory.

The shared production `dtfs_dtc_write` veneer now checks the
published VFS root and DTFS media slabs for ANY mounted V2
instance on the physical target unit. A matching unit refuses
BEFORE BCACHE eviction or the raw Type-551 write jump. This is
necessary because internal directory/resize/block writes could
otherwise bypass a VFS-only read-only permission check. A
legacy DTFS mount on another unit is not affected; a second
legacy mount on the same V2 physical unit cannot bypass refusal.
The low-level raw intent write barrier remains unlinked and
the V2 mounted read-only path cannot mutate the tape.

The original v1522 write failure path (with persistent owner
retention and WRITE_UNCERTAIN poisoning) remains in place for
genuine V1/legacy physical writes. A V2 request refused before
raw I/O does not fabricate a physical write error or poison.

The userland native DTFS probe is source-updated to recognize
only valid V2/CLEAN while still probing legacy and V1. It never
authorizes RW itself; final mount flags and a fresh RBN0 read
are checked inside KCORE. Target MKFS identity reset remains
unchanged and still discards the old identity before directory
publication.

## Executed acceptance

`daimos-dtfs-v2-ro-admission-v1555.sh` builds actual production
`mkdtfs` for two independent V2/CLEAN media and V1, decodes the
physical RBN0 and directory RBN0144 from the two 18-bit halves
per word, and links the ACTUAL production `dtfs_mount_unit`
source and unmodified v1550 PDP-6 parser with raw Type-551 and
VFS publication boundary oracles. **15 native mount cases PASS:**
V2/CLEAN RO, V2/CLEAN RW refusal, V2/DIRTY RO and RW refusal,
damaged padding/seal, unreadable RBN0, invalid directory, zero
high/low identity with rechecked seals, a different genuine
V2/CLEAN volume, V1 RW and RO, malformed V1, and all-zero legacy
RW. Publication, physical reads, V2 media tag, both saved ID
halves, and unchanged rejected mount state are checked.
**Nine unsafe changes to actual mount assembly are rejected.**

`daimos-dtfs-v2-ro-write-guard-v1555.sh` extracts and executes
the actual common `dtfs_dtc_write` entry and V2 scanning gate
on PDP-6; raw write, cache invalidation and poison are strict
boundary oracles. **12 cases PASS**: current/other/later-slot
V2 unit, old V1, foreign provider, retired mount, duplicate
physical unit and raw failure. None of the prohibited V2 writes
reaches the raw device. Pending caller data is unchanged;
ordinary V1 raw failures still mark WRITE_UNCERTAIN. **Seven
unsafe actual-source mutations are rejected**.

`daimos-dtfs-v2-probe-v1555.sh` builds the genuine userspace
`dtfs_probe.c` with an ASCII C89 host fixture. **12 positive/
negative observations PASS**, covering CLEAN V2, DIRTY V2,
torn seal, nonzero padding, other checked state, zero ID halves,
old V1 and all-zero media, partial invalid block, failed read,
and invalid physical unit.

The real generated DTFS MRES source is built by the updated
`system/kernel/Makefile` using both `dtfs_runtime.s` and
`dtfs_intent_validate_v1550.s` (no new MRES registration).
The full-profile KCC boot make target successfully rebuilt
the actual linked `dtfs-mres.dobj` with its KCORE map and fold
plan. **PASS** (not a guest boot or physical-DMA test).

Regression tests **PASS**: v1519 direct physical directory mount
with seven mutations; v1520 legacy format/target-MKFS/native
mount with five mutations; v1522 mounted identity and poison
with eight mutations. Their native fixture linkage now includes
the V2 record validator where the production mount source
calls it; the older test scenarios and policies remain intact.

Reproduce from `daimos-testkit`:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-v2-ro-admission-v1555.sh
sh tests/validation/daimos-dtfs-v2-ro-write-guard-v1555.sh
sh tests/validation/daimos-dtfs-v2-probe-v1555.sh
sh tests/validation/daimos-dtfs-mount-native-verify-v1519.sh
sh tests/validation/daimos-dtfs-volume-id-v1520.sh
sh tests/validation/daimos-dtfs-mounted-id-v1522.sh
```

## Remaining work

**P0-B is NOT complete.** V2 is intentionally admitted READ-ONLY.
The v1551-v1554 durable marker, MM scratch and per-mount gate
are still not attached to the production writable DTFS path.
No DTVOL2 write transaction, owner-safe CLEAN/unmount, physical
full-guest Type-551 partial-write/reinsertion or cold-boot
acceptance is claimed here. V2 RO read-fault recovery remains
conservatively fail-closed under the old DTVOL1 identity-recheck
routine until a version-aware replacement is implemented.

The hardware tape-exchange race between physical RBN0 and later
DATA transfers remains an open safety question for writable V2.
This read-only cutover does not claim to solve it.

P0-A complete; P0-B OPEN; P1-C separate. No optimization performed.

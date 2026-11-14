# v1554: actual PDP-6 DTVOL2/DIRTY revalidation before further writes

Date: 2026-11-14. Source-linked DTFS durability acceptance, **not a
booted full-guest physical Type-551 or deployed mounted DTFS test**.

The v1553 first-write gate previously allowed a mounted volume with
its volatile `INTENT_ARMED` bit set to return immediately. That was
not sufficient: Type-551 DECtape media can be removed or replaced
after the first successful WRITE_INTENT arm. v1554 changes that
return path into a mandatory **fresh physical RBN0 read** under
the same provider lease before every subsequent DATA/DIR write.

## Production source under test

`DAIMOS/system/kernel/fs/dtfs_intent_verify_v1554.s` is a
standalone PDP-6 service with the same four-register ABI as v1551:
physical unit, 36-bit high ID, 36-bit low ID, independent pinned
128-word scratch. It clears scratch before raw Type-551 RBN0 READ
to prevent accepting a previously cached DIRTY block after a
short/false-successful transfer. It calls the unchanged native
v1550 validator and requires exact DTVOL2/WRITE_INTENT and both
previously saved ID halves. The operation **never writes media**.

On a failed physical read, malformed or CLEAN RBN0, or changed
identity, it invalidates BCACHE and marks the actual unit with
sticky WRITE_UNCERTAIN. An old-style READ_SUSPECT that can later
be cleared by a mere identity check is not sufficient: a missing
WRITE_INTENT record must not become a writable volume. A null
scratch or zero expected ID is refused before physical I/O.

The existing `dtfs_intent_owned_arm_v1552.s` now exposes a
`dtfs_intent_owned_verify_v1554` entry. Both modes share the
same 0200-word MM_TYPE_KERNEL_DYNAMIC owner 015 allocation,
`mm_pin` before physical I/O, `mm_unpin` after I/O, exact-owner
`mm_free`, and caller-retained base on a refused cleanup. No
second permanent scratch table or duplicate MM allocator was
introduced. The original v1552 ARM entry and its ABI remain.

`dtfs_intent_first_write_v1553.s` now calls this owned verifier
whenever the mount already carries `INTENT_ARMED`. It no longer
authorizes a second write directly from that RAM bit. Both a
newly armed and previously armed transaction recheck the media
word, the two stored identity halves and the retained scratch
base **after** physical I/O returns. An altered mount, poisoned
media, or unfreed buffer refuses authorization.

## Executed test suites

`daimos-dtfs-physical-verify-v1554.sh` generates actual opt-in
DTVOL2 and old DTVOL1 images with production host `mkdtfs`,
decodes their two physical 18-bit lanes per 36-bit word, and
links the actual native v1550 validator and v1554 verifier to a
strict Type-551 I/O response oracle. **17 PDP-6 cases PASS**:
genuine DIRTY header, CLEAN header, legacy DTVOL1, all-zero
legacy, a distinct well-formed ID in either half, torn checksum,
nonzero reserved padding, raw read error, incomplete physical
prefix with false success, zero expected ID halves, null scratch,
repeated successful read, no actual bytes despite apparent
success, unknown checked state and changed magic. Each checks
result, raw read count, exact WRITE_UNCERTAIN marking, BCACHE
eviction, zero physical writes and intact pending user DATA.
**10 unsafe source mutations are rejected** by the native test.

`daimos-dtfs-armed-gate-v1554.sh` exercises the actual v1553
per-mount gate with the v1554 physical/MM boundary stubbed.
**23 PDP-6 scenarios PASS**, including physical verification
failure, media becoming uncertain during the read, both saved
identity halves changing during I/O, and outstanding MM ownership.
**8 new unsafe source mutations are rejected**, including
skipped physical recheck and ignored post-I/O identity checks.

`daimos-dtfs-verify-real-mm-v1554.sh` links the modified shared
MM wrapper to the **actual production PDP-6 no-reclaim MM
allocator, pin, unpin and free instructions**. It completes two
verified MM leases and then refuses a no-arena allocation before
I/O. Four unsafe mutations are rejected: dispatching ARM instead
of VERIFY, omitting the pin, failing to unpin, or failing to free.
The physical service is simulated only in this MM test; it is
exercised separately by the first native test.

The preceding v1552 and v1553 native regression scripts remain
the compatibility checks for the original source entry points.

Reproduce from `daimos-testkit`:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-physical-verify-v1554.sh
sh tests/validation/daimos-dtfs-armed-gate-v1554.sh
sh tests/validation/daimos-dtfs-verify-real-mm-v1554.sh
sh tests/validation/daimos-dtfs-owned-scratch-v1552.sh
sh tests/validation/daimos-dtfs-first-write-v1553.sh
```

## Hard remaining requirements

All new entries are still **UNLINKED** from the production
mounted DTFS provider. Current live DTFS has no DTVOL2 mount
admission, mandatory DATA/DIR gate routing, persisted provider
MM scratch pointer or exclusive owner-safe final CLEAN seal.
Native controlled Type-551 I/O proves the source computation,
not physical media/interrupt/DMA or complete cold reboot.

Even a fresh physical RBN0 read followed by a DATA write has a
hardware removable-media time-of-check/time-of-use boundary.
The provider lease excludes other filesystem actors, but does
not mechanically lock the operator out of removing the tape.
The remaining full-guest tests and any hardware media-generation
contract must address that residual risk before P0-B closes.

P0-A complete, P0-B OPEN, P1-C separate. No optimization.

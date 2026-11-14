# v1556: native DTVOL2/CLEAN mounted read-fault recovery

Date: 2026-11-14. Production DTFS MRES read-only recovery
feature, not the writable durable-transaction completion.

## Problem closed by this increment

v1555 made correctly sealed DTVOL2/CLEAN volumes mountable
read-only. However, the old `dtfs_identity_revalidate_v1522`
recovery path accepted only DTVOL1/zero syntax. One transient
physical read fault would leave a perfectly valid V2 tape
permanently READ_SUSPECT until an administrative unmount,
even if its original medium returned unharmed.

The real native routine now reads RBN0 physically when the
published mount carries READ_SUSPECT. It clears the entire
shared 0200-word workspace after invalidating its BCACHE tag,
so an incomplete Type-551 transfer that falsely reports
success cannot reuse an old complete CLEAN stamp.

The routine saves its original mounted media word AND slot on
the process-private kernel stack across the sleeping read.
It selects the production v1550 DTVOL2 parser only when the
original media word has FORMAT_V2; for V1 mounts it still
calls the original four-word V1/legacy parser. V2 requires
the *exact* CLEAN state, all 122 zero padding words, and both
checksum words; DIRTY and malformed records never recover.
Both ID halves must equal the saved MM per-mount identity.

After I/O and ID validation, the routine verifies that the
entire original media word remains unchanged. V2 additionally
requires a still-published DTFS root with the original public
mount ID, and the same VFS slot must still have READONLY set.
Only then is READ_SUSPECT cleared, preserving FORMAT_V2,
INTENT_ARMED, WRITE_UNCERTAIN and the 18-bit UID/GID owner.
WRITE_UNCERTAIN refuses before physical I/O and is never
cleared by identity revalidation.

## Source-linked native acceptance

`daimos-dtfs-v2-revalidate-v1556.sh` builds the actual host
`mkdtfs` formatter and creates two independent opt-in V2
and one default V1 DECtape images. It extracts the physical
RBN0 36-bit words from the original two 18-bit little-endian
lanes of each image. The actual production PDP-6 recovery
and V1 parser and unchanged v1550 V2 parser are all linked;
only the raw Type-551 I/O completion is a controlled oracle.

**29 native scenarios PASS:** original V2/CLEAN recovery, owner
preservation, no unnecessary physical read on a healthy mount,
DIRTY refusal, another well-formed volume, downgrade to V1 or
all-zero legacy, torn seal, nonzero padding, unknown checked
state, zero high/low ID with repaired checksums, wrong magic,
raw I/O failure, partial/empty false-success reads, changed
mounted WRITE_UNCERTAIN bit or saved high/low ID during I/O,
loss of RO, changed provider or public mount ID before or
during I/O, and both real V1 recovery and V1 replacements.

**14 unsafe actual-source mutants rejected** by the native
oracle: bypassing full V2 parsing, admitting DIRTY, choosing
wrong format, leaving stale scratch, ignoring physical errors,
skipping saved ID halves, ignoring WRITE_UNCERTAIN, failing
to compare mounted media after I/O, wrong provider/mount,
ignoring RO, preserving stale BCACHE tags and using a wrong
physical RBN. The original v1522 regression (including its
eight unsafe-source mutants) is also PASS with the new V2
validator linked as required.

Reproduce from `daimos-testkit`:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-v2-revalidate-v1556.sh
sh tests/validation/daimos-dtfs-mounted-id-v1522.sh
```

## Boundaries and remaining P0-B features

This is a source-linked PDP-6 test against physically formatted
image records, not an actual full-guest Type-551 controller
interrupt/DMA or tape reinsertion test. No V2 writable mount
or DATA/DIR mutation is enabled. The independently tested
v1551-v1554 physical DIRTY barrier and pinned MM helper still
require mandatory provider write-path integration, durable
scratch ownership, and an exclusive owner-safe CLEAN/unmount.
The TOCTOU boundary of removable media between a physical
RBN0 check and the eventual DATA write remains open.

P0-A complete. P0-B OPEN. P1-C separate. No optimization.

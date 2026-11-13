# v1525 source-linked fixture correction (2026-11-13)

The v1520 native PDP-6 mount fixture was still encoding the
directory's reserved owner at assembly `media_dir+014` (octal
index 12), a stale test assumption inherited from v1519.
The actual native format uses C `dir[14]` (decimal) which
is assembly octal `+016`. Both valid test-media setup and
the deliberately corrupted directory-owner case now
use the correct offset. The v1520 host stamp/checksum,
target MKFS identity-clear, native positive admission and
all five identity mutations PASS against the corrected
production source. No on-media format was changed.

# KCORE v1520: optional native DTFS persistent volume identity groundwork

Date: 2026-11-12. Scope: host `mkdtfs` identity producer; actual
target userspace `DTFSPROBE` and `MKFS.DTFS` source; native PDP-6
kernel mount admission with a retained per-mount 72-bit identity.
Not yet an online media-replacement or live FILE recovery protocol.

## Format and backward compatibility

Physical DTFS RBN 0 is reserved in the native allocation map and was
zero-filled by official native V1 formatters. The V1520 optional record
uses four 36-bit words there; the original RBN 0144 native directory,
magic, file names, allocation map, data block numbers and file ABI
remain unchanged.

| RBN 0 word | Identity-stamped native DTFS |
| --- | --- |
| 0 | SIXBIT `DTVOL1`, octal `0446466575421` |
| 1 | Nonzero random high 36-bit ID |
| 2 | Nonzero random low 36-bit ID |
| 3 | `~(word0 ^ word1 ^ word2) & 0777777777777` |
| 4..127 | Zero; reserved for future versions |

An entirely zero block is **legacy**, not a stamped identity.
Any nonempty malformed block is rejected: it is never reinterpreted
as legacy after an invalid signature, checksum, zero half or padding.
The 72-bit random equality token has probabilistic collision resistance
for independent volumes; it is NOT cryptographic authentication.

Host `mkdtfs` obtains nine bytes from `/dev/urandom`, packing 72 bits
into the two native 36-bit words without inventing entropy from time.
It refuses creation if randomness is unavailable, and continues to
create the destination exclusively with `O_EXCL`. The existing native
directory content is unchanged. The host producer uses the common
`system/kernel/fs/dtfs_identity_v1520.h` format definitions.

The target `MKFS.DTFS` does not have a sufficiently trustworthy native
random source. Rather than reuse an OLD stamp or pretend to generate a
unique one, it zeroes the entire reserved block 0 BEFORE writing the
new native directory. If that initial physical write fails, it aborts
without publishing the new directory. Therefore target-native MKFS
creates explicit legacy media; host-formatted native media are stamped.
This distinction is documented and is not a recovery capability.

The actual userspace `dtfs_probe_unit` checks block 0 after a valid
native directory read. It reuses the existing transfer buffer for the
identity block, adds no second 128-word buffer, and accepts all-zero
legacy while refusing malformed/missing stamped records.

The actual native PDP-6 `dtfs_mount_unit` independently reads and
validates the physical identity block before VFS publication; it does
not trust the userspace probe or BCACHE. Across VFS publication,
both ID halves are held on the caller's own temporary stack, then
stored in the two EXISTING dynamic per-mount SHAPE and EXTENT words
otherwise used only by TSFS mounts. A DTFS mount and a TSFS mount
cannot occupy the same VFS slot. No slab expansion or fixed RAM words.
Legacy mounts store zero/zero, signaling *absence* of verified ID.

## Executed tests

`daimos-dtfs-volume-id-v1520.sh`:

- Compiles real host `tools/host/mkdtfs.c`, creates two different
  complete tapes, verifies their separate random 72-bit identities,
  checks marker, complement checksum, all zero reserved padding,
  physical image size and unchanged native directory magic/owner.
- Compiles the actual `userland/dtfs/dtfs_probe.c` under C89 with
  only physical DTC read stubs. Positive stamped and legacy probes
  pass; checksum corruption, nonzero padding, partial header,
  zero ID half, unreadable header, nonnative directory and invalid
  DTC unit all fail closed.
- Compiles actual `userland/exec/commands.c` as native MKFS command.
  Negative test verifies that failure clearing block 0 prevents the
  later directory write; positive test verifies exactly ordered
  block0-clear THEN native directory publication using one buffer.
- Source-links the real PDP-6 `dtfs_mount_unit` and production BCACHE
  invalidate leaf with a normal VFS publication/physical DTC callback.
  It first replays the entire v1519 legacy-format regression; then
  verifies stamped 72-bit mount identity in both MM slab words,
  rejection of corrupt checksum, nonzero padding, partial record
  and unreadable RBN0, with identity and VFS publisher unchanged
  after failures. The same valid ID can be admitted again, but the
  test does NOT model live open FILEs or automatic recovery.
- Five actual native PDP-6 unsafe-source mutations are rejected:
  omitted checksum, ignored padding, treating any nonempty header as
  valid, skipping high ID publication and skipping low ID publication.

All v1520 host/C89/PDP-6 cases and five native negative mutations PASS.
The older v1519 native mount-admission and its six negative mutations,
v1518 DTFS/BCACHE I/O error, v1490 BCACHE ABI/MM refusal, and legacy
DTFS chain/create/unlink/rename/dirfield tests also PASS. Both full
isolated 256K KCC and 32K GCC tape-root KINIT/DTFS/TSFS MRES builds
LINK. KCC also compiles target MKFS.DTFS and DTFSPROBE objects.

The strict **32K fixed-KCORE size gate remains FAILED** at
`__kcore_low_end=023241` octal versus required `<020000` octal.
A controlled old/new link with identical other objects and independent
p10fold plans gives **+46 optional MRES instruction words, zero new
permanent data words and zero fixed KCORE words**. The extension
consumes no new MM per-mount space, since DTFS reuses its otherwise
unused TSFS shape/extent entries.

## Explicitly unimplemented

The v1520 stored identity is NOT yet checked on every post-error
retry or on silent physical media change. A mounted DTFS device may
still serve cached hits without discovering that a different tape
has been installed. Existing open FILEs, dirty directory state and
mount-slot reuse are not yet safe for **automatic replacement**.
Legacy tapes have no identity, so they cannot be auto-reattached
with authenticated continuity. The target formatter's legacy
format is supported for compatibility, not as proof of identity.

Type-551 physical loss classification and fatal TSFS-root-member
dispatch remain the independent P0 feature gate; they are not
implemented here. The next non-root feature is an explicit checked
identity/revalidation state transition that blocks stale vnode/FILE
access before allowing another physical tape to inherit the mount.

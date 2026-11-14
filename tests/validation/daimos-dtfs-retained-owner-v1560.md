# v1560: retained DTFS MM scratch ownership across VFS slot lifetime

Date: 2026-11-14. KCORE feature-completion acceptance, **P0-B OPEN**.

## Source and memory design

VFS already allocates one boot-inventoried, MM-backed, six-array
mount slab, including a one-word `reader` auxiliary slot for each
mount. D6FS stores its precisely owned MM reader there; it frees
the reader and zeros that word before its successful unmount.
Because each published VFS mount slot belongs to exactly one
filesystem provider, the same *existing* word can hold the
eventually retained DTFS 0200-word physical RBN0 intent-scratch
extent. The v1552 service's `basep` argument can be the address
of this word: failed pin/unpin/free leaves the exact owned base
there rather than losing it on a process's transient stack.

Production `fs_mres.s` now gives `vfs_mount_aux_base_v1560`
the same address as `d6fs_reader_slots_base` (the native KCORE
linker map independently confirms their address equality). The
KINIT mount slab, six arrays, boot-sized allocation and provider
owner tags are **unchanged**. No new fixed KCORE word, per-mount
word, or permanent pointer table is allocated.

The actual native `vfs.s` defines `vfs_dtfs_aux_empty_v1560`
for a checked zero-based slot: invalid slot, absent MM table,
or nonzero retained scratch base returns -1 without changing
anything. Its new production call sites are:

- VFS DTFS mount publication: before publishing a new DTFS
  root/owner in the selected slot; a retained MM pointer cannot
  be overwritten by a recycled mount ID.
- Final VFS DTFS unmount: after all potentially sleeping SYNC/
  PREPARE work and the final FILE/cwd/PIPE/swap owner recheck,
  but before owner unlock and slot retirement.
- Administrative DTFS poisoned-slot discard: both **before**
  the physical replacement-read provider request and again
  after it returns and final owner checks pass. A pending scratch
  base cannot be lost through a replacement or a reused slot.

The check is DTFS-specific. D6FS already owns its reader-slot
lifecycle, including its preseeded root reader during KINIT;
it must not be rejected merely because its legitimate reader
base is nonzero. No V2 physical writes are enabled.

## Native acceptance and regressions

`daimos-dtfs-mount-aux-v1560.sh` links and executes the **actual
PDP-6 helper** across **16 cases PASS**, including both slots,
independent owner pointers, missing MM table, invalid capacity,
negative/out-of-range slot, preserved arguments and no state
mutations. **Five unsafe instruction mutations rejected**.

`daimos-dtfs-aux-lifecycle-v1560.sh` extracts and executes the
**actual VFS mount-publish and after-prepare unmount instructions**
with a controlled VFS/owner boundary, checking publications,
retire/unlock counts, unchanged retained pointers, D6FS root
reader compatibility and DTFS denial. **14 native PDP-6 cases
PASS; five unsafe instruction mutations rejected.**

`daimos-dtfs-aux-retire-order-v1560.py` statically verifies
the real mount/unmount/admin-discard call ordering and shared
alias. It rejects **five unsafe source-order mutations**, including
discard of the owner before or after physical replacement I/O.
This source-level check complements, but is not itself a native
hardware or full guest test.

Existing native v1514 failed-media unmount/retry and v1523
all-process FILE/cwd ownership regression suites PASS after
providing their no-leak, zero-filled auxiliary test table.
The complete KCC full-profile KCORE and DTFS MRES assemble,
fold and link PASS. KCORE `kcore.map` assigns the same address
to `d6fs_reader_slots_base` and `vfs_mount_aux_base_v1560`.

Run from daimos-testkit:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-mount-aux-v1560.sh
sh tests/validation/daimos-dtfs-aux-lifecycle-v1560.sh
python3 tests/validation/daimos-dtfs-aux-retire-order-v1560.py "$DAIMOS_REPO"
sh tests/validation/daimos-nonroot-unmount-retry-v1514.sh
sh tests/validation/daimos-file-mount-busy-v1523.sh
```

## Important limitations

v1560 installs the **storage and VFS retention barriers**, not
the producer of the retained pointer. In particular the
v1552 MM-pinned `basep` service and v1553-v1554 physical
DIRTY-before-write gateway are NOT yet called by the live
`dtfs_dtc_write` veneer. There is no writable DTVOL2 admission,
no final on-media CLEAN/unmount, no verified physical Type-551
partial-write/reinsert/cold-boot transaction, and no proof of
the removable-media change race between marker read and DATA
write. No MM allocation is newly performed by v1560.

Next: pass the actual checked per-mount auxiliary word into the
existing v1552 `basep` ABI under the serialized filesystem
lease, then protect every data/directory mutation and implement
exclusive owner-safe CLEAN/unmount before enabling V2 RW.

P0-A complete; **P0-B OPEN**; P1-C separate. No optimization.

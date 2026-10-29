# v688: resident VFS mount and cache ownership audit

KINIT's `vfs_mount_slab_v4_prepare()` provides six MM-backed arrays:
reader, media, shape, extent, target and root. KINIT publishes their
individual base addresses in KCORE and publishes `vfs_mount_limit` last.
The six pointers are resident, but the arrays themselves are not permanent
KCORE storage. Their separate publication is required by current consumers.

VFS mount policy is already a single packed 36-bit word containing a
read-only bitmap and two owner fields. Replacing six base pointers with
one slab base would require reconstructing addresses throughout the VFS and
MRES paths and cannot be called a saving without linking that replacement.

The block cache reuses the existing 128-word filesystem workspace as slot
zero, with a single resident workspace tag. Its optional second slot is
allocated as a 0201-word MM slab (tag plus 0200 words), and is reclaimable.
The fixed cache controls consume two words (`bcache_state`,
`bcache_workspace_tag`).

This inspection found no duplicated resident mount arrays or cache block
buffer to remove. The regression guards these invariants; no production
source change was justified. It is a focused source audit, not proof that
other filesystem or kernel allocations are duplication-free.

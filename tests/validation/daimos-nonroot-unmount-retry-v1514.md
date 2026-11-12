# KCORE v1514: non-root unmount after failed sync and media return

Date: 2026-11-12. This is an actual native PDP-6 source-linked
VFS ordering test, not a full guest media-unplug acceptance.

The v1513 policy states that permanently lost root/BACKSTORE
media is terminal, while unavailable mounted non-root filesystems
should remain recoverable. v1513 already verified a negative
D6FS backing read and a successful retry when the same secondary
device returned. v1514 checks the next critical VFS boundary:
**an unmount may not retire a mount while its sync fails**.

`daimos-nonroot-unmount-retry-v1514.{s,sh}` source-links the
real `vfs_unmount` and `vfs_mount_retire_slot` instructions from
`DAIMOS/system/kernel/fs/vfs.s`. Its two independent registered
mounts are root D6FS public ID 1 and secondary D6FS public ID 2.
Only the secondary's serialized sync callback is failed while
its media is unavailable. The test executes with the PDP-6
instruction simulator, not a reimplementation of the VFS branch.

On failed sync, `vfs_unmount` returns -1; the original secondary
mount root/target, read-only bit and namespace root are retained;
neither provider preparation, FILE unlock nor slot retirement
occurs. When the *same* media is marked available, another real
`vfs_unmount` call completes sync, passes D6FS preparation,
unlocks the secondary FILE owner and clears exactly its mount
root, target and read-only bit, leaving the root slot unchanged.
Exact call counts are two sync attempts, one preparation and one
FILE unlock. This is fail-closed recovery of the VFS teardown
sequence, not a forced unmount while the device is missing.

Three *executed* unsafe-source mutations are rejected:

1. Bypassing the result of the failed sync.
2. Omitting real mount-slot retirement after accepted cleanup.
3. Omitting FILE mount unlock after accepted cleanup.

The runner fails closed on source anchor drift and also rejects
mutants that never actually reach the PDP-6 execution oracle.
Baseline and all three negative tests PASS.

Scope limitations: sync and provider callbacks are controlled
at the native test boundary, not backed by an actual detached
physical D6FS unit. The test does not show successful remount of
different replacement media, superblock revalidation, real
BCACHE flush/invalidation, dirty uncommitted data handling or
open-file/pinned-vnode recovery. Those remain future KCORE
feature gates. Production KCORE source, ABI, RAM and on-media
format remain unchanged in v1514.

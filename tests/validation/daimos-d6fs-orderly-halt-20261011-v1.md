# D6FS orderly HALT / DSH HISTFILE restart regression — 2026-10-11 v1

Rebuild an isolated PDP-6 DSK boot image using the current-source host tools
(`mkd6fs`, `mkdsk`, `d6fsck`). Keep the same D6FS disk files for both boots.
Run the v6 SIMH harness with ROOT login and
`probes/daimos-dsh-histfile-orderly-halt-20261011-v1.txt`.
After the process exits, run current-source `d6fsck -n 4 -d DISK_DIRECTORY`.
Require CLEAN. Then reboot the same disk with
`probes/daimos-dsh-histfile-reboot-20261011-v1.txt`.

Observed: first boot 3/3 PASS, `d6fsck` selected superblock 705 sequence 3
CLEAN (179196 blocks, 336 FCBs). Second boot 1/1 PASS; `/.DSH_HISTORY`
retained the command recorded before HALT.

The kernel HALT path runs MEMFS shutdown then `vfs_shutdown_root`, which
checks the D6FS namespace root and mount read-only bit, syncs, then uses
the existing serialized VFS remount operation to publish CLEAN. Publication
failure is fatal to shutdown (HALT must not proceed). The routine does not
turn an already-CLEAN root DIRTY.

This verifies one ROOT login, writable D6FS root, orderly HALT and immediate
reboot. Failure injection and concurrent history writers are not yet covered.

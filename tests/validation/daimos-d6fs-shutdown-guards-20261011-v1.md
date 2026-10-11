# D6FS HALT guard validation — 2026-10-11 v1

The host check `tests/host/daimos-d6fs-shutdown-guards-20261011-v1.sh`
checks the assembled-source control-flow contract at the boundary between
`vfs_shutdown_root` and the privileged HALT syscall. The checked properties:

- No D6FS transition for an absent namespace root or non-D6FS root.
- Invalid mount IDs fail rather than indexing an untrusted slot.
- An already-read-only D6FS root bypasses the remount toggle.
- The writable path synchronizes before remount publication.
- Any sync or publication failure prevents execution of HALT.
- The existing MEMFS shutdown still precedes D6FS shutdown.

This test **does not inject a device write failure**, execute a read-only-root
SIMH boot, or test concurrent HISTFILE updates. These remain OPEN and need
separate live regression cases. It also cannot prove the correctness of
assembly conditional branching independently of machine execution.

The earlier live writable-root integration acceptance is recorded in
`tests/validation/daimos-d6fs-orderly-halt-20261011-v1.md`: first-boot
history/HALT 3/3 PASS, CLEAN D6FS superblock and same-disk reboot 1/1 PASS.

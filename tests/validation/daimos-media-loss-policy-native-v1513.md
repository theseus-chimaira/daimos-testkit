# KCORE critical/non-root media-loss boundary, native v1513

Date: 2026-11-12. User-selected fault policy: *confirmed* loss of
the boot root or BACKSTORE is terminal; a mounted non-root
filesystem must be permitted to recover when its media returns.
Temporary controller errors and 300-tick watchdog timeouts are
not reliable evidence that a physical medium is permanently gone.

## Source sweep

- `drivers/dsk_io.s` and `drivers/drm236_io.s` return generic
  negative completion on hardware error or watchdog expiration.
  Neither currently provides a distinct persistent-media-loss
  status, even though each accounts errors and retires live I/O
  descriptors correctly.
- `storage/fs_backing.s` propagates a negative backing callback
  result; the special root adapter additionally accounts D6SET
  logical errors. This is an individual I/O error, not proof of
  persistent loss. The direct adapter's separate root marker
  already distinguishes logical boot-root I/O from non-root units.
- `proc/proc_swap_pdp6.s:proc_swap_in_read_fail` rolls back MM
  while preserving the DISK owner; its service schedules bounded
  retries and pending TERM. Existing v1511 and v1512 full-guest
  tests deliberately recover after two real error-path failures.
  A universal panic on first negative read would regress them.
- `fs/d6fs_runtime.s:d6fs_reader_get_block` returns NULL after
  backing read failure and does not publish a BCACHE hit. Its
  real mount identity remains separate from the failure result.
- `fs/vfs.s` preserves mounted provider state on an ordinary
  negative filesystem I/O result. Mount teardown requires busy
  checks and a successful sync, so disappearing media must not
  be silently treated as a successful unmount. Existing
  `vfs_remount_to` does not constitute replacement-media
  verification or BCACHE invalidation.

## Source-linked native test: PASS

The new `daimos-nonroot-media-return-v1513.{s,sh}` links the
production D6FS block reader and `fs_backing_read` dispatcher
into a PDP-6 instruction-execution test. It models two independent
D6FS backing identities (root mount ID 1 and secondary mount ID 2)
and makes only the secondary physical callback return -1.

The secondary returns NULL on two failed reads with **zero
cache-store publications**; the unaffected root read returns
the correct original data. When the original secondary callback
becomes available, it succeeds through the same source-linked
reader and publishes the expected cache entry. A second failure
again returns NULL without publishing a cache entry; another
return to service succeeds. The two mount IDs remain unchanged.

Three *executed* negative mutations are rejected:

1. Branching on success rather than failure at the D6FS callback.
2. Returning a success-looking value from the read-failure leaf.
3. Bypassing the real backing callback and manufacturing success.

The older D6FS mount-isolation test initially failed at link
because its extracted runtime slice now references
`fs_backing_read`. Its standalone mount oracle was repaired with
a fail-closed, unused stub and now PASSes; the v674 D6FS remount
source gate and v9 VFS mount mutation also PASS. This correction
does not alter production KCORE or its filesystem interface.

## Accepted and open

**ACCEPTED:** native callback failure, clean retry when the
*same* secondary media becomes available, independent root
backing, and rejection of false clean cache publication. These
are source-linked D6FS logic checks, not a full physical
hot-unplug/reattach simulation or an automatic mount recovery API.

**OPEN:** authoritative classification of confirmed permanent
critical media loss; minimal runtime fatal diagnostic and halt;
full physical root/BACKSTORE loss acceptance; non-root media
identity/superblock verification, recovery/remount sequence,
dirty data handling and BCACHE invalidation for *replaced*
media. Do not classify one generic -1 or a transient timeout
as permanent loss, force-close a live foreign process, or let
a stale BCACHE hit validate a different medium.

No permanent kernel code, RAM, ABI, on-media format or process
state was added for this step. The root/BACKSTORE decision is
**crash-only** after confirmed loss, not resource reconstruction.

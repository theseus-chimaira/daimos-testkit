# KCORE v1526: physical DTFS cross-process cwd/FILE ownership

Checked on 2026-11-13 against the unchanged v1525
KCC tape-root KCORE and DTFS/TSFS MRES image.

## What actually ran

`daimos-dtfs-cross-owner-fullguest-v1526.sh` reuses
the real physical DTC0-2 TSFS boot and stamped
independent native DTC3 media from the v1525
full-guest runner. A new disposable user
`daimos-dtfs-cross-owner-v1526.c` is compiled
with the production KCC runtime and placed at
`/SYSTEM/INIT` in the **test-only** root image.
It uses no simulated provider, controller or VFS.

Real PID 1 mounts DTC3 read-only as native DTFS
and independently checks FSINFO provider 5 and
`/MOUNT/DT0`. PID 1 then uses the actual RUN V2
syscall to launch a **second** instance of its
executable as a different PID, with two separate
real kernel pipes mapped as control and readiness
descriptors. Exact one-word acknowledgment tokens
synchronize all transitions without sleep guesses.

1. The child enters `/MOUNT/DT0`, ACKs its cwd,
   and blocks until the parent releases it.
   The parent is in `/` and has no DTFS FILE;
   a real UNMOUNT must fail and FSINFO must
   still report the original DTFS mount.
2. The child opens the DTFS directory as a real
   FILE, exits that cwd back to `/`, ACKs,
   and waits. The parent again must see
   UNMOUNT fail with only the **other process's
   FILE** retaining the physical mount.
3. The child closes its FILE and ACKs, remaining
   blocked alive on the release pipe. The parent
   additionally checks actual PROCINFO for the
   child's PID and non-zombie status. UNMOUNT
   must now succeed and FSINFO must show the
   retired slot empty **before child exit**.
4. The parent releases the child and reaps it
   through the real WAIT syscall. The child
   must exit normally with status zero.

Final real CTY output includes exactly the
`DTFSCROSS V1526` milestones `START`,
`MOUNTED`, `CHILD_START`,
`CROSS_CWD_REFUSED`, `CROSS_FILE_REFUSED`,
`CROSS_RETIRED`, `CHILD_DONE`, `PASS`.
The full-guest script returned success after
checking the ordered markers and absence of
FAIL output. Strengthened second run also checks
parent cwd '/', child PID greater than 1, and
actual live child PROCINFO before retirement.
Both runs PASS. The v1525 test harness retains
its original default gate and stages; only
explicit v1526 environment variables select
the new disposable executable.

## Significance and limits

This closes the **cross-process owner lifetime**
part of P0-B, including no premature slot reuse
when either another process's cwd or FILE is
live. The v1523 production owner scan needed
no change: it already behaved correctly on
actual physical mounts. No new KCORE or optional
MRES resident words, no new kernel state,
no module-policy change and no optimization.

Real Type-551 detach, DTVOL1 return/mismatch,
partial-write WRITE_UNCERTAIN and explicit
administrative recovery remain distinct P0-B
work. No P0-A fatal physical-loss verdict is
implied by this test.

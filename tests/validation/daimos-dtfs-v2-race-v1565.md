# v1565: scheduled PDP-6 DTFS quiescence / owner publication race

Date: 2026-11-14. **Actual full-guest two-process scheduler PASS.**
P0-B remains OPEN; DTVOL2 remains read-only.

## Reproduce

```sh
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-v2-race-v1565.sh
```

The script normally builds an isolated current 256K KCC/TSFS-root
image. For a source-matched current existing full build, set
`DAIMOS_V1565_BASE_BUILD` to its actual directory. The script always
COPIES it first; `V1565_KEEP_WORK=1` preserves the disposable copy,
KCORE maps, simulator logs and full physical tape evidence. No files
in the production DAIMOS checkout or in the supplied base build
are modified.

## Deterministic scheduling boundary

The actual VFS v1562 code acquires its exclusive V2 quiescence bit
after the first PIPE/swap/FILE owner scan and before `vfs_sync`.
The existing production source is copied without change into an
isolated `kcore-asm/vfs.s` except for the test-only injection:

- If the acquisition result is V2 (1), call real
  `proc_sleep_ticks` for 768 PDP-6 ticks, then resume the original
  VFS SYNC path.
- If acquisition is legacy (0), skip the delay.
- Export one versioned label for verifying the ordinary KCC KCORE
  assembler/fold/link/boot image actually includes the delay.

The original VFS owner checks, `vfs_dtfs_owner_admit_v1562`,
DTFS provider dispatch, `vfs_sync`, unmount retirement, process
scheduler, proc wait/wakeup and Type-551 read paths are not altered.
This is a controlled longer instance of the normal possibility
that the provider sleeps after the barrier is acquired, NOT a
simulated provider completion. The test does not claim that a
natural tape SYNC delay of this length occurs without injection.

## Guest acceptance

PID1 mounts an independently formatted, physically validated
DTVOL2/CLEAN DTC3 read-only. It RUNs another genuine process from
`/SYSTEM/INIT` and uses two real anonymous pipes to coordinate it.
The child owns NO DTFS cwd or FILE when PID1 begins unmount.

PID1 sends a token, calls UNMOUNT and acquires the real V2
barrier. The test-only sleep permits PID2 to run. PID2 calls the
production FSINFO syscall for slot 1 until it observes the actual
DTFS provider SPACE refusal (-1). Before quiescence, a valid
mounted slot returns 1; after retirement, the empty slot returns 0.
The child treats a zero result before observing the barrier as a
test failure, so scheduling that misses the window cannot PASS.

With the mounted, sealed slot witnessed, PID2 attempts a real OPEN
and CHDIR of `/MOUNT/DT0`. **Both MUST refuse**, and `GETCWD`
must still be `/`. PID2 sends a success report and waits on the
other pipe. PID1 finishes actual SYNC, owner/MM rechecks and VFS
retirement. It verifies the mount slot is empty before taking the
child's earlier race report, then releases the child.

After retirement, the *underlying* `/MOUNT/DT0` directory on
the TSFS root must again permit ordinary OPEN/CHDIR. This is not
a stale DTFS owner: the DTFS public slot must remain empty both
before and after these operations. The child changes back to `/`,
closes its handles and exits cleanly. PID1 waits and checks the
exit status. The harness also independently compares whole-tape
SHA-256 before/after the real guest.

Physical CTY proof:

```text
DTFSRACE V1565 START
DTFSRACE V1565 MOUNTED
DTFSRACE V1565 CHILD_START
DTFSRACE V1565 SEAL_OBSERVED
DTFSRACE V1565 OWNERS_REFUSED
DTFSRACE V1565 RETIRED
DTFSRACE V1565 RACE_PROVEN
DTFSRACE V1565 RETIRED_TSFS
DTFSRACE V1565 PASS
```

## Failed hypothesis corrected before acceptance

The first iteration of the guest wrongly assumed that reopening
`/MOUNT/DT0` after unmount must fail. This is incorrect: after the
VFS mount slot is retired, the original TSFS mountpoint directory
is legitimately accessible again. The first guest run produced
`FAIL_RETIRED_OWNER` even though the seal and admission race checks
already passed. The oracle was fixed to require *empty DTFS FSINFO*
plus valid underlying TSFS access and a second empty-slot check.
The corrected guest then passed all stage and full-tape checks.
No production kernel change or error workaround was introduced.

## Limits

This is deterministic genuine scheduler concurrency, but the
extended sleep is injected between acquiring the seal and entering
the physical SYNC. It does not demonstrate real simultaneous
in-flight Type-551 I/O, physical CLEAN writing/readback, removable
media exchange or partial physical RW failure. v1555's mandatory
V2 RO veto remains active. No production fixed KCORE or MRES
bytes, persistent RAM words or user-visible ABI changed.

Related earlier native source-link/mutation suites are v1562
owner/quiescence and v1563 staged PURE executable admission.
After the successful full v1565 physical race, all four prior
production-linked native suites were rerun and PASSed: v1562 V2
quiescence 41 cases/seven unsafe mutations rejected; v1562 complete
VFS unmount 12 cases/three mutations; v1563 PURE vnode/mount scans
26 cases/six mutations; and v1563 KCC C attach plus real VFS gate
11 cases/two mutations. No production source change was needed.

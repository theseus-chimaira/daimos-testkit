# P1-C v1593: exact second owner RESIDENT publication on physical PDP-6

Date: 2026-11-15. Full 128K KCC PDP-6, two cold boots, four genuine
Type-236 DR0..DR3 D6FSR2 root VOLUME members, mapped BACKSTORE,
LOGSTORE and persistent MEMFS/XIP. Production scheduler, MM, FSINFO,
storage provider, physical media format and installed KCORE unchanged.
No ABI or permanent RAM addition: all observers live in disposable
source-linked test copies and all guest behavior uses original syscalls.

## Original transaction and observer boundaries

v1593 retains the accepted v1584 original mapped physical swap PI2,
v1585 original timer frontier, v1588 selected post-DMA checked-release
refusal and v1592 two distinct SLEEP/DISK owner wakeup instrumentation.
At the exact original `proc_storage_publish_v30` successful return,
*after* `PROC_TRANSITION_RH` was cleared, a new read-only observer
compares original AC10 with the two selected real process slots.
It records the exact published process, resident VM base, original
post-commit process descriptor, swap record and the owning stable
u-area's authoritative disk-backing pointer. No extra call to the
scheduler, storage services, MM or PI handler is made.

The physical guest additionally uses original `dsys_fsinfo` to check
its selected **four-member DRM236 D6FS root** inventory: capacity
six, root provider 6 and public mount ID 1, MEMFS `/TEMP` provider
4 and mount ID 2, empty slots 2..5, invalid slots 6 and 7, and
stable capacity on a second query. Both boots emit the actual
`P1D-D6FS-DRM-CAPACITY6-V1593` stage before snapshot work.

## Accepted physical evidence

| Original linked source observation | Boot 1 | Boot 2 |
| --- | ---: | ---: |
| Timer-woken process slots | 6 and 7 | 6 and 7 |
| Real selected PI6 wakes | 1 / 1 | 1 / 1 |
| Slot 7 actual successful RESIDENT publications | 1 | 1 |
| Slot 7 real new aligned VM base | `0220000` | `0220000` |
| Slot 7 stable u-area backing pointer after success | 0 | 0 |
| Slot 7 original swap record after success | nonzero | nonzero |
| Slot 7 process transition after successful publication | clear | clear |
| Slot 6 successful publications in other transactions | 1 | 1 |
| Slot 6 checked-release refusal/rollback | 1 / 1 | 1 / 1 |
| Total original independent physical swap READs | 5 | 5 |
| Actual matching Type-236 PI2 swap completions | 1,120 | 1,120 |
| Total successful resident publications | 4 | 4 |
| Original D6FS DRM-root FSINFO capacity | 6 | 6 |

The earlier v1592 assumption that the slot selected for a later
checked-release refusal could **never have a successful previous
publication** was too strict. The new actual post-commit observer
shows one successful publication for slot 6, as well as one for the
independently woken slot 7. These are transaction events, not
permanent success/failure properties of a process. The original
v1588 refused transaction still preserves its exact MM/bitmap/
BCACHE/DISK owner and emits TERM without publishing the failed
transaction. No production bug or workaround was found.

Both original privileged HALTs normal; second boot recovers the
first boot's MEMFS/XIP and LOGSTORE before committing again. Raw
physical DR3 `017777` contains a valid v2 snapshot with a
3,648-word pool and 280 other nonzero backing sectors; every
original root-member descriptor remains intact. The verifier
rejects 10 new exact-publication/VM/backing/FSINFO mutants,
16 inherited v1592 owner/PI6/rollback mutants and 13 original
v1584 physical/scheduler/PI2 mutants: **39 negative controls**.

Retained physical evidence:
`$TMPDIR/daimos-p1c-owner-publish-v1593.Tom4Zl` including two
SIMH post-HALT transcripts, real drum member images, linked maps,
`v1593-physical-verification.txt` and `v1593-verifier-output.txt`.

Reproduce:

```
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
V1593_KEEP_WORK=1 sh \
    tests/validation/daimos-p1c-owner-publish-physical-v1593.sh
```

This closes the v1592 **specific successful owner** acceptance gap.
It does not test true owned-media loss as recoverable: original
critical BACKSTORE I/O errors remain fail-stop. P1-C still needs
later-stage mixed DEVICE/VOLUME/DTFS physical media failure,
dirty/write-through behavior, and repeated simulator-loaded timing.
The DRM-root FSINFO capacity-6 result is one P1-D hardware variant,
not provider-error acceptance. VERSION 0.5 and strict 32K/
optimization HOLD unchanged.

# KCORE physical Type-167/236 drum read-error propagation, v1511

Date: 2026-11-12. Production KCORE is unchanged; all observers and
fault injection are confined to a disposable full 256K KCC PDP-6
F07 guest. This is a **controller error-path** injection, not proof
that a real disk has lost magnetic media or all device service.

## Why this additional gate is needed

Physical v1508-v1510 proved permanently refused *checked release*,
original DISK ownership/TERM, native retry bounds, resident PID 5
fairness, and an independently swapped PID 011's checked restore and
execution. A rejected checked free occurs **after** the payload has
been read. It does not exercise the actual Type-167/236 controller
error status, its request wakeup, or the swap-in read-failure
MM unpin/rollback branch.

v1511 reuses the v1510 full guest, including genuine F07 MM pressure,
original selected bad slot, independent PID 5 SLEEP spinner and
delayed swapped PID 011. The original v1508 injector first selects
a real failed owner after a successful physical transfer and refuses
checked backing release while leaving the bitmap intact. For the
next two **real slot-0 reads of that exact owner**, the v1511
disposable observer tags its actual DRM private request descriptor
after `storage_request_init`. On Type-236 `DR_DONE` at PI2,
it redirects only that descriptor to existing
`drm236_pi_error`/`drm236_finish_active_v1079` code. This returns the
driver's actual negative completion to `backing_region_io` and
`proc_swap_in_read_fail`; the transaction must unpin/free its new
RAM extent and retain authoritative DISK/TERM/backing.

Subsequent reads of the bad owner use original hardware success
followed by the original checked-free refusal. Healthy separate
swapped process reads must remain unaffected. The real DRM error
counter `mfsdev_storage_errors+5` is sampled directly alongside
the number of test-selected PI2 errors. The test also distinguishes
read-error count from checked-free refusal count rather than
mislabeling one as the other.

## Strict acceptance and limitations

The v1511 verifier requires six or more real fault-on samples,
two injected Type-167/236 PI2 errors reaching actual DRM accounting,
and subsequent checked-free refusals still occurring. For each
sample, total source-linked slot-0 failed-service returns must
equal exactly **driver read errors + checked-free refusals**.
Original selected DISK run, stable u-area, nonresident VM, bitmap
accounting, retry marker and pending TERM must all remain intact.
No fake READY_ONCE, finalizer, zombie or successful reclaim is
allowed. Actual PID 5 progress and independent physical DISK-to-RAM
restore plus user SLEEP progress of slot `011` are also required.

The source-injection self-test rejects five unsafe changes to
driver and gateway call sites; verifier self-test rejects eleven
false accounting/rollback/restore/progress cases. All test code
must compile from a clean committed v1510 baseline as well as the
locally extended v1508 test fixtures. Only the full guest can
qualify the physical gate; a preparation/self-test PASS is not
a physical acceptance.

Run:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
sh tests/validation/daimos-backstore-device-error-physical-v1511.sh
```

`V1511_PREPARE_ONLY=1` creates and syntax-checks the disposable
runner and sampler without booting. The guest deliberately stops
after sufficient physical diagnostics; a permanently held owner
cannot pass the normal all-child HALT/WAIT completion gate.

The result will not establish actual failed hardware attachment,
complete media disappearance, disk-write failure, timeout under
lost PI2, or a way to free an irrecoverable private executive
owner. These remain explicit future KCORE DEVICE/media gates.

## Status

Five source-injection mutation self-tests PASS; eleven strict
verifier mutation self-tests PASS; generated runner and sampler
preparation PASS. The first physical v1511 attempt targeted the
**wrong DEVICE** (Type-270 DSK rather than the actual drum BACKSTORE
Type-236), yielding zero DSK error events during 27 checked-free
refusals. That attempt is explicitly REJECTED as a test-setup error,
not a production regression. The corrected v1511 instruments the
real DRM descriptor/PI2 path and must pass an independent full guest
before receiving scoped acceptance.

## Physically accepted Type-167/236 PI2 error boundary

The corrected v1511 ran a full disposable 256K KCC PDP-6 F07
guest with the source-linked Type-236 DRM request PI2 observer.
The guest completed 36 SIMH read-only snapshots, including 13
fault-on samples 24..36; it was deliberately sample-stopped, not
allowed to falsely HALT with a permanently held DISK owner.
The strict physical v1511 verifier **PASSED** on the finalized
guest console and sampler, with **two** selected real DRM PI2
error-path completions and **25** later checked-release refusals.
The original slot-0 failed-service witness ends at exactly 27,
matching PI2 errors plus refused frees, never treating a physical
read failure as a backing bitmap failure.

Selected process: octal slot `010`, original BACKSTORE run first
`02350`, count `0330`, exact authoritative swap record
`002350000330` at every fault-on snapshot. The bitmap remained
allocated; source-linked MM unpin/rollback preserved nonresident
VM, stable u-area, v1507 retry marker and pending TERM. There
were zero false READY_ONCE publications, repairs, owner-side
fatal close, finish or zombie. DRM controller error accounting
`mfsdev_storage_errors+5` recorded exactly the same two failures.

| Sample | PI6 clock (decimal) | PI2 DRM errors | Checked free refusals | PID 5 SLEEP | PID 011 real restored SLEEP |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 24 | 36238 | 1 | 1 | 58 | 0 |
| 25 | 37753 | 2 | 3 | 162 | 0 |
| 26 | 39278 | 2 | 5 | 239 | 0 |
| 27 | 40795 | 2 | 7 | 305 | 0 |
| 28 | 42313 | 2 | 9 | 371 | 0 |
| 29 | 43832 | 2 | 11 | 437 | 0 |
| 30 | 45351 | 2 | 13 | 484 | 0 |
| 31 | 46869 | 2 | 14 | 518 | 34 |
| 32 | 48388 | 2 | 16 | 584 | 100 |
| 33 | 49906 | 2 | 19 | 674 | 190 |
| 34 | 51427 | 2 | 21 | 749 | 265 |
| 35 | 52944 | 2 | 23 | 815 | 331 |
| 36 | 54466 | 2 | 25 | 881 | 397 |

The healthy slot `011` was genuinely swapped, then restored by
an actual checked ordinary `proc_swap_mres_service_v481` success
before sample 31, and executed **397 real user SLEEP syscalls**
by sample 36. Resident PID 5 also made independent physical
progress to 881 SLEEP entries. The original bad owner remained
intact through the entire 18,228-tick fault-on observation window.
The strict verifier self-test rejected eleven unsafe evidence
variants; the v1511 source-instrumentation self-test rejected five
malformed bridge/DRM sites. The older native source-linked
v1079/v1080 watchdog/queue and v1247 PI-register tests also PASS.

### Evidence fingerprints (SHA256)

Guest: `$TMPDIR/daimos-oom-requester-live-v1075.3YVnE1`.
Runner: `$TMPDIR/daimos-swap-no-partner-v1304.vjhHP1`.

```
addresses          1cb94c0d0d98abdcbafff9355450c726c76f77a5ae02cfc06177e98fdfe86705
simh-sampler.log   2f8189e1fdb9bdc97789c1cb7a870b0ba68a8006397bf02a76e6665a5342a77d
simh.out           771f1422a9250053b4422bcf4fadf51c8ba00171cc3a788d8e7151706c3f73dd
build.log          86b410c00089a0398a4ca6d031607d957faf2382d4beb1a9b1455907aa7577db
kcore.map          761b847e05fbd35f64fa90781dbe483d80d455c6522842688f1f953478a8ba58
```

**Scoped ACCEPTED:** real Type-167/236 runtime descriptor,
real PI2 error publication and accounting, original BACKSTORE
read-failure rollback and independent healthy user restoration.
The test intentionally injects the controller's existing error
branch at a genuine hardware completion, not broken magnetic
media, persistent device disappearance, lost completion/PI6
timeout, write failure, or terminal reclamation. Those remain
separate OPEN gates. Production KCORE is unchanged (no new
resident words, process status or ABI changes).

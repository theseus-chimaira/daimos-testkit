# KCORE physical Type-270 read-error propagation, v1511

Date: 2026-11-12. Production KCORE is unchanged; all observers and
fault injection are confined to a disposable full 256K KCC PDP-6
F07 guest. This is a **controller error-path** injection, not proof
that a real disk has lost magnetic media or all device service.

## Why this additional gate is needed

Physical v1508-v1510 proved permanently refused *checked release*,
original DISK ownership/TERM, native retry bounds, resident PID 5
fairness, and an independently swapped PID 011's checked restore and
execution. A rejected checked free occurs **after** the payload has
been read. It does not exercise the actual Type-270 controller
error status, its request wakeup, or the swap-in read-failure
MM unpin/rollback branch.

v1511 reuses the v1510 full guest, including genuine F07 MM pressure,
original selected bad slot, independent PID 5 SLEEP spinner and
delayed swapped PID 011. The original v1508 injector first selects
a real failed owner after a successful physical transfer and refuses
checked backing release while leaving the bitmap intact. For the
next two **real slot-0 reads of that exact owner**, the v1511
disposable observer arms the request only at `dsk_runtime_slot0`
after draining preceding hardware requests. On Type-270 PI5 IDLE
completion it redirects exactly that request to the existing
`dsk_pi_error`/`dsk_fail_runtime` code path. This returns the
driver's actual negative completion to `backing_region_io` and
`proc_swap_in_read_fail`; the transaction must unpin/free its new
RAM extent and retain authoritative DISK/TERM/backing.

Subsequent reads of the bad owner use original hardware success
followed by the original checked-free refusal. Healthy separate
swapped process reads must remain unaffected. The real DSK error
counter `mfsdev_storage_errors+2` is sampled directly alongside
the number of test-selected PI5 errors. The test also distinguishes
read-error count from checked-free refusal count rather than
mislabeling one as the other.

## Strict acceptance and limitations

The v1511 verifier requires six or more real fault-on samples,
two injected Type-270 PI5 errors reaching actual DSK accounting,
and subsequent checked-free refusals still occurring. For each
sample, total source-linked slot-0 failed-service returns must
equal exactly **driver read errors + checked-free refusals**.
Original selected DISK run, stable u-area, nonresident VM, bitmap
accounting, retry marker and pending TERM must all remain intact.
No fake READY_ONCE, finalizer, zombie or successful reclaim is
allowed. Actual PID 5 progress and independent physical DISK-to-RAM
restore plus user SLEEP progress of slot `011` are also required.

The source-injection self-test rejects four unsafe changes to
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
lost PI5, or a way to free an irrecoverable private executive
owner. These remain explicit future KCORE DEVICE/media gates.

## Status

Four source-injection mutation self-tests PASS; eleven strict
verifier mutation self-tests PASS; generated runner and sampler
preparation PASS. Full physical v1511 acceptance is pending its
independent real PDP-6 sample run.

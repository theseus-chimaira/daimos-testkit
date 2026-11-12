# KCORE: independent swapped process under permanent BACKSTORE failure, v1510

Date: 2026-11-12. The production v1507 KCORE scheduler, checked swap,
MM allocator, PI6 clock and process state remain unchanged. All v1510
changes belong to the disposable full 256K KCC PDP-6 F07 test guest.

## Experimental design

Physical v1509 already proved a real **resident** PID 5 spinner
executing SLEEP syscalls while another process's backing release
remained permanently refused. It did not demonstrate that a distinct
**swapped** user could restore and run while a bad owner stayed held.

Retain the v1509 real PID 5 spinner. In a disposable copy of the
original F07 user, change only the ordinary `C` child with PID
`011` octal. After genuine RUN, BRK and acknowledgement, it sleeps
for `0120000` octal timer ticks instead of blocking on its PIPE,
then enters an independent two-tick real SLEEP loop. All other
children preserve the original PIPE read and parent TERM/WAIT.
This delays the contender's wakeup beyond normal child admission
and expected selected BACKSTORE failure, avoiding a synthetic
process state or early extra load on the 24-slot F07 stress test.

The v1508 injector still selects an actual ordinary slot after
the physical swap payload read, leaving the allocation bitmap
intact while permanently refusing only the original selected run's
checked free. A disposable source-linked observer records:

- A successful `proc_swap_mres_service_v481` restore of slot `011`,
  only *after* the original fault armed and returned checked success.
- A successful ordinary exchange restoring slot `011`, if the
  selected completion used the legitimate exchange path instead.
- Real `proc_sleep_ticks` syscall entries by slot `011` only while
  that original fault remains armed.

The normal v1344/v1508 read-only sampler additionally records the
actual linked process-table slot `011` states at every sample, plus
the original owner record/bitmap accounting/TERM and PI6 clock.
The v1509 PID 5 fairness witness is retained unchanged.

## Strict physical acceptance

The complete v1509 and v1508 real-ownership/fairness validation must
pass. Additionally, physical samples must show the contender
SLEEP/DISK before its own checked restore, at least one genuine
source-linked checked restore or checked exchange of slot `011`
*after* the original permanent refusal, and then ongoing true user
SLEEP syscall execution by that same process while original slot
`010` remains nonresident, TERM-pending and still owns its backing.
The contender must not be the selected bad owner.

The v1510 native injector self-test rejects eight dangerous
source changes. The independent strict physical verifier's
self-test rejects eleven fabricated restore/owner/user-progress
or invalid-process-state cases. No test changes the production
rollback, scheduler, MM allocation or fatal TERM decisions.

Run:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
python3 tests/validation/daimos-backstore-swapped-source-selftest-v1510.py
python3 tests/validation/daimos-backstore-swapped-verify-v1510.py --self-test
sh tests/validation/daimos-backstore-swapped-physical-v1510.sh
```

`V1510_PREPARE_ONLY=1` validates the generated runner and sampler.
The physical test **intentionally stops after diagnostic sampling**;
an unrecoverable owner cannot reach normal F07 HALT, and neither
fake finalization nor artificial repair qualifies as success.

## Status

Test-only v1510 source and verification self-tests PASS. Full
physical swapped-contender execution is **not accepted** until
the strict verifier passes on actual post-fault SIMH samples.

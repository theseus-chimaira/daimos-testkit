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

Test-only v1510 source and verification self-tests PASS. The full
physical swapped-contender run has also PASSED the strict verifier,
as documented below. Production KCORE remains v1507, unchanged.

## Accepted physical switched-owner evidence

The full 256K KCC PDP-6 guest ran original F07 admission, real
MM no-partner allocation pressure and 37 source-mapped, read-only
SIMH snapshots. The selected true permanent-failure owner remained
slot `010` octal, BACKSTORE first `02350`, blocks `0330` octal,
original authoritative DISK record `002350000330`. All thirteen
post-fault snapshots 25..37 kept its stable u-area, exact DISK run,
retry marker, pending TERM and bitmap-backed allocation accounting.
Checked release refusals advanced **1 to 24**, with no repair,
false READY_ONCE/RESIDENT, owner fatal close, finish or zombie.

An independent original F07 child in slot `011` was physically
observed `SLEEP/DISK` at samples 25..31. It passed the original
delayed timer deadline and executed a real checked swap-in commit
between samples 31 and 32, appearing as `SLEEP/RESIDENT` at sample
32. The source-linked committed swap-in counter became **1** and
remained 1; exchange completion counter remained **0**. Its first
genuine post-fault `proc_sleep_ticks` was recorded as count **1**
at sample 32, then **67, 133, 199, 265, 331** at samples 33..37.
This proves actual, continued *user execution after checked restore*,
not merely a runnable descriptor, MM allocation, or scheduler hint.

| Physical sample | PI6 clock (decimal) | Refused frees | Slot 011 restores | Slot 011 real SLEEP | PID 5 real SLEEP |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 25 | 36273 | 1 | 0 | 0 | 42 |
| 26 | 37731 | 3 | 0 | 0 | 108 |
| 27 | 39192 | 5 | 0 | 0 | 174 |
| 28 | 40652 | 7 | 0 | 0 | 240 |
| 29 | 42115 | 9 | 0 | 0 | 306 |
| 30 | 43574 | 11 | 0 | 0 | 372 |
| 31 | 45036 | 13 | 0 | 0 | 438 |
| 32 | 46495 | 14 | 1 | 1 | 440 |
| 33 | 47955 | 16 | 1 | 67 | 506 |
| 34 | 49417 | 18 | 1 | 133 | 572 |
| 35 | 50875 | 20 | 1 | 199 | 638 |
| 36 | 52336 | 22 | 1 | 265 | 704 |
| 37 | 53794 | 24 | 1 | 331 | 770 |

The independent resident PID 5 still executed 728 further real
SLEEP calls over the fault-on interval. The inherited exact-owner,
retry cadence and pending-TERM verifier v1508 PASSed; the v1509
resident-bystander verifier PASSed; v1510's further true checked
swap-in and post-restore user execution verifier PASSed.
Eight malformed source-injection mutants and eleven invalid physical
witness variants were rejected by the native self-tests.

The live v1510 verifier originally rejected the *early boot*
process-table snapshots before PID `011` had been created. This was
a validation parser error, not a kernel failure. Revision `d79991e`
limits the slot-011 requirement to fault-on samples; the strict
original-owner and committed-restore criteria were not weakened.
Both self-tests and the final actual physical snapshots then PASSed.
The v1510 parser now also self-tests genuine pre-admission snapshots.

### Evidence identities

Guest: `$TMPDIR/daimos-oom-requester-live-v1075.2kswMw`.
Runner: `$TMPDIR/daimos-swap-no-partner-v1304.aIcepd`.

```
addresses          01571a8dd8951b11df1b2a66b64b4e83b2fb33a8fdad82d41827505015d9d3ec
simh-sampler.log   174f8d1bf811b93edb53e80d6a00acee0922cd0ee80b3f861936abd03f72efe7
simh.out           c96807be2bd8b69902e23b8b1c933ff5876a020bfc6cb05707ca235628945eb2
build.log          bdf3582a2e8a4df8ab0b3a5bccd238c5776bb312e36e6e653f744844133fa1d1
kcore.map          6ea6c47386dd5d37b8a71205198c3d49284870d40a32096babb35d891c71222e
```

The SIMH diagnostic deliberately stopped after sampling, before
normal guest HALT. Expected standard postflight rc=1 reflects the
intentionally unresolved failed owner, not failure of the scoped
physical v1510 verifier. The original DISK owner cannot be silently
reclaimed, and no false child termination was accepted.

**Accepted scope:** healthy swapped contender restoration and
independent user execution while a distinct true failed DISK owner
remains preserved. Actual permanent hardware DEVICE loss, safe
reconstruction or long-lived owner handling, and mixed filesystem
provider failure gates remain OPEN. There are no production KCORE
source, process-state, ABI or resident RAM changes in v1510.

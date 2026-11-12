# KCORE: physical independent bystander under held BACKSTORE owner, v1509

Date: 2026-11-12. Scope: disposable 256K KCC PDP-6, no production
KCORE/ABI/RAM modification.

## Purpose and source-derived setup

The accepted v1508 permanent checked-release diagnostic preserved one
genuine DISK owner but provided no independently runnable bystander:
INIT terminated the real F07 PID 5 spinner before entering the later
child TERM/WAIT loop where the selected fault was triggered.

The v1509 test changes only the disposable F07 C source: retain the
original `S` child and its real two-tick SLEEP loop through extra-child
TERM/WAIT, moving its original TERM and WAIT (and its output marker)
after that loop. If an extra child cannot restore backing, INIT remains
blocked waiting on it, leaving PID 5 alive as an independent scheduler
contender. No source counters, scheduling priorities, or process records
are synthesized. Four malformed user-source mutations must be rejected.

The preexisting v1150 source-linked `daimos_test_spinner_v1150` witness
increments on an authentic PID 5 SLEEP syscall after the actual
held-provider/gateway conditions have been reached. The inherited
v1508 read-only SIMH sampler is extended to capture this counter
and independent PID 5 state in each actual process-table snapshot.

## Strict acceptance

The inherited strict v1508 validator must PASS intact: exact original
DISK backing identity and accounting, repeated checked refusal,
clock-qualified independent retry intervals, pending TERM, stable
u-area and zero false RESIDENT/READY_ONCE or owner finalization.
Additional v1509 conditions require a live distinct PID 5 in every
fault-on process-table sample, the spinner SLEEP counter to increase
strictly between consecutive fault-on samples, and at least two
additional real SLEEP entries during the capture. Nine synthetic
mutations must be rejected, including frozen/regressing progress,
missing/dead PID 5, false READY_ONCE and lost backing identity.

Run with:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
sh tests/validation/daimos-backstore-bystander-physical-v1509.sh
```

`V1509_PREPARE_ONLY=1` checks the generated runner/sampler without
booting. The sampler stops deliberately after sufficient fault-on
samples; HALT and final resource reclamation are **not** expected.
The separate irrecoverable physical DEVICE/media-error recovery policy
remains open even if actual bystander progress qualifies.

## Status

Source-injection self-test PASS (four rejected mutations), strict
physical-witness verifier self-test PASS (nine rejected mutations),
runner/sampler preparation PASS. Full physical outcome must be
recorded separately; do not treat these prerequisites as a PASS.

## Accepted physical resident-bystander result

The disposable full 256K KCC PDP-6 guest completed 29 read-only SIMH
snapshots and intentionally stopped with its original unrecoverable
DISK owner still allocated (runner postflight rc=1 is expected).
The v1509 strict final verifier **PASSed**, inheriting every v1508
owner/bitmap/timer/TERM invariant, plus six live independent PID 5
process-table checks and real SLEEP-entry progress. The injector left
the physical allocation bitmap intact and refused only the selected
real extent's checked releases. It did not synthesize a scheduler turn.

Selected target slot `010` (octal), backing `02350`/`0330` (octal),
authoritative DISK record `002350000330`. Exact fault-on witnesses:

| Sample | PI6 clock decimal | Refused frees | PID 5 SLEEP count |
| ---: | ---: | ---: | ---: |
| 24 | 37630 | 3 | 98 |
| 25 | 39214 | 5 | 174 |
| 26 | 40794 | 7 | 240 |
| 27 | 42375 | 9 | 306 |
| 28 | 43955 | 11 | 372 |
| 29 | 45534 | 14 | 456 |

All six process-table samples show slot `05` in actual
`SLEEP/RESIDENT` state. Thus an independent process executed
**358 genuine additional SLEEP syscalls after the permanent fault**,
despite 11 additional failed checked frees of slot `010`. Clock
increased by 7904 ticks. The failed owner's original bitmap-backed
DISK record, nonresident VM, u-area and pending TERM stayed intact;
its per-owner retry tag persisted, while repairs, owner-side fatal
close, finish and zombie remained zero. `READY_ONCE` was never
falsely published for the failed owner. Allocator accounting still
includes at least its original run.

The source-order self-test rejects four malformed guest edits; the
strict v1509 verifier rejects nine wrong-process/missing-progress/
ownership mutants. The inherited stricter v1508 verifier separately
rejects thirteen unsafe mutations. These are native validation
self-tests, not synthetic replacements for the physical samples.

### Evidence fingerprints

Guest:
`$TMPDIR/daimos-oom-requester-live-v1075.jY2tjW`.
Test runner:
`$TMPDIR/daimos-swap-no-partner-v1304.v72VGD`.

```
addresses          6d62c489d6852778d4ea544a445328e550f96259247dcbc8caa7740ae9e2622b
simh-sampler.log   9bf554e74aef79f1e27175e1ec2bfd6f4f3fb7d8b510bfdccdf0234ec5ed0096
simh.out           830a2f91cb2452a2734fcb0e9730531e654af1942628e9082d2009400c5916f6
build.log          848318984daec816611743ba75d9d163b00b41a3196bacb319659b477ac1ed72
kcore.map          5e918bb3b6a5aa5fdcc04f66cc938964025ee03f9f8267c1e65de4497f029c7c
```

**Accepted scope:** physical independent **resident** bystander
progress during sustained failed BACKSTORE release. There was no
demonstrated independent *swapped* bystander restore/dispatch in
the fault-on interval. Genuine hardware DEVICE/media failure,
lost-media reconstruction, and terminal reclamation of the failed
private executive owner remain OPEN. No production KCORE source,
process state, ABI or permanent RAM growth in v1509.

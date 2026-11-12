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

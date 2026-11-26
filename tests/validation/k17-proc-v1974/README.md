# v1974 native KA10 and matched PDP-6 process regression

Use unchanged existing user fixtures, compile once per
machine with the same cross-GCC and DAS, build actual
native KCC 64K lowmem D6FS kernel and execute to HALT.

    DAIMOS_REPO=$HOME/git/DAIMOS sh run-v1974.sh ka10 lifecycle WORK PORT

Modes lifecycle, events, scheduler, protection. Repeat
with pdp6. Use separate work directory and local TCP port
for each invocation. Existing headless helper disables
host graphical backends, not any tested storage path.
Scheduler retains the original 8M throttle and actual
marker ordering/private context checks. Both machines
use byte-identical test user DXRs for every mode.

All eight native results PASS:
- lifecycle: exact P marker, RUN, GETPID, WAIT/nohang,
  zombie reap, orphan adoption, explicit FD maps.
- events: E marker, PID/PGRP, STOP/CONT, pending events
  and exact fatal-event WAIT results.
- scheduler: all five native users start before slot1's
  A checkpoint, private stack/data checks, nice ABI and
  disk sleep/wakeup, all five completion markers.
- protection: deliberate out-of-segment logical 077777
  access by PID1 terminates to native HALT; no return
  or failure marker. This does not yet prove faulting
  non-PID1 child cleanup/parent survival.

KA10 original tests exit0. First PDP6 invocation used
graphical default boot and blocked in host video/audio
initialization; stopped and replayed same builds using
existing headless helper. All four replay exit0.
Evidence $TMPDIR/k17-pi2-v1974.HMnc5A/ka-{lifecycle,events,
scheduler,protection} and pdp6 equivalents (console-headless.log).
No production change.

## Child fault cleanup

Additional childfault mode: KA10 read/write beyond APR
limit, native unassigned instruction (same opcode v1964),
then ordinary child; parent observes exact EXITED status
0400001 for faults and 037 for normal child. After each
WAIT, checks parent static/stack canaries and unchanged
process words/slots and file slots. KA10 RWINP then HALT0;
PDP6 RWNP then HALT0 (unassigned not requested). Both exit0.
Evidence ka10-childfault and pdp6-childfault directories.
This strengthens earlier PID1-only protection tests.

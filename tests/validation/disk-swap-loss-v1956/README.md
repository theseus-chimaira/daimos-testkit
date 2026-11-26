# v1956 real Type-270 BACKSTORE fail-stop

Use the accepted v1955 KCC 64K D6FS disk-root build and
v1954 SIMH. No kernel/source changes or memory deposits
after normal boot. Separate private disk copies for each run.

READ: at B (six native children, slot2 DISK, run0..63),
resolve the installed DSK MRES via the live read-call patch
and check actual READ CONO opcode. Break immediately after
CONO at 032053; real slot0 swap-in, request043220,
raw sector177210, destination152000, original slot2 DISK
record64, TRANSITION, exact 8192-word destination pin1.
DETACH DSK0. HALT004510 reason2; active descriptor and
storage_state cleared, completion -1, same DISK record,
64 bitmap bits/counters and exact original MM table.

WRITE: arm actual WRITE CONO breakpoint at A and run
ordinary pressure admission. At 032050, slot0 swap-out
request044332, raw177210, source152000, slot2 RESIDENT
and TRANSITION, exact 8192-word source pin1, reserved
bitmap64, published proc_swap_blocks_used0. DETACH DSK0.
Actual caller slot1 reaches dedicated HALT004510 reason2;
same original resident owner, backing record, bitmap and
MM table, completion -1 and cleared controller request.
Do not require same current slot across the synchronous
slot0 I/O service and caller's fatal gateway.

This is the v1541 specified critical BACKSTORE policy.
The READ and WRITE are actual issued native commands, not
a synthetic failure return. The fault occurs immediately
after CONO, not after an arbitrary number of DCT words;
no claim of recovery after critical loss or exhaustive
partial-sector/queued request recovery. The monitor halts
the real CPU then the harness terminates the simulator.

First WRITE attempt reached correct HALT but its verifier
incorrectly required current slot0 at HALT; the corrected
full replay passes. First READ test checked disk ownership
and destination pin before fault, then strengthened replay
also checks the entire MM table at HALT.

Evidence: $TMPDIR/k09-disk-swap-v1955.MbLEZM/
read-loss-final-v1956 and write-loss-final-v1956, console.clean.
Run with installed v1954 SIMH and accepted v1955 source build:
    V1956_OPERATION=read sh tests/validation/disk-swap-loss-v1956/run-v1956.sh BUILD WORK
    V1956_OPERATION=write sh tests/validation/disk-swap-loss-v1956/run-v1956.sh BUILD WORK

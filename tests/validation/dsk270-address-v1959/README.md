# v1959 Type-270 address acceptance and bounded runtime recovery

Production DAIMOS 06eff089; unchanged SIMH cec5436.
H-270 pp.2-11, 3-10/11 and Fig.3-1: IDS/ADT accept DATAO;
ADT/DFR alternate while awaiting a command. An ADT status
sample alone does not prove subsequent address acceptance.
Wait for SNA after DATAO in ADT; retry on DFR within the
shared 300-tick countdown. Do not arm DCT or publish an
active request before acceptance. The runtime watchdog
atomically rechecks ownership, requests END/CLR and disables
DCT before failing the descriptor. Dispatch drains older
requests, including synchronous admission failures.
DSK MRES 234 -> 264 words, BSS unchanged; fixed KCORE unchanged.

Run: DAIMOS_REPO=$HOME/git/DAIMOS sh run-v1959.sh WORK

Source-linked queue-v1958.py uses actual PDP-6 instructions,
APR clock and Type-270/DCT, with test wakeup stubs. Queue
case refuses two older descriptors and slot0's own request
after lost WRITE, 900 ticks total, three wakes, unchanged
IOWD. READ-loss and masked-PI5 cases fail first request,
then complete three peer sectors, verifying all 384 words
with different unit/sector values; masked PI5 expires at
300 ticks. No fake controller reset or guest status deposit.
Forced-race variant waits for actual DFR once before DATAO,
requires debug trace of rejected DFR then accepted ADT
DATAO, and passes. Unsafe variant removes confirmation
and must produce actual wrong-medium data 020 vs 040,
not merely fail a host assertion. Original and replacement
disk hashes unchanged. Test-only variants not shipped.

Evidence $TMPDIR/k09-address-v1959.1opCid:
sector-{queue,read,silent}, race-confirm, race-unsafe-witness,
root-matrix (six FULL configurations), boot-irq-r2 and
boot-silent-r2 (both actual KINIT faults; silent uses v1953
SIMH missing-event model), elevator.log. Initial boot harness
opcode matcher also matched watchdog END/CLR; corrected
to scope to PI5 leaf. Both reruns PASS. Full 64K normal
and partial READ/WRITE tests in physical, partial-read,
partial-write on fresh committed-source lowmem build.
See ../dsk270-runtime-v1958/README.md for physical tests.

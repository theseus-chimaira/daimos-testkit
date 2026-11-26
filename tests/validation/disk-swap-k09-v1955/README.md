# v1955 physical 64K DISK swap and WAIT

KCC lowmem disk root, actual Type-270, installed v1954 SIMH.
PID1 enables swap using STORAGECTL. Six non-PURE children grow
to 8192-word APRs, write PID-specific canaries at 02500 and
017000, and block on a real coordination pipe. All six RUNs
succeed. At B, slot2 has DISK mode, base0, original u-area
and BACKSTORE run 0..63; exactly those 64 bitmap bits are set.
No packed owners. All six children check both canaries and
their release word, EXIT(0), and PID1 checks exact WAIT PID,
kind and status. Parent closes both coordination pipe FDs.
A/B/C MM9/20/8, free43663/1119/43677, swap blocks0/64/0.
Disk read counts50/129/193, writes1/65/65, errors0 throughout.
Exact parent APR/u-area and non-cache/non-pipe owner identities
preserved, baseline idle-stack pin only, no reservation or
active storage request. No kernel changes or injected states.
Harness terminates sleeping PID1 after successful marker; not
a normal HALT. Initial run retained PID1 pipe, rejected by
final oracle; corrected fixture closes FDs and passes.

Evidence $TMPDIR/k09-disk-swap-v1955.MbLEZM/source-final,
physical-final/console.clean and report.json. KCORE SHA256
848a14b5bc2f7433430194c9da61b0e3bfc7facf6073f9eba0b678ee8e420849.
SWAP MRES SHA256
5ff2c96a14811c8deab58dfa999e5903289e235501b9965833c5ba27e19a03fb.
Trace SHA256
5674fd66397ea1d623105435425a807a5ac0ebe39537e2acacb38fd148e7c6e5.

Run: DAIMOS_REPO=$HOME/git/DAIMOS make test-disk-swap-k09-v1955

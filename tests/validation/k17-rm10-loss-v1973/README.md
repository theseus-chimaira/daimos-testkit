# v1973 full-kernel native KA10 RM10 critical-loss qualification

Use v1972 D6FS/RM10 six-child 64K build with DCS installed.
No production modifications or fake controller status.
The host locates the actual linked and relocated RC10
DATAO instruction (not a hardcoded monitor PC) and stops
at the next native instruction during the first actual
swap WRITE (after A) or READ (after B). Selected unit0
detached, no replacement attached, then genuine clock
watchdog expires at exactly 300 ticks. Dedicated BACKSTORE
reason2 HALT. Read/write request failure, active descriptor
cleared, error counter incremented once. Exact original
resident source or pinned restore destination, transition,
swap record, counters, 64 backing bitmap bits, all MM
extents and inactive DF10 pair preserved. Medium hash
unchanged after removal. Representative command-issue
fault, not arbitrary mid-sector loss or continued critical
backing operation. No active TCP reader in these tests.

    V1973_OPERATION=read V1973_DCS_PORT=34830 sh run-v1973.sh BUILD WORK
    V1973_OPERATION=write V1973_DCS_PORT=34831 sh run-v1973.sh BUILD WORK

Both clean native runs exit0. Evidence:
$TMPDIR/k17-tape-v1973.fel8Sn/loss-read-r2 and loss-write-final.
Initial read trial stopped on host TCP port collision.
Initial write verifier passed but shell wrapper had a stray
PY after execution; removed and full clean replay passed.
Original v1972 build $TMPDIR/k17-dcs-v1972.3KPvNN/ka-swap.

# Type-270 octoflop contract v1950

Source: DEC Discfile Control 270, H-270, April 1966, pp. 2-11,
3-7/8, 3-11, 3-26, Fig. 3-1. DATAO is accepted in IDS/ADT only.
A new address in ADT interrupts the previous seek. DFR requires
RDY from the discfile; an address error sets ADE and FER in ADT.
CLR implies END; it is not an unconditional reset to IDS.
Nonbusy CONO reloads the command buffer.

Each test runs a separate native PDP-6 program on one attached
DSK0 and absent DSK1. No guest OS, synthetic status or monitor
deposit into controller state. The monitor deposits only the
linked test instructions and initial pushdown pointer. The RIM
converter's automatic GO is stripped before loading.

- clear_test: absent drive reports ADT/ADE/FER, no DFR; CLEAR
  does not invent IDS; new DATAO and CONO recover attached DSK0.
- reselect_test: interrupt an in-flight ADT seek with a new
  unit/address, observe the absent-unit error, recover DSK0.
- dfr_test: reject DATAO during DFR, return to ADT with NOP,
  then accept new DATAO and recover.

All three fail on original fe97912 and rejected v1949 227f563;
all three pass on corrected v1950 source. The latter is
cb6a255; first test binary reports the parent with local changes.
The earlier v1949 CLEAR-to-IDS assumption and DFR reselection
test were invalid; withdraw their acceptance.

Evidence relative to TMPDIR:
- k09-dsk-trace-v1949.cRHfKI/dsk.debug: original real driver I/O;
  false DFR 040103, then stale event/command bits on reselection.
- k09-sims-v1950.zk3e6w/probe-original, probe-speculative,
  probe-fixed: independent HALT/AC1/AC2 observations.
- k09-root-v1950.qEXzJF: all six actual v1948 KCC FULL root cases
  PASS, including AUTO TSFS with DSK AUXSTORE (512 blocks).
  No kernel image changes. Boot selection only, not active swap.

Run:
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    make test-dsk270-octoflop-v1950

# Type-270 command loss and bounded KINIT wait, v1954

DEC H-270 (Apr 1966), Fig.3-1 and pp.3-11/13, 3-25/26:
OPERABLE loss sets FER; DFR, ALS, CMS and SCE have internal
delays. READ can generate ESP1 from END without completing a
sector. WRITE/compare cannot generate the missing sector clocks
from END alone. The simulator must not invent IDS or transfer
stale data to a replacement disk.

The selected medium-loss latch persists until a new legal
DATAO. Internal delays continue; no lost CMS/SCS operation
accesses the host file or data channel, and SCE cannot commit
a lost write. READ END schedules internal ESP1/ESP2 as needed;
DFR with no command returns to ADT. Busy WRITE after loss is
not automatically recoverable: no claim of reset or write
completion without sector clocks.

Native test: original linked code stops at observed DFR or SCS,
operator DETACH DSK0, optionally attach a distinct file with a
different first sector. No status or guest data deposits after
the original code load. DFR, READ, READ with replacement, WRITE
with replacement fail on v1953 and pass on v1954; both files
unchanged. The WRITE case verifies retained SCS rather than
successful termination; it is not a complete active-write DCT
data-path test.

Physical KCC FULL: actual READ CONO270,1105 at 033650,
DETACH at 033651. The corrected simulator reaches real PI5
error handler with CONI001105020003 and KINIT fails closed.
Original KCC image passes with the v1954 simulator alone.

Independent KINIT bound: DSK MRES reuses storage_count,
300 ticks at 60Hz, waits for IDS/ADT before DATAO; timeout
claims outstanding request under global PI disable and checks
whether completion already won. END/CLR/SCL and DCT disable
before releasing owner. Clock required (normal native KINIT).
No new data words or fixed KCORE growth. DSK MRES 211 -> 234
installed words. Normal runtime watchdog unchanged.

The physical silent-controller regression deliberately uses
the old v1953 simulator, where the issued READ produced no
interrupt after detach. Actual countdown -300 -> 0 and
wall clock 013 -> 0467; timeout instruction034146, still -3
storage_state. Corrected KINIT halts rather than hangs.
The v1954 interrupt case also halts on the new KINIT.
All six current FULL root-selection cases and native elevator
regression pass. No active disk-swap recovery acceptance.

Evidence: $TMPDIR/k09-read-loss-v1954.M1T1TL.
SIMH cec5436; clean executable SHA256
6cab775ae1f9291853ac26a489d7d18714226be32b47e93911ec6c81a9964e66.
DAIMOS b98f64d7, KCC FULL build boot-bounded.
Native: original-native, candidate-native, committed-native.
Normal boot: root-regression (old KCORE/KINIT), bounded-root-matrix
(new driver). Actual fault: candidate-boot, bounded-silent-2,
bounded-irq-2; final ownership checks in bounded-silent-final
and bounded-irq-final. First bounded-silent/irq attempts rejected
the two identical abort CONO opcodes before execution; the
corrected source-map-aware harness distinguishes the PI5 leaf.

Run native:
    make test-dsk270-read-loss-v1954
Run physical:
    python3 tests/validation/dsk270-read-loss-v1954/boot-loss-v1954.py BUILD WORK PREFIX SIMULATOR
For the independent silent-controller check add --silent-controller
and use the saved v1953 simulator.

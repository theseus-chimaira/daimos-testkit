# K07/K08 integrated recovery acceptance v1947

2026-11-26: completed the original v1946 physical replay with the
normal 1150-second deadline. Actual wall time 284.728 seconds,
including original source proof, hardware search timeout, independent
process progress, foreign refusal, exact-source recovery and cleanup.
Unmodified v1939 production GCC KCORE/KINIT/PURE images; the accepted
v1945 guest and v1944 physically seeded CLEAN DTVOL2 COMP source.
No monitor deposits or kernel hooks.

All addresses and cursor words below are octal; clocks and MM counts
are decimal.

| Checkpoint | Clock | MM | Physical evidence |
| --- | ---: | ---: | --- |
| B/A | 5709 | 18 | five children admitted, sixth RUN refusal, no-growth BRK |
| FULL | 6351 | 18 | PC040756, slot0/cursor3, both original pins |
| MIDFULL | 6351 | 18 | PI6 entry017712, saved TAPE PC032060 |
| MISSING | 13551 | 17 | actual FULL return034453/-4; source retained |
| POSTFAIL | 13551 | 17 | actual PI6 saved executive PC020277 |
| PEER | 13850 | 17 | slot4 executes data sentinel w while DTC3 absent |
| FOREIGN_0 | 13853 | 15 | actual PREFIX return034446/-4, 302 ticks after missing refusal |
| READY_0 | 13853 | 15 | cursor3, 64-tick cooldown |
| READY_1 | 14282 | 15 | healthy slot5 READY_ONCE cursor01005 |
| READY_2 | 15996 | 13 | slot3 READY_ONCE cursor01003, AC1=01003 |
| DISPATCH | 15996 | 13 | AC1=3, cursor3, same MM descriptors |
| Z | 16450 | 8 | all five exact EXIT/WAITs, parent data intact, unmount |

Source113600..120000 and target122000..130000, original slot3
u-area051274, backing037141000000, FULL escrow040457122000.
Both pins1 during real PI6, complete 2176-word RAW suffix unchanged
at every observed failure boundary. Original backing and both volume
ID halves retained on failure, escrow0, source pin0 and target absent.
Actual return after 7200-tick tape search timeout. Fresh distinct-ID
foreign reel refuses at a different call return after the genuine
64-tick cooldown; this supersedes the invalid v1945 repeated-PC
witness. Original reel restoration publishes sole unpinned PROCESS
122000..130000, backing/escrow0, storage mode RESIDENT and original
u-area, then scheduler consumes READY_ONCE. Actual normal HALT PC0,
simulator exit0. Both reel hashes unchanged.

The independent v1946 full oracle and ten altered-trace controls pass.
The v1947 supplementary oracle requires final high slot2, mode word0,
unchanged parent backing/u-area/APR capacity, only the parent PROCESS
owner, MM8 and healthy retired medium0100003. Four additional altered
traces reject: repeated foreign stop, stale packed mode, unhealthy
retired medium, lost parent backing. These 14 tests mutate observed
traces, not 14 additional guest faults. Earlier native v1650/v1808/
v1677 executed source mutations remain separate evidence. PI6 is
observed inside FULL and after rollback, not inside a PI-disabled
critical section. Other root/controller matrices and KCC physical
production acceptance remain K09; KA10 remains K17.

Evidence:
$TMPDIR/pure-k08-pi6-physical-v1946.csaBIz/physical.clean
SHA256 5734e7d488a5cf1f2fbd3c033d440184365685947bd8f378bf54a56f1340d9ed
Build $TMPDIR/pure-k07-loss-v1945.OLgxdN/build.
Original full provider build $TMPDIR/pure-brk-pressure-v1614.Fx9gcX/build.

KCORE 4177db78eabee2b54a1cb3d6e2cec3eee6e4b0b2d9e330a22f3d6acf052c85e1
KINIT 0dd50179f40bfef8880e93071e50293230e85ed7b262e3b7fdb74d9958003843
PURE e488f1a93315ff7039326c948d1e9b39632507850c999fffa1285f975c6b0c41
Original reel 44e616a50abae9914359552e9cf55152f6250c9ae50dc526d96091d8e260593e
Foreign reel 8bfac4a7d367357affd98e42040395b09988394374522620aa929250358b4f88

Reproduce (same accepted guest, original provider maps):
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1946_BUILD="$TMPDIR/pure-k07-loss-v1945.OLgxdN/build"
    export V1946_PROVIDER_BUILD="$TMPDIR/pure-brk-pressure-v1614.Fx9gcX/build"
    make test-pure-k08-recovery-v1947

Actual v1947 acceptance executed the existing make test-pure-k08-pi6-v1946
target followed by verify-v1947.py --mutants on the same completed trace.
The new combined target invokes those same steps; no second full run
is claimed.

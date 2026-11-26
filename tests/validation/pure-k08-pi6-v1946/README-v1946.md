# K08 v1946: actual PI6, independent peer and READY_ONCE dispatch

First scoped K08 acceptance candidate. Reuse the uninstrumented
current-production v1945 physical 48K guest and sealed DTVOL2 inputs.
No deposits, artificial IRQ, new kernel code, or test-only scheduler
hooks. The optional read-only observer extends the v1945 controller;
its original invocation and acceptance oracle remain available.

The observer requires the original PI6 handler to interrupt slot-0
FULL with the exact source and target pins, saved executive PC in the
installed loader/provider/driver path or other reserved executive code, no intervening user selection and unchanged MM.
After real DTC3 removal and the original bounded FULL refusal, require
an actual PI6 entry with the exact retained RAW suffix, and keep the
medium absent until a distinct healthy child executes its original
user-data check and emits w. Then verify refusal of the foreign reel,
reattach the original, and observe the physical idle-loop service
return publishing READY_ONCE for slot3. The next original scheduler
restore-selected entry must choose that same resident process. End
with the original five exact WAITs, media conservation and HALT 0.

Run with an already accepted v1945 build (see its README):

    export V1946_BUILD=<v1945 build>
    export V1946_PROVIDER_BUILD=<identical original v1940 source build>
    make test-pure-k08-pi6-v1946

Independent offline verifier and negative trace controls:

    python3 tests/validation/pure-k08-pi6-v1946/verify-v1946.py BUILD WORK PREFIX
    python3 tests/validation/pure-k08-pi6-v1946/test-trace-v1946.py BUILD WORK PREFIX

A partial or failed guest trace is not acceptance. The original
historical v1650 PI6 slot-0 guard native suite has been rerun on
current source; all three unsafe assembly variants reject. The old
v1808/v1658/v1677 fixture calls use the existing ABI-aware v1902
helper. The v1658/v1677 assertions are reconciled with the actual
v1916 typed hard-refusal contract and v1922/v1924 arena/provider
admission; these are fixture changes, not production changes.

Initial physical replay was rejected: Iaaa!rwwww, then HALT. The
parent failed its admission/sleep witness before B. The trace is
$TMPDIR/pure-k08-pi6-physical-v1946.gNkULc/physical.clean. It is not
an observed scheduler failure during FULL and its cause is not yet
proved. The second replay has an early !r/!u diagnostic stop.

Current-source native v1650 PASS with all three negative assembly
variants; v1808 PREFIX/FULL lost-success replies PASS, old reply-only
gate rejected at 02004; v1677 two-owner fault/independent READY_ONCE
PASS, unsafe quarantine release rejected at 02202. v1658/v1677 stale
fixtures initially failed due to old service signature, old typed
refusal expectation, original provider identity and a 32K core
declaration with a second owner above 32K. Corrected test fixtures,
not kernel changes. Evidence:
$TMPDIR/daimos-pure-slot0-v1650.K7rnzQ,
$TMPDIR/daimos-pure-restore-reply-v1808.naOkqN,
$TMPDIR/daimos-pure-pi6-fault-v1677.4UDgfb.

Second and third physical runs reached real FULL and real PCLK PI6
with slot0/cursor3, MM18 unchanged, both pins and all 2176 RAW words
unchanged. The controller incorrectly restricted the actual saved
executive PC to PURE and then PURE+DTFS/KCORE, so these are partial
captures, not complete physical passes. Saved words 340000032060
and 340000032057; third installed PURE base033136 and DTFS base041422.
Evidence $TMPDIR/pure-k08-pi6-physical-v1946.bVHBjW and
$TMPDIR/pure-k08-pi6-physical-v1946.ONFM9H. The next short run
was cancelled before acceptance to fix call-opcode binding in the
monitor (device syscall/watchdog PUSHJ, PI/DCT JRST). New observer
binds TAPE and DTFS/TSFS using actual installed service targets,
original link maps, and identical KINIT packaging, checks the saved
executive PC is outside idle and before a real service return,
and checks the actual original MM ownership. No synthetic interrupt.

Critical v1945 oracle correction: an isolated SIMH program executes
AOS at PC001001. Initial AC1=1, cleared/rearmed same PC AC1=1,
normal CONT to next hit AC1=2. The v1945 MISSING/FOREIGN_0 shared
the same PC and clock, so the claimed foreign retry is withdrawn.
Actual clock progress through the 0100-tick cooldown is mandatory
in both live replay and offline verifier; the old trace fails this
new acceptance gate. The source-loss and same-medium recovery
subresults remain valid. Probe:
`test-simh-rearm-v1946.sh`, actual evidence
$TMPDIR/k08-simh-break-rearm-v1946.W5XGc4.

Fifth replay, independently verified through FOREIGN_0:
$TMPDIR/pure-k08-pi6-physical-v1946.WzALO9/physical.clean
SHA256 a551449cd2e570c1d24bb18e16804de7fb14466002b4cfdb5fd906da2abd375f.
Actual PCLK PI6 at 017712 saved TAPE PC032067, slot0/cursor3,
MM18 identical, both pins and all 2176 suffix words identical.
FULL/PI6 tick6329; detach during tape search gives actual 7200-tick
timeout, MISSING FULL return034453/-4 at tick13529, MM17.
POSTFAIL actual PI6 tick13529, independent slot4 user sentinel w
tick13825 while DTC3 absent. Fresh foreign reel PREFIX return034446/-4
tick13828, MM15, 299 ticks after missing refusal, source and original
identity intact. This is a genuine later foreign-source refusal.
The original reel was reattached; READY_0 cursor3 and READY_1
cursor01005 (other process) were sampled, but the 260-second
diagnostic deadline expired before READY_2 and final Z/HALT.
No full K08 acceptance or complete same-run foreign/recovery
acceptance is claimed. Default run deadline remains 1150 seconds.
No simulator left running. Use verify-scoped-v1946.py for the
completed checkpoints; the full verifier still requires all stages.

    python3 tests/validation/pure-k08-pi6-v1946/verify-scoped-v1946.py BUILD WORK PREFIX


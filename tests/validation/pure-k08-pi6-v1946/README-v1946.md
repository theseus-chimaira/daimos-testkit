# K08 v1946: actual PI6, independent peer and READY_ONCE dispatch

First scoped K08 acceptance candidate. Reuse the uninstrumented
current-production v1945 physical 48K guest and sealed DTVOL2 inputs.
No deposits, artificial IRQ, new kernel code, or test-only scheduler
hooks. The optional read-only observer extends the v1945 controller;
its original invocation and acceptance oracle remain available.

The observer requires the original PI6 handler to interrupt slot-0
FULL with the exact source and target pins, saved executive PC in the
installed PURE code, no intervening user selection and unchanged MM.
After real DTC3 removal and the original bounded FULL refusal, require
an actual PI6 entry with the exact retained RAW suffix, and keep the
medium absent until a distinct healthy child executes its original
user-data check and emits w. Then verify refusal of the foreign reel,
reattach the original, and observe the physical idle-loop service
return publishing READY_ONCE for slot3. The next original scheduler
restore-selected entry must choose that same resident process. End
with the original five exact WAITs, media conservation and HALT 0.

Run with an already accepted v1945 build (see its README):

    V1946_BUILD=<v1945 build> make test-pure-k08-pi6-v1946

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

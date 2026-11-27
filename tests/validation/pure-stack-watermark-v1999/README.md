# v1999 written-stack watermark and preliminary PI measurement

Old scanner fails native sparse stack case on PDP6 and KA10.
Reverse scanner reports deepest changed word, empty zero.
Private205 usable words; idle255 in 256-word reservation.
Both CPUs pass sparse, empty, monotonic and boundary cases.
Historical v1239 bounds and two overread mutants, v1243 backing
and BRK guards pass. Default OFF process object byte-identical.
Same-tree assembly and C generator flag 0/1/0 PASS; invalid mode
rejected. Fresh outer build used, not a full outer toggle test.

Run native and mode checks:
    sh run-native-v1999.sh
    sh test-mode-v1999.sh

Use the v1997 direct runner with a fresh 48K GCC strict directory
image built with PROC_STACK_WATERMARK=1; set V1997_DIRECT=1 and
V1997_DIRECT_OBSERVER to the absolute path of observe-v1999.py.
Evidence TMPDIR/pure-k15-stack-v1999.0Aqson/48 and
pure-directory-dsh-v1997-directory-marked.03d9x6.
Initial/held/restored/HALT private113/113/113/113,
idle10/10/110/110; independent physical canary checks PASS.
Real bitmap242/raw3200, FULL16384, identity, variable, typed WAITs,
HALT, independent lifecycle replay and image/tape hashes PASS.
Diagnostic image +39 TEXT/image words and +2 BSS, MRES length same.
Written watermark is not every transient AC17 reservation, nor
a worst-case bound. No stack shrink.

Separate run on original v1996 image, diagnostics OFF, no MM
write watches: set V1997_DIRECT_OBSERVER to observe-pi-v1999.py.
Actual source-bound DROP object, four exact execution boundaries.
Global PI 1/0/0/1, saved CONI0276 unchanged, RT owner0 at each.
SIMH SHOW TIME inner369029, outer369318 simulation units.
Independent verify-pi-v1999.py EVIDENCE rejects four corruptions.
Lifecycle and root/executable hashes PASS.
Evidence TMPDIR/pure-directory-dsh-v1997-directory-marked.YmcKqa.
Not hardware time or a proven RT deadline violation; FULL and
RT-active timing and worst-case stack depth remain open.

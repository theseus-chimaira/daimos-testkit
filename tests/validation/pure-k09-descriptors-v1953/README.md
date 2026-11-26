# v1953 physical MM descriptor exhaustion

KCC GENERAL, 48K, native TSFS without AUXSTORE, v1950 SIMH.
Four ordinary child processes create three independent pipes each
and block on an inherited coordination pipe. PID1 closes its
unneeded read FD, allocates more pipes until refusal, closes one
and recreates it, checks refusal again, frees its extra pipes,
releases the children, verifies exact WAIT PID/EXITED/status zero,
and closes the coordination pipe. Original user process code and
MM ownership are inspected at four CTY barriers; no deposits,
kernel test hooks or synthetic full table.

Observed A/B/C/D descriptors 9/32/32/7 of capacity32.
Free words24247/14904/14904/24390; largest B/C14789.
Four extra parent pipes succeeded; next refused despite available
FD pair capacity and abundant contiguous memory. All four children
remain resident and sleeping in B/C; process ownership unchanged.
After reaping, no pipe or child owner remains; baseline owners
match exactly except the closed 14-word pipe and reclaimed
129-word block cache. One baseline idle-stack pin throughout.
This test is separate from nine-child RAW restoration.

Evidence: $TMPDIR/k09-descriptors-v1953.XFiqba.
Actual test and strengthened final-ownership verification PASS.
The guest deliberately sleeps after its completion marker and
the test harness terminates SIMH; this is not a normal HALT test.

Run: DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-k09-descriptors-v1953
The wrapper selects the same original v1673 runner parameters.

# v1942: physical 48K PURE pressure and FULL acceptance

PASS on unchanged production v1939 kernel images (GCC 48K TSFS).
The adapted five-child v1941 guest executes on original PDP-6 SIMH,
with the actual physical Type-551 tape path and real PCLK. No kernel,
scheduler, MM or physical I/O behavior has been patched. The replay
controller uses explicit nobreak all. A tiny monitor smoke passed
both explicit and bare forms on this simulator; the historical
breakpoint issue was not reproduced in isolation.

    export PDP10_PREFIX=$HOME/cross TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1941_BUILD=$TMPDIR/pure-k07-five-v1941.3uWwvd/build
    make test-pure-k07-full-v1941
    python3 tests/validation/pure-k07-full-v1941/test-trace-v1942.py \
        "$V1941_BUILD" "$TMPDIR/pure-k07-full-v1941.zvs3Om" "$PDP10_PREFIX"

The replay and verifier both passed, exit 0. First exploratory run
was interrupted during boot to change the monitor command; only the
complete second run is accepted. Original six-child workload remains
refused at sixth RUN, as reported in v1941. Five-child fixture demands
that refusal and checks parent survival, no-growth BRK, each child's
original data sentinels and exact PID/EXITED/status WAIT.

Actual B/A snapshots: current slot1, MM18, unchanged extent table,
zero reservation head. Slot1 resident 130000..140000; slots2..6
PACKED 121000..130000, 111000..120000, 101000..110000,
071000..100000, 061000..070000 respectively (octal). Each child
retains 07000 words instead of 010000, saving 01000 words (512
decimal) per child, aggregate 05000 (2560 decimal) mapped-owner
words. This is not additional v1942 optimization or a measurement
of total peak/net RAM. There are four intervening 01000 alignment
gaps, not five; slot2 and parent are adjacent.

Both installed service JRSTs resolve PURE base 033136. Verified
actual bounded FULL opcode 200000000004 at 040756 and native
breakpoint at that PC. Current slot0; child3 original PACKED
111000..120000 and separate PROCESS 120000..130000 each pin1.
AC1 backing 021400000012, AC2 destination 120000, AC3 stable
u-area 051274, AC4 capacity 010000. Original PACKED identity
matches A; MM18, no overlap. First plain child already emitted w
before the FULL breakpoint. Four remaining w markers and Z prove
all five exact WAIT checks and data sentinels. Z: slot1, MM8, no
child VM/u-area leak, empty reservation list. PCLK B/A11492,
FULL16982, Z21881 (decimal), delta10389. Exactly one normal HALT
PC000000, simulator exits successfully.

Seven synthetic verifier geometry negatives passed. Nine further
negative controls on the actual accepted transcript reject source
and target unpin, foreign target/u-area, reservation and child
owner leaks, wrong entry, missing child marker and wrong HALT.
Those are transcript verifier tests, not nine executed guest faults.

The current plain/compressed guest pair was independently
recompressed byte-identically; three private tape members matched
the verified fixture, tsfscheck PASS (54 files,315 extents).

Evidence: $TMPDIR/pure-k07-full-v1941.zvs3Om/physical.clean.
Accepted trace SHA256:
e31bf43619c8bb91b42694739a2ca89930a964c042ee0a21dea11870240d2e0d
KCORE SHA256:
4177db78eabee2b54a1cb3d6e2cec3eee6e4b0b2d9e330a22f3d6acf052c85e1
PURE SHA256:
e488f1a93315ff7039326c948d1e9b39632507850c999fffa1285f975c6b0c41
KINIT words SHA256:
0dd50179f40bfef8880e93071e50293230e85ed7b262e3b7fdb74d9958003843

No kernel RAM growth. All simulator processes terminated. K07
physical pressure/FULL/WAIT baseline passes. Concurrent live
reservation/retirement under real PI6 and integrated source-loss
recovery remain OPEN. RAW PURE and mode3 default policy unchanged.

# P1-E v1637: physical 48K seventh-RUN pressure and six PACKED restores

Base: accepted v1636 minimal production BCACHE placement correction.
BCACHE's unchanged 0201-word clean slab uses MM_ALLOC_LOW instead of
HIGH, allowing parent APR `130000..140000` octal and six complete
child APRs below it in physical 48K PDP-6 core.

The v1637 testkit source generator derives a distinct C89 guest
from the original v1614 PIPE/WAIT fixture. It admits six children,
waits until all six are PROC_SLEEP, then attempts a seventh RUN.
This seventh RUN must fail with -1 under honest resource pressure;
the parent must survive, perform the no-growth BRK 010000->010000,
close its write PIPE, and reap all six original children. Original
child PIPE reads, two private mutable sentinels, EXIT status 057,
six exact parent PID/EXITED/status-057 WAITs, and parent sentinels
are retained. The `x` marks the expected seventh RUN refusal and
`L` means lifecycle-only, NOT whole-system RAM savings.

Build and run the real original PDP-6 TSFS/no-AUX guest:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-cache-pressure-v1637/run-v1637.sh

The actual original source-built physical guest prints a continuous
console line:

    aaaaaax[B013470/042501]<010000+010000>
    [A013470/042501]{013470-013470}LwwwwwwZ

It ends in normal simulator HALT. The same freshly compiled guest
and tape images were replayed, unchanged, with source-linked MM
snapshots at parent B, A and final Z:

    PURE_CACHE_PRESSURE_BUILD_V1637=/path/to/guest/build \
        sh tests/diagnostics/pure-cache-pressure-v1637/replay-v1637.sh

The real original B and A snapshots contain six unpinned PACKED
owners, each retaining a 007000-word writable suffix:

| Owner | Exact physical interval (octal) |
|---|---|
| 7 | 051000..060000 |
| 6 | 061000..070000 |
| 5 | 071000..100000 |
| 4 | 101000..110000 |
| 3 | 111000..120000 |
| 2 | 121000..130000 |

The parent remains at `130000..140000`. The MM owner set is
unchanged between B and A. All six child processes subsequently
restore and execute the original PIPE/sentinel and EXIT path.
The parent's `Z` follows all six exact WAIT status checks.
At the actual final Z snapshot there are no remaining child
PROCESS/PACKED owners, no stranded pins and the same parent APR.
The clean BCACHE slab is low when present, and is legitimately
reclaimed during the six-PACKED pressure interval.

Verify real source, linked physical MM and two corrupted witnesses:

    PURE_CACHE_PRESSURE_BUILD_V1637=/path/to/guest/build \
    PURE_CACHE_PRESSURE_TRACE_V1637=/path/to/replay/trace.clean \
    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-cache-pressure-v1637/run-audit-v1637.sh

The physical auditor PASSes and rejects a forged foreign PACKED
owner and a false final parent WAIT success. This proves six real
PACKED-to-user-execution-to-EXIT/WAIT recovery sequences after a
resource denial, NOT six individually identified fast/FULL code
paths, immutable-source loss recovery or a transient physical
peak/net RAM advantage. Those remain separate P1-E gates.

PURE remains disabled by default. Strict 32K whole-KCORE size
optimization stays on HOLD pending complete feature acceptance.

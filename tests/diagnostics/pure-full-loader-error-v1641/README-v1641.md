# P1-E v1641: one-shot TEST loader-return error, physical MM rollback

Status: physical simulator test ACCEPTED 2026-11-17. No
production code change; explicit TEST-only return injection.

The original 48K PDP-6 no-AUX TSFS v1638 compressed PURE guest
and MRES are replayed unchanged. The simulator briefly stops
at the ACTUAL return from the bounded v1391 FULL callback.
At this point the real loader has already read and reconstructed
the compressed image into a separately owned/pinned full APR.

The testkit observes returned AC1=0 and the physical MM table,
then injects ONE -1 in the simulator's AC1 register before the
original `proc_pure_ram_restore_v1391` caller consumes it.
This is an explicit failure-injection regression for the loader
error transaction, not a device-level or VFS read failure.
The original MM and executable bytes are never changed.

    PURE_FULL_LOADER_BUILD_V1641=/path/to/v1638/guest/build \
        sh tests/diagnostics/pure-full-loader-error-v1641/replay-v1641.sh

The replay checks the source-linked original MRES PUSHJ to the
loader at offset 002332, first instruction after that call at
offset 002333, and v1391->service return at offset 000433.
It snapshots simultaneously pinned PACKED and PROCESS owners
BEFORE the injected callback failure, again after the original
rollback (source unpinned, temporary full target freed), then
observes an unmodified successful callback on a later retry.
The guest must still complete all six exact original PIPE/data/
EXIT-057/WAIT checks and end in normal HALT. No new production
KCORE/MM/MRES code is built or installed.

    PURE_FULL_LOADER_BUILD_V1641=/path/to/v1638/guest/build \
    PURE_FULL_LOADER_TRACE_V1641=/path/to/replay/trace.clean \
        sh tests/diagnostics/pure-full-loader-error-v1641/run-audit-v1641.sh

## Actual original physical source-linked result

The source-built, unchanged v1638 guest and 48K Type-551 tapes
were replayed with B/A/FULL/rollback/Z MM snapshots. Both B/A
capture six actual unpinned PACKED 007000-word child suffixes.
At the real v1391 post-loader call site, original physical
PC 034361 (HRROI 10,777774), the callback's AC1=0 and the
original MM table has the SAME slot3 owning both:

| Owner | Octal physical words | MM type | Pins |
|---|---|---|---:|
| 3 | 111000..120000 | PACKED_PROCESS | 1 |
| 3 | 120000..130000 | PROCESS destination | 1 |

The test simulator then deposits only AC1=777777777777 (-1).
The following original v1391 error branch returns AC1
777777777774 (MM_ERR_INVAL=-4) to the source-linked v1612
PURE service at physical PC 032461. At that return, slot3's
original PACKED extent remains 111000..120000, pin=0;
the temporary PROCESS destination 120000..130000 is GONE.
No other child owner, pin or MM extent was affected.

The subsequent UNMODIFIED original compressed FULL callback
returns AC1=0 for slot4, with separate pinned PACKED source
101000..110000 and full target 120000..130000. Slot3's
original rejected suffix was still present and unpinned at
that checkpoint. The guest eventually prints all six original
child `w` messages and parent `Z` after six exact EXIT-057/
PID/WAIT/status checks, reaching normal simulator HALT.
At final Z there is no PROCESS/PACKED owner for any child.
The test therefore proves safe cleanup followed by recovery
of all six child users; the first observed successful retry
callback is for slot4, not the originally injected slot3.

The source-linked physical audit PASSes and rejects a forged
still-pinned original suffix at the rollback return as well as
a forged original-loader failure before injection.

Failure-atomic loader-callback rollback is NOT the same as a genuine Type-551 read fault,
immutable source loss/unmount, PI6 interleaving or a transient
whole-system peak measurement. Those remain separate P1-E gates.

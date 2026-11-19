# P1-E v1639: physical six-child PURE ON/OFF matched RAM snapshots

Date: 2026-11-17. Source-identical PDP-6 48K TSFS/no-AUX
guest, unchanged fixed KCORE and corrected low-BCACHE placement.
This experiment adds NO production code or second MM registry.

The original v1637 C89 guest admits six sleeping child processes,
attempts a seventh RUN that returns -1 due to memory pressure,
keeps the parent alive and checks the original PIPE read, both
private writable sentinels, child EXIT status 057, six exact
PID/EXITED/status-057 parent WAITs, and terminal `Z`.

`run-off-v1639.sh` builds this exact source with the optional
PURE MRES switched OFF. The accepted v1637 PURE-on image and
the v1639 control have BYTE-IDENTICAL guest INIT DXRs, C input
and fixed `kcore.map`. The ONLY differing optional subsystem is
the installed 1758-decimal-word PURE MRES. Both physical guest
consoles reach six initial `a` markers, expected seventh RUN
refusal `x`, exact parent BRK checks and `LwwwwwwZ` before
normal simulator HALT. The OFF console includes
`[B073470/037143]`, while ON includes `[B013470/042501]`;
these MEMINFO values are logical counters, NOT physical free RAM.

Build the source-matched 48K control:

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_ON_BUILD_V1639=/path/to/original/v1637/build \
        sh tests/diagnostics/pure-six-matched-v1639/run-off-v1639.sh

Replay that exact compiled OFF guest with read-only SIMH MM
snapshots at parent B/A/final Z:

    PURE_OFF_BUILD_V1639=/path/to/off/build \
        sh tests/diagnostics/pure-six-matched-v1639/replay-off-v1639.sh

Then run the auditor against the completed original v1637 ON
B/A/Z trace and new v1639 OFF B/A/Z trace:

    PURE_ON_CASE_V1639=/path/to/v1637/on \
    PURE_OFF_CASE_V1639=/path/to/v1639/off \
    PURE_ON_TRACE_V1639=/path/to/on/trace.clean \
    PURE_OFF_TRACE_V1639=/path/to/off/trace.clean \
        sh tests/diagnostics/pure-six-matched-v1639/run-audit-v1639.sh

## Real PDP-6 MM results (36-bit words)

| Stage | ON occupied oct | ON free oct | OFF occupied oct | OFF free oct | ON-OFF free decimal |
|---|---:|---:|---:|---:|---:|
| B, parent alive | 066433 | 006564 | 074433 | 004122 | +1314 |
| A, parent alive | 066433 | 006564 | 074433 | 004122 | +1314 |
| Z, all children reaped | 011536 | 063461 | 011335 | 067220 | -1887 |

While six children are sleeping/PACKED, the physical ON guest
has **3444 decimal free words** against **2130 decimal** OFF,
a **+1314-word physical free advantage**. Six omissions of
001000-octal PURE prefixes each gross 3072 decimal; installing
the optional MRES costs 1758 decimal. The exact difference is
3072 - 1758 = **1314** decimal words. The original MM tables
confirm six unpinned PACKED suffixes (ON) versus six full unpinned
PROCESS APR owners (OFF), no duplicate or overlapping owners.
The original source-matched linker maps confirm the optional
MRES lowers ON managed-arena capacity by 003336 octal words.

At terminal Z, both child owner sets are completely released.
ON nevertheless has 1887 decimal fewer free words than OFF:
the 1758-word optional MRES still exists and the ON guest has
an extra legitimate 0201-octal-word BCACHE private slab at Z
(129 decimal), while OFF has no corresponding slab allocated.
This is an unequal terminal CACHE state, NOT evidence that the
PURE restore leaked 129 words or that the six-owner saving
persists after process exit.

The strict testkit audit PASSes. It rejects a falsified original
OFF PROCESS-owner number and a falsified terminal parent WAIT
success marker. Every stage has original sorted physical MM
extents inside actual managed arenas, parent APR remains at
130000..140000 octal, and child ownership clears at Z.

**Scope limitation:** these are physical samples at three
explicit source-authenticated progress markers, not the maximum
simultaneously allocated words during PACKED->PROCESS restores.
No transient FULL-target peak, complete throughput comparison,
source-loss/PI6/rollback or entire-system 32K feature freeze has
been claimed. PURE remains OFF by default. Strict 32K whole-
KCORE size optimization stays HOLD pending full P1-E acceptance.

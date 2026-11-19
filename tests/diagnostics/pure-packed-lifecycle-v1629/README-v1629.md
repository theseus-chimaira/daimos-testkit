# P1-E v1629: physical 48K PACKED restoration with live parent

The successful 64K v1627 parent completed all six WAITs but v1628
proved no child was PACKED at any sampled point. Genuine physical
48K v1625, conversely, showed five actual 007000-word PACKED
suffixes after the sixth `RUN` failed `EXEC_LOAD_NOMEM`, but its
original test killed the parent on that resource refusal.

v1629 is a separate source-checked 48K test derived only from the
original C89 v1614 child/PIPE/WAIT diagnostic. It starts FIVE
children and waits for all five to reach SLEEP, attempts a sixth
RUN with the original PIPE input and requires its expected -1
resource refusal, then prints `x` and keeps the parent alive.
It uses an exact no-growth BRK target 010000, and the `L` marker
only establishes lifecycle/accounting, not positive net RAM.
It preserves every child's original PIPE read, two mutable-data
sentinels and EXIT status 057 octal, plus the parent's strict
five PID/EXITED/status-057 WAIT checks and final data checks.

Run the actual physical guest:

    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-packed-lifecycle-v1629/run-v1629.sh

The original physical 48K output reached:

    aaaaax[B013060/042502]<010000+010000>
    [A013060/042502]{013060-013060}LwwwwwZ

This is one continuous line in the real console and ends in normal
SIMH HALT. Unlike the historical early-refusal guest, the parent
remains alive and confirms all five child EXIT statuses before Z.

To prove the physical PACKED ownership and post-WAIT cleanup,
replay the SAME saved compiled guest and root tapes with three
source-linked MM snapshots:

    PURE_PACKED_BUILD_V1629=/path/to/guest/build \
        sh tests/diagnostics/pure-packed-lifecycle-v1629/replay-v1629.sh

Then check the exact trace plus two unsafe mutations:

    PURE_PACKED_BUILD_V1629=/path/to/guest/build \
    PURE_PACKED_TRACE_V1629=/path/to/physical/trace.clean \
        sh tests/diagnostics/pure-packed-lifecycle-v1629/run-audit-v1629.sh

Only the source-matched live B/A MM owners and final Z owner release
can close the actual PACKED -> restored PROCESS -> EXIT functional
slice. No transient peak or full-system net RAM saving is inferred
from MEMINFO's logical process word counts alone.

## Original physical three-stage result

The original replay completed with B, A and Z MM snapshots, source-
matched linked `kcore.map`, and a normal final simulator HALT.

| Stage | Extents (octal) | PACKED owners | Occupied | Free gaps |
|---|---:|---:|---:|---:|
| B | 022 | 5 | 057023 | 016173 |
| A | 022 | 5 | 057023 | 016173 |
| Z | 010 | 0 | 011536 | 063460 |

At both B and A the exact five unpinned PACKED suffixes are:
owner 6 `057000..066000`, owner 5 `067000..076000`, owner 4
`077000..106000`, owner 3 `107000..116000`, owner 2
`117000..126000`. Every suffix is 007000 octal physical words.
All five have disappeared at Z, and no child PROCESS owner survives
the five successful WAITs. The parent remains current slot 1.
The auditor PASSes and rejects both a foreign-owner mutation and
a forged final parent `Z` result.

These five 001000-word omitted prefixes amount to 2560 decimal
gross omitted physical words while packed. The installed GCC PURE
service alone costs 1758 decimal words, leaving a tentative 802
decimal-word margin BEFORE auxiliary allocations, restore scratch
and transient peak. It is NOT an accepted whole-system net saving.

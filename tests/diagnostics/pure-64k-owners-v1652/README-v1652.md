# P1-E v1652: PDP-6 64K genuine nine-PACKED-owner acceptance

Date: 2026-11-17. Original source-derived 64K PDP-6
PURE/TSFS/DTFS guest PASS; separate B/A/Z MM replay PASS.
Production KCORE, MRES, MM, VFS, scheduler and ABI unchanged.

## Workload

The source-derived v1643 compressed-secondary-DTFS guest
increases its original six-child array to nine children.
The parent mounts original native DTFS DTC3, copies the
same newly compressed DXR2 from TSFS via user syscalls,
CLEAN-unmounts then mounts RO, and RUNs one plain plus
eight compressed children. Original PIPE, private writable
sentinels, EXIT-057 and exact PID/WAIT assertions survive.
The tenth RUN must refuse. The first experimental ten-child
run admitted nine and rejected the tenth with !r, but
failed its ten-child expectation. Final nine-child source
prints aaaaaaaaa x, B/A, L, nine w, Z and normal PC000000
HALT (without a separating space before x).

## Observed 64K native MM

| Checkpoint | PACKED children | Pins | Free words | Largest gap |
| --- | ---: | ---: | ---: | ---: |
| B | 9 | 0 | 9404 | 4155 |
| A | 9 | 0 | 9404 | 4155 |
| Z | 0 | none | 42769 | 42769 |

The original single arena is 042601..200000 octal:
47743 decimal 36-bit words. Slots 2..10 are nine
distinct, unchanged PACKED_PROCESS extents, 006600
octal or 3456 decimal words each, based on text 001227
and omitted prefix 001200 octal. The plain parent
retains its 010000 octal PROCESS APR. At Z the exact
original nine exit/WAITs finish and no child MM
PROCESS/PACKED owner remains. Three independent fake
traces are rejected: wrong child MM type, duplicate
owner and forged parent WAIT success.

## Reproduce

From daimos-testkit, set DAIMOS_REPO to original sources,
PDP10_PREFIX to the installed toolchain and TMPDIR to
a writable scratch directory. Run:

    sh tests/diagnostics/pure-64k-owners-v1652/run-v1652.sh

Then set PURE_64K_BUILD_V1652 to the emitted guest/build:

    sh tests/diagnostics/pure-64k-owners-v1652/replay-v1652.sh

Finally set PURE_64K_TRACE_V1652 to emitted replay/trace.clean:

    sh tests/diagnostics/pure-64k-owners-v1652/check-mm-v1652.sh

The independently source-linked guest audit is audit-v1652.py.
No test code is inside production DAIMOS.

## Limits

This is an independent 64K physical nine-PACKED-owner
lifecycle and real MM cleanup, not a 48K projection.
Matched 64K PURE ON/OFF net saving, physical transient
FULL peak, 32K profile, permanent unknown MM pins and
KA10 remain OPEN. PURE disabled by default; strict 32K
whole-KCORE optimization HOLD.

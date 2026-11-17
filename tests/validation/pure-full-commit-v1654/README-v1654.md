# P1-E v1654: FULL transaction commits only after destination unpin

Date: 2026-11-17. Source-linked native PDP-6 transaction PASS.
Production change is opt-in PURE MRES ONLY, no permanent KCORE
instructions, per-process state, ABI or process registry.
The separate rebuilt physical 48K PDP-6 DTC3 read-error,
rollback, same-reel recovery, full restore and WAIT/HALT
regression also PASSed, with both forged physical witnesses
rejected by the source-linked original v1643 auditor.

## Old failure and corrected ordering

Before v1654 the bounded FULL transaction could release its only
authoritative PACKED RAW source, publish a runnable RESIDENT APR,
then discover that the target MM unpin failed. The process was
held TRANSITION with no original RAW source left and the new
APR still pinned. Neither a normal packed-source retry nor a
safe runnable activation was possible.

The corrected source-linked C transaction keeps source and
target pinned throughout the original possibly slow file read
and writable RAW overlay. It then disables PI ONLY around the
short MM commit: unpin temporary target FIRST, unpin and free
RAW source, publish resident APR/storage/backing, clear
TRANSITION, restore PI. All fallible MM operations precede
authoritative source deletion or resident publication.
No allocation or filesystem read runs with PI disabled.

Transient target-unpin failure allows cleanup unpin/free and
an exact one-owner unpinned PACKED rollback; a later retry
restores all immutable text and retained writable words.
Permanently refused target or source unpins remain safely
TRANSITION-held with unchanged RAW and backing, never
mis-published RESIDENT. Permanently uncertain owners still
require separate recovery design; no blind unlock/free.

## Executed native regression

The historical v1395 native original FULL transaction suite
now checks one-shot destination unpin failure before source
deletion, exact source and no leaked APR, and successful
retry. The original v1648 suite still checks source-free
BUSY/INVAL, target pin BUSY and two executed invalid-source
mutations. New v1654 native PDP-6 cases inject permanently
refused target/source unpins and assert fail-closed exact MM
type/owner/pin, source content, storage mode and TRANSITION.

An independently assembled and executed test-only mutation
moves destination unpin back after RESIDENT publication. It
must FAIL the updated original v1395 transaction oracle
(not simply fail compilation).

Run from the daimos-testkit root with original DAIMOS source:

    export TMPDIR=$HOME/tmp
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=/path/to/DAIMOS
    sh tests/validation/pure-full-commit-v1654/run-v1654.sh

## Source-linked actual 48K physical replay

The original accepted v1643 48K DTC3 source-failure test
requires exact linked breakpoint addresses. In the new
GCC MRES, the restore entry stays 002207 octal, the bounded
loader return still 002333, but bounded loader entry moves
from 003224 to 003233. The v1654 prepare-physical script
validates these exact symbol-map values and regenerates the
original strict v1643 replay and physical auditor with that
single verified address update. It preserves genuine
secondary DTC3 loss, independently pinned RAW/destination,
full original rollback/retry, same-private-reel recovery,
all PID/WAIT checks and invalid trace witnesses.

First build a source-derived original physical 48K guest:

    sh tests/diagnostics/pure-secondary-read-v1643/run-v1643.sh

Then set PURE_FULL_BUILD_V1654 to the emitted guest/build and run:

    sh tests/validation/pure-full-commit-v1654/run-physical-v1654.sh

The fixed KCORE stream remains byte-identical with accepted
v1652; optional GCC PURE MRES/KINIT transient text grows only
eight PDP-10 words. No 32K boot/runtime claim is made.

## Remaining acceptance

Permanent uncertainty in MM pin/owner storage still fails
closed, not automatically repaired. Matched continuous peak
RAM, KA10 VM segment ownership, and optional compressed
process swap are separate KCORE gates. Explicitly defer
32K acceptance until functional freeze and final RAM-size
optimization; do not weaken the original KINIT stack reserve.

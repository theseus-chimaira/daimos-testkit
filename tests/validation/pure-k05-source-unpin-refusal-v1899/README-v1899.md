# K05 v1899: genuine native source-unpin -4, safe target free and retry

Date: 2026-11-23. Scoped original **48K PDP-6 physical PASS**,
including original five-child PIPE/BRK, mutable-data sentinels,
typed EXIT/WAIT, final parent Z and actual HALT. Thirteen
executed unsafe physical negative transcripts are rejected.
No production KCORE, PURE MRES, allocator, scheduler or user
source change is needed for this demonstrated case.

## The precise failure

v1898 proved genuine target-unpin -4 at BOTH original commit
and cleanup calls after a test-only zero-target-pin deposit,
retaining both MM owners and a quarantined child. v1899
exercises the different **source** commit `mm_unpin` call,
AFTER the original target unpin succeeded. An unexpected
zero-pin source must cause the real native `mm_unpin(source)`
to return `MM_ERR_INVAL=-4`. The C caller sets its original
`source_uncertain=1` flag; it must not unpin the source again
because it no longer knows whether that original pin exists.
It may free the now-unpinned temporary complete PROCESS target,
provided actual native MM accepts that release, and must
retain the authoritative PACKED RAW suffix and nonresident
TRANSITION state for later safe retry.

**Fault-model limit:** The original v1855 one-pin owner guard,
target unpin and source unpin all execute under PI exclusion.
An ordinary interrupt cannot remove a physical source pin
between the guard and the original source unpin. Here a private
SIMH controller deliberately changes exactly one source MM
metadata word while the CPU is stopped at the original call.
The test demonstrates real fail-closed handling of an unexpected
physical pin state, not a naturally occurring scheduler race.

## Original source-linked machine instructions

The original full v1855 48K five-child guest and production
fixed-KCORE and opt-in PURE MRES images are unchanged. The
original KCORE reclaim JRST physically establishes installed
PURE base `032417` octal. The compiled original FULL DOBJ symbol
`.text+000504`, all four real `mm_unpin` relocations and both
`mm_free` relocations are compared to linked original MRES
`PUSHJ 17,mm_unpin/mm_free` opcodes, not guessed addresses.

Original physical PDP-6 PCs (octal):

* target commit `mm_unpin` `035271` (already succeeded);
* source commit `mm_unpin` **`035276`**, return **`035277`**;
* original rollback target `mm_free(PROCESS)` `035371`,
  return `035372`;
* original full PURE service return `033067`.

At the original pinned FULL stage, MM has 18 records, including
slot3 authoritative PACKED RAW `111200..120000` pin1 and full
temporary PROCESS `120000..130000` pin1. The unchanged loader
completes, the original v1855 exact owner guard passes, and
original target unpin succeeds (target pin0). At the original
SOURCE `mm_unpin` call, the authoritative source remains pin1,
and the target is pin0, with 18 descriptors and unchanged root.

Only the private stopped-simulator test controller changes the
original source metadata word `024703` (octal):

    000014000003 (PACKED, slot3, pin1)
    000004000003 (PACKED, slot3, pin0)

The ORIGINAL fixed-KCORE `mm_unpin` physically executes,
returning genuine `MM_ERR_INVAL=-4` as AC1 `777777777774`
at original source-unpin return PC `035277`. Both exact
original slot3 extents remain: source pin0 and target pin0,
MM count18. The original C sets `source_uncertain=1` and enters
`fail_target`, WITHOUT trying to unpin the uncertain source
again. At actual original target-free PC `035371`, the target
is still the exact complete unpinned PROCESS owner. The real
fixed-KCORE `mm_free(PROCESS)` executes SUCCESSFULLY, returns
AC1=0 at `035372`, and physically deletes the target.

Original MM count falls **18 to 17**, with the precise sole
slot3 owner PACKED RAW `111200..120000` pin0 retained. The
original FULL reports its native source-unpin result -4 at
service `033067`, keeping original slot3 TRANSITION and VMbase0.
Physical original process descriptor at `044723` is
`046031600401` (TRANSITION set), VM word `044724` is
`010000000000` (physical APR zero). Neither owner geometry nor
the selected TSFS ROOT `070101000000` changes except the verified
temporary PROCESS target deletion.

The unchanged original five-child user program then retries,
completes its original PIPE/sentinel/typed EXIT/WAIT tests,
prints parent `Z` and executes real
`HALT instruction, PC: 000000`. The final original MM table has
8 entries and **no slot3 PACKED or PROCESS reservation**.
This is a whole-guest recovery proof, not merely a parent HB.

## Original MM checkpoints (octal)

| Stage | Count | PACKED RAW source | PROCESS target |
|---|---:|---|---|
| Pinned FULL | 18 | pin1 | pin1 |
| Native source-unpin entry | 18 | pin1 | pin0 |
| Native source `mm_unpin` returns -4 | 18 | pin0 | pin0 |
| Original target cleanup-free entry | 18 | pin0 | pin0 |
| Original target free succeeds | 17 | pin0 | deleted |
| Original FULL returns -4, VM0 | 17 | pin0 | deleted |
| Five children EXIT/WAIT, parent Z/HALT | 8 | gone | gone |

Independent physical audit verifies all original source-linked
native PCs, actual native -4 before the C caller, exact
owner/type/length/pins, original target rollback success and
physical deletion, authoritative RAW suffix, unmodified ROOT
and unrelated MM owners, slot3 TRANSITION/VM0, all five child
EXIT/WAIT status and parent HALT. Thirteen separate unsafe
physical transcripts are executed and rejected at intended
pin/MM/native-return/process/terminal-HALT checks.

Original normalized physical PDP-6 console SHA256:
`32b178432dce4404a405b15cb7a812718115205ad4a119f376256142abc68844`.
Original fixed KCORE SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Original optional PURE MRES SHA256:
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.

## Reproduction

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1899_BUILD=$TMPDIR/pure-brk-pressure-v1614.qnobNT/build
    export V1899_PROBE=$TMPDIR/daimos-k05-pin-probe-v1890/probe.clean
    export V1899_PRIOR=$TMPDIR/daimos-k05-target-free-lost-reply-v1897-real
    export V1899_WORK=$TMPDIR/daimos-k05-source-unpin-refusal-v1899-real
    make test-pure-k05-source-unpin-refusal-physical-v1899
    make test-pure-k05-source-unpin-refusal-audit-v1899

This accepts ONE real native source-unpin -4 outcome with
test-only zero source pin, successful actual target disposal,
unchanged RAW source and subsequent five-child HALT. It does
not establish lost successful source-unpin replies, foreign or
replaced MM owners, persistent unpin errors, terminal cleanup
of permanently quarantined processes, alternate PI6 orders,
64K/KA10 or whole K05-K09 release. RAW PURE/mode3 stay OFF.
Zero permanent production code/RAM growth.

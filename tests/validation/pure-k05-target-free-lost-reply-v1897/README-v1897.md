# K05 v1897: actual PDP-6 target cleanup free succeeded; reply lost

Date: 2026-11-23. **Scoped 48K original full-system physical PASS**.
No production kernel or removable PURE MRES edits. Original
five-child PIPE/BRK/EXIT/WAIT, writable-data sentinels and final
parent HALT complete even though the original successfully freed
PROCESS target is reported as `MM_ERR_BUSY=-5` to its C caller.

## Why this scenario matters

The original v1839 FULL source-free error reconciliation handles
ambiguous successful PACKED-source deletion by checking the exact
surviving MM owner set. The `fail_target` rollback is intentionally
more conservative: any failed `mm_free(PROCESS)` reply returns
`MM_ERR_BUSY` without speculatively freeing the authoritative RAW
source or publishing an incomplete APR. v1896 already proved that
the original target `mm_free` REALLY refuses a new pin and preserves
both owners/quarantine. v1897 proves the opposite: the target free
PHYSICALLY completes before a false -5 return is introduced.

The full original v1855 48K PDP-6 with the unchanged five-child
user program and unmodified original secondary DTC3 compressed
backing is used. The real original full loader, both native MM
frees, original service return, recovered children and HALT are
observed. The permanent fixed KCORE, opt-in PURE MRES, original
source media, parent INIT and all child code are byte-identical
to the accepted v1894 five-child build.

## Source-linked physical transaction

The source-linked KCORE reclaim JRST determines installed PURE
base `032417` octal. The original compiled DOBJ FULL symbol
`.text+000504` and two `mm_free` relocations `.text+000674`
and `.text+000755` are checked against the actual linked MRES
`PUSHJ 17,mm_free` instructions. Original physical PCs:

* original bounded FULL `036202`;
* original PACKED source free `035310`, return `035311`;
* original temporary PROCESS target cleanup free `035371`,
  return `035372`;
* original FULL service `033067`.

The original full MM table has 18 extents at pinned FULL, including
slot3 authoritative PACKED RAW `111200..120000` pin1 and separate
complete PROCESS target `120000..130000` pin1. After both normal
unpins, one private test-only source pin causes the REAL original
`mm_free(PACKED)` to refuse with its OWN `MM_ERR_BUSY=-5`. The
external source pin is then released. Original v1839 source-free
owner reconciliation finds exactly two complete, unpinned slot3
owners and enters the REAL `fail_target` cleanup at `035371`.

Unlike v1896, the original target is left unpinned (pin0), and
the simulator allows original unmodified fixed-KCORE
`mm_free(PROCESS)` to fully execute. At its actual return
`035372`, AC1 is **0** (`MM_OK`) and the 18-entry MM table has
PHYSICALLY dropped to 17 extents; the temporary target is GONE.
The sole surviving original slot3 owner is precisely PACKED RAW
`111200..120000` pin0, and all other MM owners/pins, as well as
selected TSFS root `070101000000`, remain unchanged.

ONLY AFTER physical successful target deletion, a private test
controller deposits `AC1=777777777773` (-5). No kernel opcode,
MM descriptor, RAW extent, executable backing or guest word is
changed. The original `fail_target` correctly returns -5 to the
FULL caller at `033067`; slot3 remains TRANSITION, VMbase0 and
has the sole source PACKED extent intact (MM count17). This is
conservative, safe nonpublication; it is not falsely reported as
immediate successful completion.

The unchanged original guest subsequently retries the child
restore, executes the complete original PIPE/BRK/checks, all five
typed EXIT/WAIT and mutable-data sentinels, prints parent `Z`
and physically reaches `HALT instruction, PC: 000000`.
Final original MM count is 8 and slot3 has NO PACKED or PROCESS
extents remaining. No return-status or process owner was modified
in the production kernel.

## Original MM snapshots (octal)

| Original checkpoint | MM count | PACKED source pin | PROCESS target pin |
|---|---:|---:|---|
| FULL pinned entry | 18 | 1 | 1 |
| Native source-free entry | 18 | 0 | 0 |
| Native PACKED free refused -5 | 18 | 1 | 0 |
| External source pin released | 18 | 0 | 0 |
| Original native target cleanup free call | 18 | 0 | 0 |
| Original target free returns MM_OK | 17 | 0 | deleted |
| Only AC1 changed to false -5 | 17 | 0 | deleted |
| Original FULL returns -5, slot3 VM0 | 17 | 0 | deleted |
| All children reaped and parent Z/HALT | 8 | gone | gone |

The independent read-only audit checks actual original native PCs,
initial pinned pair, real source MM refusal, source pin release,
exact pair at target-free invocation, true original AC1=0,
physical target deletion, false AC1=-5 after commit, retained
authoritative RAW source, quarantined original process VM0,
unchanged unrelated MM/ROOT, typed child WAIT and terminal HALT.
**TWELVE executed deliberately unsafe physical transcript mutants**
are rejected at their expected checks: false source-free success,
target already pinned, actual cleanup refusing, unexpected surviving
pin, missing injected -5, foreign RAW owner, falsely successful
FULL return, stale process-table pointer, missing TRANSITION,
published invalid VMbase, incorrect terminal MM count and
missing HALT. The initial test-only negative-control parser
was corrected to accept the same MM count appearing twice in a
single original simulator snapshot; the original physical
transcript was not rerun or edited.

Normalized original physical console SHA256:
`6aeb9da4b13d471ca300b2091b4b663be867f24c3e54850579287f140fa6d11e`.
Unchanged original fixed KCORE SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Unchanged original optional PURE MRES SHA256:
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.

## Reproduction and limits

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1897_BUILD=$TMPDIR/pure-brk-pressure-v1614.qnobNT/build
    export V1897_PROBE=$TMPDIR/daimos-k05-pin-probe-v1890/probe.clean
    export V1897_PRIOR=$TMPDIR/daimos-k05-real-free-refusal-v1894-real
    export V1897_WORK=$TMPDIR/daimos-k05-target-free-lost-reply-v1897-real
    make test-pure-k05-target-free-lost-reply-physical-v1897
    make test-pure-k05-target-free-lost-reply-audit-v1897

This validates the single real original completed rollback-target
deletion with a false -5 return, and eventual safe normal child
recovery. It does NOT solve permanent target pins, foreign owner
states, failed original unpins, lost successful unpin replies,
eventual cleanup of indefinitely quarantined owners, alternative
PI6 timings, KA10/64K or complete K05-K09 acceptance. RAW PURE
and mode3 remain OFF by default. ZERO production code/RAM growth.

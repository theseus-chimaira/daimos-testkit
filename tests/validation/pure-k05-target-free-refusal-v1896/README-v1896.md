# K05 v1896: original PDP-6 target cleanup MM free refusal

Date: 2026-11-23. **Scoped original 48K physical full-system PASS**.
The actual original fixed-KCORE `mm_free` refuses source PACKED
and, later, the provisional PROCESS target rollback, each with its
own *native* `MM_ERR_BUSY=-5` return. A permanent external pin on
the target remains held through original FULL return and two
autonomous parent user heartbeats. No production binary, MM
routine, driver, MRES or user child program changes are needed.

## Why this is a new K05 branch

v1893 physically proved original source deletion committed despite
a falsely failed reply. v1894 proved real source-free refusal
followed by a released temporary source pin and successful target
rollback. v1895 proved permanent source-pin refusal: both extents
retained, TRANSITION held and independent resident parent progress.
v1896 reaches the ACTUAL `fail_target` cleanup after the v1839
original exact-zero-pin owner scan and causes **that original
cleanup `mm_free(PROCESS)` to fail** under a persistent target pin.

The original `proc_pure_ram_restore_v1391.c` `fail_target` branch
must return typed `MM_ERR_BUSY` without speculatively freeing
either owner, clearing TRANSITION or publishing an APR. It must
not conflate failure to dispose of scratch with a completed
rollback. The authoritative PACKED RAW suffix remains available,
and the complete target remains physically allocated even though
no process may yet execute it.

## Exact source-linked original physical instructions

The testkit validates actual original v1855 fixed-KCORE/PURE DXR
SHA256s; the installed MRES base comes from original KCORE reclaim
JRST, not a stale hard-coded address. The original production
`proc_pure_full_v1611.dobj` symbol and BOTH `mm_free` relocations
are compared to the actual linked PURE image PUSHJ opcodes:

* original FULL bounded entry `036202` octal;
* source `mm_free(PACKED)` at `035310`, return `035311`;
* later cleanup `mm_free(PROCESS)` at **`035371`**, return
  **`035372`**, distinct original `fail_target` invocation;
* original FULL service return `033067`.

The source and target MM metadata word addresses are individually
derived from the ORIGINAL full pinned MM table of a prior accepted
original v1894 physical run, not hand-written guesses:

    PACKED source `111200..120000` physical meta `024703`
    PROCESS target `120000..130000` physical meta `024705`

The original FULL completes its data overlay and successful
precommit one-pin owner check; actual original source/target unpins
leave both zero. A test-only source pin is introduced at the actual
source-free call and the original fixed-KCORE MM itself returns
`MM_ERR_BUSY=-5`, leaving both extents. Only THAT transient test
pin is released. The original v1839 MM owner scan sees precisely
two complete unpinned original owners and chooses `fail_target`,
whose actual physical `mm_free(PROCESS)` call is observed at
`035371`. At that precise call, both owner pins are still 0 and
original MM count remains 18.

The test-only simulator changes ONLY target physical metadata:

    before cleanup call: `024705: 000001000003`  (pin0)
    external target pin: `024705: 000011000003`  (pin1)

The original unchanged fixed-KCORE `mm_free(PROCESS)` now actually
returns `777777777773` octal (-5) at original `035372`. The
complete provisional target is not deleted; the authoritative RAW
source is unpinned and intact; all 18 original MM extents are
unchanged except the one external target pin. That target pin is
**NEVER released** in the v1896 physical experiment.

Original FULL returns `MM_ERR_BUSY=-5` at `033067`, preserving
slot3 TRANSITION and VMbase0. Original slot3 physical process
descriptor at `044723` is `046031600401` (TRANSITION set), VM
word at `044724` is `010000000000` (no APR publication). Root
`070101000000` octal and all unrelated physical MM owners remain
unchanged through subsequent independent user execution.

The source-built v1892 test-only parent fixture retains all five
original child RUN/BRK/PIPE pressure paths and writable-data
checks, but its already-resident parent emits repeated `HB`
markers instead of blocking in WAIT for the held child. Two new
parent user HBs are physically observed after the failed cleanup,
both with `proc_current_slot=1`, the parent `SRUN`, VM at valid
APR `130000..140000` and original PROCESS MM pin0. Real original
PCLK advances between those HBs from `015401` to `015564` octal.
No child EXIT/WAIT/HALT under the unresolved pin is claimed.

## Physical MM stages

| Original runtime point | MM count | source pin | target pin |
|---|---:|---:|---:|
| Pinned FULL entry | 18 | 1 | 1 |
| Original source free call | 18 | 0 | 0 |
| Genuine source free -5 | 18 | 1 | 0 |
| External source pin released | 18 | 0 | 0 |
| Original cleanup target free call | 18 | 0 | 0 |
| Genuine target cleanup free -5 | 18 | 0 | 1 |
| Original FULL return | 18 | 0 | 1 |
| Both new parent heartbeats | 18 | 0 | 1 |

The independent physical read-only verifier checks source and
target **original native** MM -5 replies, both source-linked
relocations/linked opcodes, exact owner/size/pin geometry at every
stage, no target or source deletion, no invalid process publication,
ROOT and all unrelated MM conservation, and both new original
parent HBs with advancing original PCLK. **THIRTEEN** separately
executed unsafe physical transcripts are rejected, including
missing source refusal/release, pre-pinned target, missing injected
pin, false target-free success, source or target owner corruption,
false process publication, wrong original service return, wrong
user dispatch, stalled clock and missing second heartbeat.

Accepted normalized original physical SHA256:
`b408a84b27b39b351e56196356fb4abaac2b60c64175abe4bb74d38382ab7601`.
Unchanged fixed KCORE SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Unchanged optional PURE MRES SHA256:
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.

## Reproduction

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1896_BUILD=$TMPDIR/pure-brk-pressure-v1614.UQzCQO/build
    export V1896_PROBE=$TMPDIR/daimos-k05-resident-peer-probe-v1892/probe.clean
    export V1896_PRIOR=$TMPDIR/daimos-k05-real-free-refusal-v1894-real
    export V1896_WORK=$TMPDIR/daimos-k05-target-free-refusal-v1896-real
    make test-pure-k05-target-free-refusal-physical-v1896
    make test-pure-k05-target-free-refusal-audit-v1896

This closes the **real refused temporary-target cleanup free under
a persistently held target pin**, including fail-closed quarantine
and already-resident unrelated user progress. It does NOT prove
eventual target unpin, terminal owner cleanup, foreign ownership,
ambiguous successful free with lost reply on the TARGET, permanent
unpin/allocator outcomes, child WAIT/HALT, KA10/64K, arbitrary PI6
timings or full K05-K09 release. RAW PURE/mode3 remain OFF. Zero
production code or RAM growth.

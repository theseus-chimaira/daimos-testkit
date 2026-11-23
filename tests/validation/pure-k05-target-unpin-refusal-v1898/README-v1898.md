# K05 v1898: original PDP-6 double native target-unpin refusal

Date: 2026-11-23. Scoped **original 48K full-system physical PASS**.
Two original fixed-KCORE `mm_unpin(PROCESS target)` calls genuinely
return `MM_ERR_INVAL=-4` after one test-only physical zero-pin
injection. The K05 FULL operation fails closed, retains both exact
owners, leaves slot3 TRANSITION/VM0, and an unrelated already-
resident parent emits two new user `HB` markers with advancing
original PCLK. **Thirteen** executed unsafe transcript negatives
are rejected by an independent read-only physical verifier.

## Scope of this injected failure

This is NOT a normal PDP-6 scheduler race. The original v1855
one-pin owner guard and both commit unpins execute inside a
PI-disabled section. A normal asynchronous MM client cannot
remove the target pin between that guard and `mm_unpin`. To
exercise the REAL native failed-unpin paths, the private SIMH
controller changes exactly one MM metadata word **while the CPU
is stopped at the original call**, making the original allocator
observe a zero pin count. This tests defensive handling of an
unexpected MM state, not the likelihood of that state occurring.

Original 48K production fixed KCORE and optional PURE MRES remain
byte-for-byte identical to v1890-v1897. The source-built v1892
test-only user fixture preserves original five child RUN/BRK/PIPE
pressure, root and secondary compressed DTC3-backed executables,
and writable checks. Its already-resident parent prints repeated
`HB` instead of waiting for a deliberately quarantined child.

The original compiled `proc_pure_full_v1611.dobj` FULL symbol,
all **four** original `mm_unpin` relocations and actual original
linked `PUSHJ 17,mm_unpin` opcodes are independently checked.
The installed PURE base is derived from the original KCORE
reclaim JRST probe, not guessed. Actual native PDP-6 PCs (octal):

* original full loader `036202`;
* original target commit `mm_unpin` `035271`, return `035272`;
* original `fail_target` retry `mm_unpin` `035362`, return `035363`;
* original full service return `033067`.

## Original physical MM and process proof

The pinned FULL MM table contains 18 extents, including slot3
PACKED RAW source `111200..120000` pin1 and full PROCESS target
`120000..130000` pin1, plus separate parent slot1 PROCESS
`130000..140000` pin0. Both owners are STILL pin1 at the first
original unpin call after the original precommit one-pin guard.
The private simulator then changes ONLY the target descriptor:

    024705: 000011000003 -> 000001000003
             target pin1         target pin0

The original unchanged `mm_unpin` genuinely refuses this already
zero-pin target with **AC1 `777777777774` = -4** at physical
return PC `035272`. Source still pin1, target pin0, MM count18.
The C FULL restore invokes its actual `fail_target` cleanup and
retries `mm_unpin(target)` at `035362`: it STILL finds pin0 and
genuinely returns **-4** at `035363`. No other test deposit is
made; the target pin remains zero.

The original fail-closed C path returns **`MM_ERR_BUSY=-5`** at
FULL service `033067`, without attempting to free the target,
unpin/source-free the sole authoritative PACKED RAW suffix, or
publish a RESIDENT APR. All 18 original MM descriptors and
selected TSFS root `070101000000` remain identical from the
first unpin refusal through the original FULL return and two
postfailure parent user HBs. Slot3 meta at `044723` is
`046031600401` (TRANSITION set), VM at `044724` is
`010000000000` (physical APR zero).

At both new user `HB` outputs, the actual current process is
slot1, SRUN and resident at valid APR `130000..140000` pin0.
Original PCLK advances from `016325` at the first heartbeat to
`016425` octal at the second. The original MM table remains
unchanged, including source pin1 and complete target pin0.

| Original physical stage | MM count | PACKED source | PROCESS target |
|---|---:|---|---|
| Pinned FULL / precommit target unpin call | 18 | pin1 | pin1 |
| Test-only target pin set to zero | 18 | pin1 | pin0 |
| Original first `mm_unpin` native -4 | 18 | pin1 | pin0 |
| Original cleanup retry native -4 | 18 | pin1 | pin0 |
| Original FULL returns -5 | 18 | pin1 | pin0 |
| Both subsequent resident parent user HBs | 18 | pin1 | pin0 |

The read-only audit checks both exact source-linked native PCs
and AC1 results, owner geometry and pins at all original MM
snapshots, no target free/source unpin, process TRANSITION/VM0,
parent dispatch/resident APR/SRUN and real original PCLK.
**Thirteen** separate forged physical transcripts are executed
and rejected: original pin unexpectedly zero, injection absent,
either native -4 replaced by false success, changed MM owner
pins, cleanup not seeing pin0, falsely successful FULL, invalid
child VM or TRANSITION, wrong parent slot, stale PCLK or missing
second HB.

Original normalized full physical trace SHA256:
`c7d5350098f69474e1fd2398c0822d3abf11bd21ad754c5a69d973a7ef3e215e`.
Fixed KCORE DXR SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Optional PURE MRES DXR SHA256:
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.

## Reproduction

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1898_BUILD=$TMPDIR/pure-brk-pressure-v1614.UQzCQO/build
    export V1898_PROBE=$TMPDIR/daimos-k05-resident-peer-probe-v1892/probe.clean
    export V1898_PRIOR=$TMPDIR/daimos-k05-target-free-lost-reply-v1897-real
    export V1898_WORK=$TMPDIR/daimos-k05-target-unpin-refusal-v1898-real
    make test-pure-k05-target-unpin-refusal-physical-v1898
    make test-pure-k05-target-unpin-refusal-audit-v1898

The simulator exits after the two new parent HBs. This does
NOT prove a naturally occurring PI-atomic pin loss, subsequent
source unpin, permanent quarantined-owner cleanup, original
child EXIT/WAIT/HALT, source-side unpin errors, foreign owners,
64K/KA10 or general K05-K09 acceptance. RAW PURE/mode3 remain
disabled by default. No production kernel or RAM growth.

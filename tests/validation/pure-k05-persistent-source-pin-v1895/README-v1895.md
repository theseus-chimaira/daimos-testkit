# K05 v1895: persistent original source pin after genuine PDP-6 MM -5

Date: 2026-11-23. **Scoped original 48K full-system physical PASS**.
The unchanged production fixed KCORE and optional PURE MRES execute
the genuine original `mm_free(PACKED)` and refuse a pinned RAW source.
Unlike v1894's temporarily pinned source, the external test pin is
**never released** during this experiment. The original transaction
must quarantine slot3 without releasing either original MM extent;
an independently resident parent must nevertheless continue running.

## Original hardware, exact fault and preserved owners

The test combines two already source-built accepted fixtures:
the original v1894 source-free native MM call/return validation,
and the v1892 test-only guest that preserves all original five-child
RUN/BRK/PIPE pressure before keeping only its already-resident
parent emitting `HB` after user `sleep(0100)` and two mutable-data
sentinel checks. This parent-only change does NOT modify KCORE,
PURE MRES, the five original child code paths or their source media.

The original installed PURE base is independently read from the
physical KCORE reclaim-JRST probe. The original FULL production
DOBJ symbols/relocations and linked MRES bytes identify:

* original bounded FULL entry `036202` octal;
* actual `PUSHJ 17,mm_free(PACKED)` at `035310`;
* actual return-status consumer `035311`;
* original FULL service return `033067`;
* original physical PACKED MM meta `024703`.

Original FULL entry MM count is 18, including authoritative slot3
PACKED RAW `111200..120000` pin1, provisional full PROCESS
`120000..130000` pin1, and independent parent PROCESS
`130000..140000` pin0. The real original loader completes and
both original unpins succeed; immediately before its real source
`mm_free` call both slot3 owners are pin0. One private SIMH deposit
increases only the PACKED source to physical pin1:

    024703: 000004000003 -> 000014000003

The **original** unmodified fixed-KCORE `mm_free` executes and
genuinely returns `MM_ERR_BUSY=-5` (AC1 `777777777773`) because
its original exact MM descriptor is pinned. The source is NOT
deleted, the complete target is NOT deleted, MM count remains 18,
and no other MM owner or selected TSFS root changes.

Unlike v1894, there is deliberately **no source-pin release**.
The original v1839 zero-pin owner reconciliation sees the source
still pinned, so it cannot safely establish either the sole
complete PROCESS successor or the exact TWO unpinned owners needed
for rollback. It returns `MM_ERR_BUSY=-5` at original FULL service
without releasing either owner, clearing TRANSITION or publishing
a runnable VM base. Slot3 physical process record:

    proc_table:  044712
    slot3 meta:  046031600401   (TRANSITION set)
    slot3 VM:    010000000000   (physical VM base 0)

At the original FULL service and two LATER parent user-output stops,
the entire ORIGINAL MM extent table is byte-for-byte identical to
the genuine refused source-free snapshot: all 18 physical extents,
including source pin1 and target pin0, preserved with exact owner,
type, size and base. ROOT is unchanged. No synthetic READY_ONCE,
unblocked child, guest HALT or source release is claimed.

The already-resident parent slot1 genuinely outputs TWO new `HB`
markers, through normal user syscalls after the failed FULL. At
both output stops, `proc_current_slot=1`, parent slot1 has an
unquarantined resident `130000..140000` PROCESS APR pin0 and its
scheduler state is SRUN. The original fixed-KCORE clock advances
from `016640` at the first HB to `016740` octal at the second.
The first HB can legitimately share the same clock value as the
failed FULL service: the only required tick progression is
BETWEEN the independently emitted HBs, not an invented earlier PI6.
The private controller exits after the second physical HB, so
this is deliberately NOT a whole guest WAIT/HALT test.

## Physical checkpoints

| Stage | MM count | Source pin | Target pin | Current slot | PCLK |
|---|---:|---:|---:|---:|---:|
| Pinned FULL | 18 | 1 | 1 | 0 | -- |
| Original source-free call | 18 | 0 | 0 | 0 | -- |
| Genuine original `mm_free` -5 | 18 | 1 | 0 | 0 | -- |
| Original failed FULL service | 18 | 1 | 0 | 0 | `016640` |
| New parent `HB` 1 | 18 | 1 | 0 | 1 | `016640` |
| New parent `HB` 2 | 18 | 1 | 0 | 1 | `016740` |

The read-only audit verifies the actual original production
image hashes, all original linked PCs, genuine AC1 -5, unique
original MM/source/target descriptors, unchanged full owner table,
slot3 TRANSITION/VM0, both parent APR/state/current-slot records,
TSFS ROOT and the exact original PCLK delta. TEN separately
executed unsafe transcript variants are rejected at their intended
checks, covering false native return, missing persistent pin,
source/target pin loss or corruption, false APR publication,
missing TRANSITION, wrong current user, stale PCLK, false service
return and a forged second heartbeat.

Accepted original normalized real PDP-6 physical SHA256:
`8f2bb94995d3522b076c845f5e784cb7f682b5cb565ae553b24b717342f62c92`.
Original fixed KCORE DXR SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Optional PURE MRES DXR SHA256:
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.

## Reproduction

From daimos-testkit with the original source-built v1892 parent
guest and the accepted actual original v1894 free-refusal trace:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1895_BUILD=$TMPDIR/pure-brk-pressure-v1614.UQzCQO/build
    export V1895_PROBE=$TMPDIR/daimos-k05-resident-peer-probe-v1892/probe.clean
    export V1895_PRIOR=$TMPDIR/daimos-k05-real-free-refusal-v1894-real
    export V1895_WORK=$TMPDIR/daimos-k05-persistent-source-pin-v1895-real
    make test-pure-k05-persistent-source-pin-physical-v1895
    make test-pure-k05-persistent-source-pin-audit-v1895

The first real physical run correctly passed owner/quarantine/
user-marker checks, but the initial test-only verifier demanded
PCLK progress **before the first HB**, while the actual physical
clock at original FULL service and first HB was the same. Only the
test-only oracle was corrected to require actual progress between
HB1 and HB2. The untouched original physical trace then passed
the independent audit and all 10 executed negatives.

## Scope and exclusions

This physically accepts the **persistent extra source MM pin**
branch of a *genuine* original `mm_free(PACKED)` failure, not a
faked AC1 return. It proves bounded fail-closed quarantine plus
already-resident independent parent progress. It does NOT prove
permanent-source-pin cleanup, release, other child restoration,
normal terminal WAIT/HALT, truly foreign ownership, persistent
target rollback failure, allocation uncertainty, alternate PI6
timings, 64K/KA10 or all K05-K09 release. RAW PURE/mode3 remain
OFF. No production code or RAM increase.

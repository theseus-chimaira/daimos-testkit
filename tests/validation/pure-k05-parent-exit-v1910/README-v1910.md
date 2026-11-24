# K05 v1910: original parent EXIT under unrepaired foreign FULL owner

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS.**

## Scope and actual execution

One source-linked original five-child compressed-TSFS parent is rebuilt
with a **test-only USER APR gate** (`v1910_exit_gate`). Production KCORE
and optional PURE MRES are byte-identical to v1906-v1909. The original
pressure workload really reaches first `mm_free(PACKED)` -5 with two
uncommitted FULL extents. The controller releases the source pin and
changes only the provisional PROCESS target's MM owner3 -> owner2.
The source-linked parent issues one real `PROCCTL TERM(3)`, which
the original kernel refuses (`TR`), then the controller opens the
USER APR EXIT gate `135401` (`065432107654`). The original parent
prints `E` and calls `dsys_exit(0)`; there is no fake MM return,
parent state deposit, forced FINALIZE, or owner repair.

Exact original fixed-KCORE breakpoints prove parent EXIT entered
`proc_exit_current=013655`, continued to the slot-0 owner finalizer
`proc_finish_slot_owner_v932=012610`, and reached the idle loop
`017552`. The original parent descriptor at physical `045703`
changes from `045761400001` (resident parent), through
`045761600001` (real TRANSITION finalizer), to **zero**.

The original MM extent count decreases from **18 to 16**. An exact
whole-table comparison proves that the ONLY released extents are:

- Parent u-area `045761..046371` (MM KERNEL_DYNAMIC, owner `01001`)
- Parent PROCESS `130000..140000` (owner slot1)

Every other MM extent remains untouched, including the authoritative
slot3 PACKED RAW source `111200..120000` and the foreign owner2
PROCESS target `120000..130000`, both pin0. The original child
metadata `047017600401` becomes `047017600001`, proving genuine
parent1 -> orphan0 adoption, with TRANSITION still set and VMbase0.
Original private CTX_PC `340000016704`, FDCTL `000000004010` and
u[067] escrow `040000120000` remain byte-identical throughout.

An actual subsequent original PCLK/PI6 at `017225` has the native
saved word `340000017562` (interrupted slot0 idle-loop PC `017562`).
MM16, ROOT, the quarantined child and its complete saved continuation
remain preserved through that interrupt. The simulator is then
**operator-stopped**: no false guest EXIT/HALT is claimed for the
foreign-owned child.

The source-backed physical verifier checks all of the above and
rejects unrelated MM mutation. Exactly THREE additional unsafe
physical transcript mutants reject: parent finalizer not on slot0,
child TRANSITION cleared by orphan adoption, and lost escrow after
parent EXIT. Earlier full ownership/TERM/PI6 matrices are not
repeated with unchanged production code.

## Reproducing

From `daimos-testkit`, with installed original PDP-6 simulator:

    export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    make test-pure-k05-parent-exit-build-v1910
    export V1910_BUILD=<source-build-output>/build
    export V1910_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1910_WORK=$TMPDIR/daimos-k05-parent-exit-v1910-physical-v3
    make test-pure-k05-parent-exit-physical-v1910
    make test-pure-k05-parent-exit-audit-v1910

An interrupted test build can finish producing KCORE/PURE without
finishing the v1638 `/SYSTEM/COMP` TSFS hook. The run script now
REQUIRES the actual compressed manifest, all three original generated
members, byte-identical copies in the boot directory, and `tsfscheck`
PASS before running; it never substitutes an uncompressed medium.
Initial discarded attempts used a console port above 65535, then an
unfinished TSFS image (real guest `!3` file-open failure). Those
invalid simulator traces are NOT v1910 acceptance evidence.

Accepted source-built hashes:

- KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`
- Test-only parent user DXR `6204b31ec342a1fd406f64952ba74bbe4af442837d7ff587d13fef3e997d7338`
- Normalized physical trace `262998e8a03dcad8b96247dd6761661cd5a8668226e0dd6db6332ea94bc10a70`
- Source-linked simulator script `acabe722deae57bf91fc033bf1b0bfa9a65afdbc5001372c597c99d45f735852`

Accepted evidence: `$TMPDIR/daimos-k05-parent-exit-v1910-physical-v3/`.
No production C/ASM, fixed BSS or default policy changed.
K05 remains OPEN for permanent unknown-owner terminal cleanup;
RAW PURE and mode3 stay default OFF.

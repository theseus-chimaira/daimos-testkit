# K05 v1911: the unrepaired foreign FULL owner as last live user

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS.**

## Question and scope

Does native EXIT of every other user, including the former INIT
parent, falsely HALT the original PDP-6 while slot3 still has an
unresolved foreign-claimed FULL target and a live executive stack?

Reuse the exact v1910 source-built 48K five-child compressed TSFS
guest and unchanged fixed-KCORE/optional PURE binaries. The original
real PACKED source `mm_free` returns -5. Only the temporary PROCESS
target's MM owner is changed by the test controller (owner3 ->
foreign owner2), while base `120000`, size `010000`, type PROCESS,
and pin0 remain unchanged. The real parent TERM(3) refuses (`TR`).
Original user parent EXIT runs through `proc_exit_current=013655`
and slot0 finalizer `012610`, freeing exactly the parent's two MM
extents and reparenting all child identities to parent0 (v1910).

v1911 **continues execution** after v1910's real post-parent PI6
checkpoint rather than stopping. Three DISTINCT original native
`proc_exit_current` breakpoints show `proc_current_slot=4`, then
`5`, then `6`. Each is followed by a separate actual original
`proc_idle_loop=017552` breakpoint. Thus the test verifies the
previous EXIT finalizer completed before it rearms a breakpoint
for another child; it does not count repeated stops at one PC.

After the third original child finalizer:

- Original slots 1,2,4,5,6 are FREE; only quarantined slot3 is live
- `proc_high_slot=4`, `proc_current_slot=0` (permanent slot0 idle)
- Actual MM count declines **16 -> 10**, deleting exactly the three
  departing siblings' KERNEL_DYNAMIC uareas `047427..050037`,
  `050037..050447`, `050447..051057` (owners `01004..01006`),
  and their PACKED RAW suffixes `061200..070000` owner6,
  `071200..100000` owner5, `101200..110000` owner4
- There is no unrelated MM deletion, insertion, or owner rewrite
- Slot3 remains `047017600001`: orphan-parent0,
  TRANSITION retained, VMbase0; original saved executive
  CTX_PC `340000016704`, FDCTL `000000004010`, and
  uarea word067 escrow `040000120000` are unchanged
- Authoritative RAW `111200..120000` owner3 and foreign full
  PROCESS target `120000..130000` owner2 remain live pin0

Three actual original `proc_finish_service_v881=013065` slot0
retry entries each follow their own completed idle-loop return.
The shared original retry delay is capped at `01000` octal
(512 decimal) ticks. Original clock values at those entries
are `020046`, `021046`, `022046` octal: exactly `01000` ticks
between each. No child memory, context, ownership or ROOT changes
across retries. An additional REAL original PCLK/PI6 enters
`proc_sched_pi_tick=017225`, saves `pdp10_pi_level6=340000017617`
(interrupted idle-loop PC `017617`) and still preserves the exact
MM10/slot3 state. **SIMH operator EXIT** ends the observation;
there is no native guest HALT or artificial successful cleanup.

The source-linked read-only physical verifier checks all original
KCORE breakpoint counts, native parent+child EXIT events, complete
MM owner sets, exact six sibling releases, last-user process table,
context/escrow, real 512-tick intervals, and PI6 return location.
Three independent unsafe physical trace mutations reject:
false still-live slot4 at last-user idle, missing retry pending,
and lost exact target escrow after the last PI6. Earlier v1910
positive/negative cases are not redundantly rebuilt or retested
with identical production binaries.

## Corrected SIMH breakpoint sequencing

The first experimental controller v1911/v1 was **NOT accepted**:
rearming `break proc_exit_current` while PC was still at that same
instruction produced three monitor stops with the identical
current slot4, clock, and MM; only the first EXIT was real.
The corrected v1911/v2 interleaves the source-linked original
idle-loop breakpoint between child EXIT entries, and again between
idle retry entries. All three distinct children then complete,
and all three timer-governed retries have real PCLK separation.
This was a simulator test-harness error, not a DAIMOS bug.

## Reproduction

The source-built v1910 compressed guest and original PURE probe
are prerequisites. No additional user or kernel compilation is
required; this test only changes the private physical controller.

    cd $HOME/git/daimos-testkit
    export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1911_BUILD=$TMPDIR/pure-brk-pressure-v1614.syLB4i/build
    export V1911_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1911_WORK=$TMPDIR/daimos-k05-last-orphan-v1911-physical-v2
    make test-pure-k05-last-orphan-physical-v1911
    make test-pure-k05-last-orphan-audit-v1911

The source build can be regenerated with
`make test-pure-k05-parent-exit-build-v1910`; its output BUILD
directory and the original v1906 probe must then be supplied
as `V1911_BUILD` and `V1911_PROBE`. Media integrity checks
require genuine completed 54-file TSFS compressed boot members.

Accepted SHA256:

- KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- Optional PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`
- Normalized physical transcript `2863df28f5712639a8c42ecce7c6b6566cd9328f06cbbee7809f2642dd60ff9c`
- Physical simulator script `58fdb78e540ce849d92193a0930400ac7f28f970325277bb6d8806f68741c9d7`

**No production C/ASM, IMAGE, BSS, RAM or default feature policy changes.**
K05 remains OPEN for permanently unknown-owner terminal policy,
other MM/PI6 orderings, and broader platform acceptance. This
physical observation covers three real delayed retries, NOT
arbitrary infinite time. RAW PURE and mode3 remain default OFF.

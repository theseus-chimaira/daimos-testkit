# K05 v1903: physical FULL retry commit and normal five-child EXIT/WAIT

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS.** The
previously accepted v1902 dual-owner rollback now proceeds through a
second genuine native PACKED source free, original FULL RESIDENT
publication, five original child EXIT results, typed parent WAIT,
user-mode `Z` and real PDP-6 HALT. No production DAIMOS code changed.
K05-K09 are still OPEN. RAW PURE and mode3 remain OFF by default.

## Test-only control

The versioned source builder reuses the actual v1901 five-child parent
and its live secondary compressed TSFS source, PIPE, BRK and sentinel
checks. One parent USER-APR conditional breaks out of the resident
heartbeat loop only after a simulator-controlled USER gate is set.
It then executes the original five `dsys_wait` calls and validates
the original typed exit values. No kernel, saved context, MM extent,
FINALIZE state or native return value is forged by the gate.

The physical controller uses the real source-built current KCORE and
PURE MRES linker maps and the compiled native `mm_free` relocation.
SIMH `nobreak` without an address DOES NOT clear old breakpoints:
v1903 correctly uses explicit `nobreak all` at all ten checkpoint
transitions. The first experimental trace was rejected because the
old source-free CALL breakpoint was mislabeled as the next return.

The newly installed compiler also changes the linked fixed KCORE
size by two words and transient KINIT placement. The actual installed
PURE base is `032453` rather than v1902's `032435`; runtime proc_table
is `045534`, and slot3 u-area is `046653`. All predicted physical
addresses are checked against actual independent MM/process evidence.
The KCORE/PURE SHA256 differs from the older v1902 source-built image
without a production source change; this is NOT a demonstrated
compiler or assembler correctness defect.

## Accepted original physical trace

- Current KCORE SHA256:
  `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- Optional PURE MRES SHA256:
  `55be5113d4d15fe5c4a44409dca22afd463c75f05f661b3f8f71451a057c577f`
- Original physical trace SHA256:
  `03a3763c12f1da7a8dc6297e8857639d46f64ed63fe5517ec7f2dc16552e3796`
- KCORE image `024167` octal words, BSS `000415`;
  PURE image `004615`. No permanent per-process state added.
- Real first source `mm_free(PACKED)` returns -5 at `036031` after
  the external test-only source pin; slot3 retains both exact owners.
- After release of that pin, original slot-0 native target
  `mm_free(PROCESS)` at `033263` returns 0 at `033264`.
  Real MM count falls 18 -> 17; original TRANSITION clears.
- The new original FULL transaction allocates a new temporary
  PROCESS target (MM 17 -> 18). The second original source
  `mm_free(PACKED)` at `036031` now returns 0: MM 18 -> 17;
  sole PROCESS target is unpinned at `120000..130000`.
- Original FULL service return `033574` has slot3 RESIDENT,
  `VMbase=120000` and TRANSITION clear. The parent USER gate at
  `135335` is zero through this stage and set only afterward.
- Original output contains exactly five `w` child exits and parent
  `Z`, with the original source verifying all five typed WAIT results.
  Real hardware HALT occurs at PC `000000`.
- Final original MM count: 8 at parent Z, 6 after HALT;
  no slot3 PROCESS/PACKED owner, selected TSFS ROOT unchanged.

The read-only verifier checks the actual original MM extent lists,
owner pins, source/target geometry, current slot, root, process table,
stable u-area, saved executive CTX_PC/FDCTL, native MM returns,
RESIDENT publication and parent gate timing. Ten independently
corrupted real physical transcript controls all reject, covering
false native replies, stuck RAW owner, premature TRANSITION/gate,
missing APR, changed saved PC and missing WAIT/HALT.

## Reproduce

Run from `daimos-testkit` with `DAIMOS_REPO=$HOME/git/DAIMOS`,
`PDP10_PREFIX=$HOME/cross` and `TMPDIR=${TMPDIR:-$HOME/tmp}`:

    sh tests/validation/pure-k05-full-commit-v1903/build-source-v1903.sh

Set `V1903_BUILD` to the versioned `pure-brk-pressure-v1614.*/build`
path printed by the build. Use the original source-linked MRES base
probe, then run the full physical and read-only negative audit:

    V1845_BUILD=$V1903_BUILD \
      V1845_WORK=$TMPDIR/daimos-k05-full-commit-v1903-probe \
      sh tests/validation/pure-k05-secondary-physical-v1845/probe-v1845.sh
    V1903_PROBE=$TMPDIR/daimos-k05-full-commit-v1903-probe/probe.clean \
      V1903_PHYSICAL_WORK=$TMPDIR/daimos-k05-full-commit-v1903-physical \
      make test-pure-k05-full-commit-physical-v1903
    V1903_PHYSICAL_WORK=$TMPDIR/daimos-k05-full-commit-v1903-physical \
      make test-pure-k05-full-commit-audit-v1903

Accepted local evidence:
`$TMPDIR/daimos-k05-full-commit-v1903-physical-v3/`.
The first experimental trace and stopped v2 geometry check are NOT
acceptance artifacts. Final acceptance requires the actual v3 trace
and all ten source-linked negative controls.

**Still OPEN:** permanently unavailable or foreign MM owners,
unknown allocator/unpin results, terminal failed-FULL cleanup,
other physical PI6 interleavings, K06-K09 and mode3.

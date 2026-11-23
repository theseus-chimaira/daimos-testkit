# K05 v1890: real PDP-6 full-system MM overpin injection

Date: 2026-11-23. This independent 48K physical validation targets
v1855's original source-linked PURE FULL commit. Keep all temporary
SIMH MM changes in PRIVATE testkit media, never production C/ASM.

## Goal and setup

The source-built 48K opt-in RAW PURE image and original five-child
RUN/PIPE/WAIT guest from v1855 have a byte-identical fixed KCORE to
v1848. `prepare-v1845.py` obtains the actual *installed* PURE MRES
base by physically examining KCORE's reclaim JRST, and derives the
original FULL loader and service return from current MRES linked
symbols and instructions. The previous actually executed v1848
FULL_PINNED MM descriptor table is used solely to select the
corresponding original target metadata address; this run re-reads
the physical target pin at the genuine FULL breakpoint, rather than
assuming the previous witness is the new runtime state.

At that original FULL loader entry, slot 3 must hold a singly pinned
PACKED RAW suffix `111200..120000` and a separate singly pinned
PROCESS destination `120000..130000` (all addresses octal). The
test-only SIMH debugger increments **only** the destination's actual
physical MM pin count from 1 to 2 by depositing the original MM
metadata word while the guest is stopped. It immediately re-examines
the same original word. DTC3 stays attached: the loader must return
success but the new exact-owner commit guard must reject the
overpinned target with `MM_ERR_BUSY` (-5) at its original service
return. The test verifies both original MM owners are still retained,
the source remains pinned 1, target remains pinned 2, and all
unrelated MM extents and selected ROOT stay unchanged.

The controller then continues the actual CPU until the first real
PCLK `proc_sched_pi_tick` entry, and checks that the held MM owner
state remains unchanged. It deliberately exits SIMH at that
breakpoint; a quarantined slot must NOT be counted as a completed
child or whole-machine HALT. Subsequent user-child EXIT/WAIT
progress is a distinct acceptance claim which requires its own
source-backed physical witnesses.

## Reproduction

Run from the daimos-testkit checkout with the unmodified 48K v1855
image and current-source original runtime base probe:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export V1890_BUILD=$TMPDIR/pure-brk-pressure-v1614.qnobNT/build
    export V1890_PROBE=$TMPDIR/daimos-k05-pin-probe-v1890/probe.clean
    export V1890_PRIOR=$TMPDIR/daimos-k05-pi6-midfull-v1848-physical
    export V1890_WORK=$TMPDIR/daimos-k05-physical-overpin-v1890-real
    make test-pure-k05-physical-overpin-v1890

To re-audit the unchanged completed original physical transcript:

    make test-pure-k05-physical-overpin-audit-v1890

The source-linked physical verifier rejects fake predeposit metadata,
a missing actual second pin, a missing retained source pin after the
FULL service return and a lost target pin at the later real PCLK.
These independent negative transcripts are constructed and actually
executed against the identical verifier, never used as evidence of
a changed physical kernel.

## Boundaries

This test intentionally differs from the older v1845 DTC3 read-loss
case: the device remains physically mounted and the actual FULL
payload completes. It differs from v1848: the new physical fault is
in the MM target pin count, not the physical source. It differs from
v1855's native fixtures: the original full-system KCORE and MM table
are stopped and changed in an actual SIMH PDP-6 physical memory word.

The debugger deposit itself is externally injected corruption, not
proof that normal code spontaneously creates a second pin; its
purpose is testing the production exact-owner rejection and
quarantine policy. It is not a completed full-system user-level
bystander scheduling test or a permission to enable PURE.

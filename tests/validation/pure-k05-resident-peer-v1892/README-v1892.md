# K05 v1892: resident parent makes original user-mode progress after pin2 FULL

Date: 2026-11-23. Physical K05 target: prove *postfault user-mode*
progress without requiring another aligned full PROCESS APR from a
memory arena whose untrusted pinned source/target pair is quarantined.

## Fixture and unchanged production contract

The existing original 48K PDP-6 physical v1845/v1855 five-child
TSFS-root, secondary DTC3 compressed executable, BRK/PIPE pressure
guest is transformed only in the TESTKIT's INIT user source.
`prepare-source-v1892.py` rebuilds the same exact v1643/v1845
five-child source used in the accepted physical v1891 image and
appends a small parent-only loop **after** the existing `L`
pressure/BRK/PIPE and `dsys_close(wr)` checkpoint:

* `dsys_sleep(0100)` on the parent already-resident user APR;
* independently validate the two original writable-data sentinels;
* print `HB` through two real `dsys_writechar` syscalls;
* repeat, without waiting for a potentially irrecoverably
  TRANSITION-held child. No special user/kernel SYS call is added.

The five original child images still execute their unmodified
argc-gated read/check/`w`/EXIT branch. All original RUN admission,
failed sixth RUN, BRK pressure, source-root, DTC3 and fallback
compressed-source setup is unchanged. This intentionally changes
the *test-only parent* from blocked WAIT to an autonomous resident
user loop, so the physical run is **not** an all-child WAIT/HALT
acceptance.

The same source-built full PDP-6 KCORE and removable PURE MRES must
remain **byte-identical** to the previous accepted v1890/v1891
images. Native `make` build-only selection
`PURE_PREPARE_ONLY_V1892=1` is testkit-only, used to prepare the
complete physical boot and media without running the old HALT
verifier on a deliberately nonterminating heartbeat parent.
All original diagnostic behavior without that explicit opt-in
continues unchanged.

## Actual physical source-linked procedure

The v1892 physical test builds on the source-linked original
v1890/v1891 independent oracles. The private SIMH runtime first
examines the newly installed KCORE reclaim JRST to derive the
physical PURE base and original FULL entry/return. It requires the
actual once-pinned authoritative PACKED source and separately
once-pinned PROCESS target at loader entry, then deposits a second
physical target MM pin **only** in the test simulator. The original
loader must complete with source DTC3 still connected, and the
original FULL commit must reject the overpinned target with -5.
The entire MM table and root must survive a later real KCORE PCLK
PI6; the original process table must keep the quarantined slot3
TRANSITION flag and VM base zero.

Only **after** that physically verified failure and process-table
checkpoint does SIMH arm `expect "HB"` and resume the guest.
This expectation is reset after the first independently emitted
heartbeat and required to fire **again** after further original
guest PCLK ticks. Both checkpoints snapshot actual original MM
reservations and slot3's TRANSITION bit; the source and destination
pins must remain 1 and 2, respectively. The parent retains an
actual nonzero VM base in both states. A marker produced before
the -5 fault does not count, since no expectation is armed yet.

## Reproduction

From the daimos-testkit checkout:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=$HOME/git/DAIMOS
    export V1892_SOURCE_DIR=$TMPDIR/daimos-k05-resident-peer-source-v1892
    make test-pure-k05-resident-peer-build-v1892

The complete source-built boot directory is printed by the builder;
with the shown versioned scratch paths:

    export V1892_BUILD=$TMPDIR/pure-brk-pressure-v1614.UQzCQO/build
    export V1845_BUILD=$V1892_BUILD
    export V1845_WORK=$TMPDIR/daimos-k05-resident-peer-probe-v1892
    sh tests/validation/pure-k05-secondary-physical-v1845/probe-v1845.sh
    export V1892_PROBE=$V1845_WORK/probe.clean
    export V1892_PRIOR=$TMPDIR/daimos-k05-pi6-midfull-v1848-physical
    export V1892_V1890=$TMPDIR/daimos-k05-physical-overpin-v1890-real/physical.clean
    export V1892_WORK=$TMPDIR/daimos-k05-resident-peer-v1892-real
    make test-pure-k05-resident-peer-physical-v1892
    make test-pure-k05-resident-peer-audit-v1892

The independent read-only audit compares the complete original
SIMH raw transcript with its normalization, reruns all source-linked
physical invariants, and executes six separately corrupted
physical transcript variants. Each must fail at a precise user
heartbeat/MM/process/clock witness. The physical `proc_current_slot`
must specifically identify the independent resident parent at **1**
on both heartbeat events; the original unswapped PROCESS reservation
`130000..140000` must remain in the actual MM extent table.
Do not count compile-only
mutants or forged transcripts as physical execution.

## Boundary

This establishes autonomously scheduled resident **parent user**
progress after a corrupt pin quarantines a separate child. It
does not prove that a second sleeping PACKED child can restore
under the original 48K pin pressure, nor postfault child WAIT/HALT,
recovery from an irreparable pin, terminal cleanup, other persistent
allocator/free failure variants, KA10 or production PURE release.
K05-K09 remain OPEN, RAW PURE/mode3 OFF by default.

## Accepted real physical v1892 evidence

The corrected source-built simulator and independent six-mutant audit
PASS. The original KCORE and PURE MRES are byte-identical to v1855.
Only the test-only user INIT DXR changed (SHA256
`620fcfaddedd5a4abea8b35e11a99e371fa624420ce479a4e4de69fb92c24e27`).
The user INIT text shrinks `001246` to `001222` octal words while
the BSS stays `004001`, but no already-resident parent APR changes
size (`010000` octal), and this is NOT production RAM saving.

At both newly emitted postfault `HB` events the actual physical
`proc_current_slot` is **1**, parent `PROC_SRUN=2`, parent physical
VM base **`130000` octal**, and its MM PROCESS descriptor remains
`130000..140000` pin0. The quarantined slot3 source `111200..120000`
retains pin1; the provisional target `120000..130000` retains pin2;
slot3's TRANSITION bit is still set and its VM base remains zero.
Original clock advances `021610` to `021710` octal between the
two new `HB` marks. All original other MM extents and root remain
unchanged. The actual source-linked complete physical trace SHA256:
`7fbc1e9fa203c2c146861d0f951e222f22721f221e3f095c300b23d96ca72f86`.
The evidence directory is the versioned
`$TMPDIR/daimos-k05-resident-peer-v1892-physical-v2/`.

The initial v1892 SIMH run was *correctly rejected* by the heartbeat
oracle because it still had the old PCLK breakpoint armed; the two
false stops were on the clock handler, not new `HB`. Only the
test controller was corrected with a `nobreak` before user-output
expectations; the second untouched physical kernel and user image
passed. Six separately run negative controls reject missing actual
user progress, nonresident parent, forged user slot, lost quarantine,
released authoritative RAW, and no PCLK advancement.

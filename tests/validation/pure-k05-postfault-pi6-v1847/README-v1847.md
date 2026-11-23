# K05 v1847: original physical PI6 after failed FULL restoration

Scope: source-linked 48K PDP-6 KCORE PCLK interrupt boundary after a
real failed FULL source restore, with a retained RAW PACKED owner. This
is a testkit-only extension of the accepted v1845 secondary DTC3
backing-loss/return test. No production kernel, PI6, PURE, MM or VFS
source is modified.

## Test source and deterministic breakpoints

The physical test reuses the exact v1845 source-built five-child guest,
TSFS ROOT and DTC3 private media, original user `w` canaries and
RUN/PIPE/EXIT/WAIT workload. It requires the previous v1845 physical
`probe.clean` evidence to authenticate the actual installed PURE MRES
base before its first FULL callback. The initial loader and return
breakpoints are derived from current physical JRST plus the real DXR
source, just as in v1845; no old fixed PURE code offsets are trusted.

After the first genuine FULL read failure (DTC3 detached), the test
captures original MM owner/pin state with no child APR runnable and
the failed target freed. Instead of instantly returning DTC3, it
breaks at the ORIGINAL fixed KCORE `proc_sched_pi_tick` function and
reads the actual KCORE instruction, clock epoch, existing cooldown,
scheduler cursor and original full MM descriptor table. It must show
that the PI6 entry occurred before DTC3 reattachment with the SAME
unpinned original PACKED owner. Only then does the original private
reel return, allowing all remaining children to resume, EXIT and WAIT.

The expected installed PI6 instruction must be derived from the
original `proc_pdp6.s` first `aos 1,proc_timer_clock` and the
source-linked fixed-KCORE `proc_timer_clock` symbol. The raw KCORE DXR
IMAGE index is a **KINIT packaging index**, not necessarily the
final installed physical KCORE address; an initial oracle accidentally
used that DXR index. The observed original physical `AOS` is the
correct witness and the oracle must independently match its encoding.

The verifier first runs the complete unchanged accepted v1845
source-linked physical auditor, then requires the exact source-linked
fixed-KCORE PI6 entry and physical MM state equality. Two independently
corrupted physical transcripts must be rejected at their intended
oracles: modified PI6 instruction, and a forged live PACKED pin.

Build and boot the v1845 baseline as described in its README, then:

    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=$HOME/git/DAIMOS
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1847_BUILD=/absolute/path/to/v1845/physical/build
    export V1847_PROBE=/absolute/path/to/v1845/probe.clean
    make test-pure-k05-postfault-pi6-v1847

The saved `V1847_WORK` physical output can be audited without rerunning
the expensive original guest:

    make test-pure-k05-postfault-pi6-audit-v1847

## Rejected earlier diagnostic

An initial disposable v1847 experiment retained detached DTC3 until
a second apparent FULL loader breakpoint was observed. It was not a
valid second FULL call: its AC2 target was **zero**, AC4 capacity was
**zero**, and the physical MM table had no pinned full target. The
simulator also stopped before completed reattachment/WAIT because a
host timeout termination was sent while the late breakpoint appeared.
The original diagnostic remains outside the repository under the
versioned `$TMPDIR/daimos-k05-repeat-v1847-real` evidence directory.
Neither that trace nor its moving-MRES breakpoint may be counted as a
real second FULL restore, a kernel regression, or production acceptance.

The underlying retry idea may still be valid, but requires tracking
MRES relocation (and possible PREFIX routing) at each candidate
breakpoint, not assuming its physical address is permanent.

## Limits

This tests one genuine physical KCORE PI6 entry **after** a FULL
failure, not an interrupt **inside** the pinned MM/FULL transaction.
It does not establish unrestricted interrupt timing, multi-owner
terminal uncertainty, permanent MM pin failure, continuous write-watch
high-water or K05 closure. PURE stays disabled by default.

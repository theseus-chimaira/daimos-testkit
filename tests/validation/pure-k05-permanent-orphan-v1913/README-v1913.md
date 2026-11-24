# K05 v1913: unrepaired last orphan, sustained original idle quarantine

Date: 2026-11-24. **Scoped 48K PDP-6 physical PASS.**

## Question

v1912 demonstrated genuine native final-user EXIT/HALT AFTER an
authoritative MM-owner correction. This test examines the opposite
terminal state: if that correction NEVER arrives during the test,
does the original kernel preserve the still-live unrecoverable
foreign-owned child, rather than prematurely FREE it or HALT?

The correct conservative runtime policy is **fail closed**:
the quarantined child is still a live user, owns a retained RAW
source and a private executive continuation, and must NOT be
destroyed unless MM ownership is authoritatively reconciled.
This is not a recoverable/process-disposable zombie state.

## Source-built original PDP-6 experiment

Reuse unchanged v1910 48K five-child source-built compressed
TSFS guest, original fixed KCORE and optional PURE binaries.
The test-only controller derives the exact accepted v1911
physical script. The original PACKED source `mm_free` genuinely
returns -5, the original full PROCESS target is intentionally
retagged to foreign owner2, the parent TERM is genuinely
refused and the parent and original healthy children 4,5,6
really EXIT. Only child3 remains live under TRANSITION, with
no runnable users and with its saved executive stack intact.
Its original physical MM10 table is compared by the full
v1911 source-linked positive oracle before the extension.

**No subsequent MM deposits or owner repair are performed.**
After the three capped v1911 recovery retries and two genuine
prior PCLK PI6 events, v1913 invokes another TWELVE *real*
`proc_finish_service_v881=013065` checkpoints. Each retry
is separated by a distinct native `proc_idle_loop=017552`
completion. A repeated SIMH stop at one unexecuted instruction
cannot count as another retry. Two more genuine PCLK PI6
interrupts enter fixed KCORE at `017225` after the sixth and
twelfth extra retries.

The v1913 extra native retry clock range is `027342` ->
`042342` octal, with every adjacent retry separated by
**exactly `01000` octal ticks (512 decimal)**, including the
interval from original v1911 retry3 to v1913 retry1. The
original shared pending/backoff word has its pending bit set
and delay locked at `01000` throughout. The two additional
real hardware-saved PCLK PI6 words are `340000017553`
and `340000017564`: both return into the original slot0
idle instruction range, not any user APR.

All captured MM10 tables stay EXACT, with no release,
insertion, owner rewrite or unexpected pin: original RAW
`111200..120000` owner3 pin0, foreign full temporary PROCESS
target `120000..130000` owner2 pin0 at compacted metadata
address `024707`, retained private executive CTX_PC
`340000016704`, FDCTL `000000004010`, and existing
uarea word067 escrow `040000120000`. The original ROOT,
slot3 process descriptor `047017600001`, VMbase0,
`proc_high_slot=4`, current slot0, and all other user slots
FREE remain unchanged. No target free or terminal FINALIZE
occurs, and **no guest HALT** is executed. The operator ends
the simulator after the final physical PI6 observation.

Combined with v1911 this proves **15 separate capped retries**
under the same still-live last-orphan failure. It does NOT
prove arbitrary infinite uptime, every tick-counter wrap,
automatic permanent-owner recovery, or a native HALT with
an irreconcilable original private executive continuation.

## Source policy audit

Original `proc_finish_service_v881` preserves the shared
pending bit on failed owners and returns success/last-user
only after a real completion. Original `proc_has_live_user`
counts the still-live TRANSITION process. Original idle loop
calls `proc_exit_halt` only after service reports the actual
last user has been fully released. The test asserts the source
fragments and verifies original physical code execution, not
only inferred simulator elapsed time. No new fixed resident
retry table or per-process field is necessary.

FOUR independently executed unsafe transcript mutations all
reject: falsely reowned target, prematurely cleared transition,
lost private target escrow and falsified PCLK retry cadence.

## Reproduce

    cd $HOME/git/daimos-testkit
    export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1913_BUILD=$TMPDIR/pure-brk-pressure-v1614.syLB4i/build
    export V1913_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1913_WORK=$TMPDIR/daimos-k05-permanent-orphan-v1913-physical-v1
    make test-pure-k05-permanent-orphan-physical-v1913
    make test-pure-k05-permanent-orphan-audit-v1913

The original guest can be recompiled using the v1910
`test-pure-k05-parent-exit-build-v1910` target, preserving
its actual source-built paths; supply the source-matched
original PURE probe. The v1913 runner validates completed
54-file compressed TSFS members before PDP-6 execution.

Accepted SHA256:

- Normalized physical trace `88867609a4329cd0a352f9681a3c59e34afe24b557ed20c3354d84918a0b7529`
- Source-linked physical script `677886f622428b6f579a09391cd8219a8a0fc29e0c2f32b49dae824fd4bb7486`
- Original fixed KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- Original optional PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`

Evidence: `$TMPDIR/daimos-k05-permanent-orphan-v1913-physical-v1/`.
No production code, RAM, IMAGE, BSS or default changes.

**K05 remains OPEN** for genuinely unresolvable ownership
policy outside the finite physical window, further allocator
and PI6 interleavings and wider platform acceptance. Under
uncertainty do not invent MM rights or forcibly discard a
live saved executive continuation. K06-K09 OPEN, RAW PURE
and mode3 remain default OFF.

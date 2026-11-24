# K05 v1904: original slot-0 rollback with externally pinned PROCESS target

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS.** This source-linked test
of the v1902 deferred RAW FULL recovery, extending v1903's successful
FULL commit and five-child typed WAIT/HALT acceptance. It reuses the
exact unchanged v1903 KCORE, PURE MRES, compressed TSFS media, and
test-only five-child parent. No production source or RAM is changed.

## Failure and recovery under test

The initial original FULL source `mm_free(PACKED)` returns native -5
after one external source pin. The real KCORE/PURE preserves both
owners and the private executive continuation with TRANSITION held.
While stopped at the original source pin release checkpoint, the
controller adds one external pin to the **complete slot-3 PROCESS
target**, not the source or the unrelated resident parent. The
current source-built MM table has two words per extent:

* authoritative PACKED RAW metadata at `024723` (owner 3, type 4);
* provisional full PROCESS target metadata at `024725` (owner 3,
  type 1), initially `000001000003`, pin1 `000011000003`;
* independent resident parent metadata at `024727` (owner 1, type 1).

The original slot-0 PURE recovery mechanism must fail closed while
the target remains pinned; it may not invoke native
`mm_free(PROCESS)`, clear TRANSITION, free the source, or publish
the uncommitted PROCESS APR. Three independent resident parent
user heartbeat/PCLK checkpoints must conserve the exact two
physical owners and saved private executive context while the
shared retry epoch/delay remains pending.

The controller then releases only the external target pin.
The original slot-0 retry must eventually remove that temporary
PROCESS target using its genuine MM `mm_free`, clear TRANSITION
only after rescanning the sole unpinned PACKED source, then restore
the child through original FULL and permit all five children
to exit through their original typed WAIT path and parent Z/HALT.
No original kernel state, native return value, FINALIZE marker,
saved CPU context or extra owner is deposited or forged.

The controller uses the exact current original linked MM/process-table
layout rather than the stale v1902 absolute addresses.

## Accepted actual original 48K physical result

The corrected pin was installed at physical `024725`. All THREE
independently observed parent user heartbeats retained MM count 18,
the authoritative RAW `111200..120000` pin0 and provisional full
PROCESS `120000..130000` pin1, slot3 TRANSITION/VMbase0, saved
executive CTX_PC/FDCTL and unchanged TSFS ROOT. Resident parent
slot1 continued running and the real clock advanced `025256`,
`025356`, `025456` octal. No target `mm_free(PROCESS)` was executed
during the pinned interval.

The **original** shared KCORE backoff word at `024532` stayed armed
with retry intervals `0100`, `0200`, `0200` octal through all three
heartbeats. This proves actual timer preservation/advancement, not
an observed native C return code during the pinned interval.

Following release of the ONE external target pin, original native
slot0 `mm_free(PROCESS)` returned MM_OK=0 after `000060` octal
hardware ticks. It deleted only the temporary target and cleared
TRANSITION after sole unpinned RAW ownership was established.
The next original FULL then committed and published slot3 RESIDENT
at `120000`. All five original child EXIT/typed WAIT results,
parent `Z` and actual HALT PC0 PASS; MM count is 8 at Z, 6 at
HALT with no residual slot3 PROCESS/PACKED extent.

Twelve independently corrupted actual physical transcripts all
reject, including wrong-parent-owner pinning, dropped source,
premature target free, altered saved CTX_PC, spurious RESIDENT,
early parent WAIT and lost retry timer/PCLK continuity.

- KCORE SHA256:
  `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- PURE MRES SHA256:
  `55be5113d4d15fe5c4a44409dca22afd463c75f05f661b3f8f71451a057c577f`
- Accepted original physical transcript SHA256:
  `f912b6cae1c470a876a404cd2e49af708b727f9bb423fbc2eaefe1d0777f16de`
- Accepted local physical trace:
  `$TMPDIR/daimos-k05-target-pin-v1904-physical-v4/`

## Reproduction

Use the *same* original source-built v1903 48K guest and installed
PURE-base probe from the accepted `pure-k05-full-commit-v1903`
test. From `daimos-testkit`:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
    export V1904_BUILD=$TMPDIR/pure-brk-pressure-v1614.os1IQT/build
    export V1904_PROBE=$TMPDIR/daimos-k05-full-commit-v1903-probe/probe.clean
    export V1904_PHYSICAL_WORK=$TMPDIR/daimos-k05-target-pin-v1904-physical
    make test-pure-k05-target-pin-physical-v1904
    make test-pure-k05-target-pin-audit-v1904

The first two exploratory runs are **rejected**: they accidentally
pinned the parent MM descriptor (`source_meta+4`) instead of the
target (`source_meta+2`). A later attempted source-derived service
return breakpoint did not reach its expected PC despite 100+ parent
heartbeats, and was NOT accepted as evidence of native refusal.
The independent original timer-word diagnostic subsequently proved
the actual intended target pinned, MM18/TRANSITION conserved,
parent PCLK advancing and the same original shared retry timer
armed with backoff `0100` then `0200` octal. Acceptance must
use the exact physical MM and retry witnesses rather than a
speculative folded-code breakpoint.
The separate timer diagnostic is supporting evidence only; it is
NOT the acceptance trace. The final corrected v4 physical run
passes both the strict v1903 full-lifecycle oracle and all twelve
new independently executed v1904 negative controls.

**Scope:** The accepted v1904 run proves bounded fail-closed
preservation across a prolonged *external target pin* and subsequent
safe release; it does not establish cleanup of a forever-pinned
extent, fabricated foreign MM owner, arbitrary allocator failure,
all PI6 interleavings, K05 closure, or RAW PURE production enablement.

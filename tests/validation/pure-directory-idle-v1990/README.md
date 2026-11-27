# v1990 directory FULL idle rollback

    make test-pure-directory-idle-v1990 DAIMOS_REPO=/path/to/DAIMOS
    PURE_TEST_COMPILER_V1984=gcc make test-pure-directory-idle-v1990 DAIMOS_REPO=/path/to/DAIMOS
    make test-pure-directory-idle-package-v1990 DAIMOS_REPO=/path/to/DAIMOS

The native test links actual v1989 placed bitmap FULL/rollback,
actual MM/codec/bounded loader, complete v1990 PURE service,
original RAW PREFIX, and original idle deadline, armer, scan and
backoff instructions. The service gateway is a JRST to a counted
native service call; the outer idle loop/interrupt handoff and
terminal/discard callbacks are controlled fixtures. No physical
interrupt timing, installed-image replay or actual terminal fault
is claimed by this test.

Each PDP6/KA10 and GCC/KCC: 82 FULL attempts and 80 explicit
rollback calls from v1989 plus 127 actual service/deadline calls.
The host original escrow helpers also pass 16,777,216 round trips
with the v1990 retry-bit convention. Known-pin target-unpin,
target-free and source-unpin failures arm the shared 16-tick clock;
due checks reject one tick early, wrap correctly at the 17-bit
epoch, double delay to the existing 512-tick cap and retain it.
Recovery without backing mount preserves the inactive bitmap and
the original heap, retires only the provisional owner and known
pins, clears pending state when the last retry succeeds. No READY,
no changed scheduler cursor, no new loader/alloc/pin. Subsequent
normal FULL can restore and publish READY. HOLD cannot arm or
participate in an unrelated pending scan. Changed MM geometry
revokes authority; next scan skips HOLD even after metadata repair.
Malformed command/nonzero current slot refuse. Exact independent RAW
owner and directory owner coexist in one actual shared scan: RAW
unlocks without clearing directory retry, then directory completes.

Eight executed unsafe variants per compiler reject: no-arm,
no-route, clobber-cursor, raw-to-bitmap, rearm-every-retry, early-retry,
no-backoff, scan-hold. Standalone v1989 regression remains accepted
with v1990 OFF, 82 FULL/80 recovery per CPU and all9 mutants reject.

Initial fixture compilation used a conflicting no-argument service
prototype and wrong terminal status type; use the original JRST
gateway ABI and unsigned int terminal status. Initial combined
fixture linked unused historical main bodies, overlapping the
physical test arena at040000; stopped that simulator and omitted
only unused mains. Final native runs pass, KCC reports unused
historical fixture helper notes; existing GCC include-order warning.
No new production compiler/assembler defect demonstrated.

Source-built linked package (same compiler and mode-switch workdir):
GCC5460->5917 resident words (+457); KCC6504->7055 (+551); BSS0.
Actual KCORE DXR unchanged between idle OFF/ON. Same-mode DOBJ,
MRES map, KCORE DXR reproduce after OFF/ON/OFF/ON. Recovery symbols
appear only in enabled MRES. Both real boot/kernel Makefiles refuse
recovery without directory and nonboolean recovery flag. The
committed package runner reproduces this matrix. New flag
DAIMOS_PBM_IDLE_RECOVER_V1990 defaults to0, requires directory and
inherits its strict swapless TSFS/no-interleaved constraints.

Evidence relative TMPDIR:
pure-bitmap-placement-v1985.SfnNWa (KCC),
pure-bitmap-placement-v1985.WVtXrs (GCC),
pure-bitmap-placement-v1985.lrRh7s (v1989 OFF regression),
pure-directory-idle-package-v1990.6BCnib (linked package matrix).
No physical FULL fault, dirty DROP recovery or source-loss policy
acceptance yet. Default unchanged.

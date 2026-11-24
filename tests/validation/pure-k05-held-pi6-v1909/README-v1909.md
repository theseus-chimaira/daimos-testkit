# K05 v1909: one genuine PCLK PI6 with held foreign FULL owner

Date: 2026-11-24. **Original source-built PDP-6 48K physical PASS.**

## Scope

This is one deliberately narrow PI6 test, reusing the unchanged
v1907 source-built five-child guest and v1908 long-held foreign
owner fixture. No alternate rebuild or general MM fault matrix.

The original packed-source `mm_free` genuinely returns -5. The
test-only complete PROCESS target owner changes from slot3 to
foreign slot2; unlike the recoverable v1906 variant, this owner
is never repaired. A real parent user TERM(3) is refused (`TR`).
Ten independently observed parent HBs continue to preserve MM18,
slot3 TRANSITION/VMbase0, original exec CTX_PC/FDCTL, source
RAW, foreign-claimed target and u[067] escrow `040000120000`.
No release or forged FINALIZE occurs; after HB10 the operator
ends the simulator, not the guest.

Immediately after HB4 the controller arms exactly one breakpoint
at the **original fixed-KCORE** `proc_sched_pi_tick=017225`.
It observes the actual PCLK/PI6 entry, checks the original
`AOS 1,proc_timer_clock` opcode `350040024530`, and reads the
hardware-saved interrupted PC from `pdp10_pi_level6=023714`:

    original PI6 saved word 340000017560
    interrupted executive PC 017560 (within idle loop 017552..017620)
    proc_current_slot 0

This is real PI6 execution, not a deposited timer/interrupt,
fabricated MM outcome or artificial kernel return. At the PI6
entry all MM18 extents, ROOT, saved executive CTX/FDCTL, held
TRANSITION and escrow remain unchanged versus HB4 and HB5.
The original shared backoff continues to `01000` octal ticks
and remains capped; subsequent original parent HBs 5..10
complete with no native target release or guest HALT claim.

The v1908 full positive acceptance oracle re-PASSes, plus a
source-linked actual PI6 PC/opcode/saved-return-PC and MM audit.
Only **three** additional independent unsafe physical trace
mutations are tested: changed PI6 opcode, interrupted PC outside
the idle loop, and lost u[067] escrow. All three reject. The
previous v1906-v1908 full MM/TERM/backoff negative suites need
not be rerun for byte-identical production images.

The source confirms ordinary executive code does **not** switch
at PI6; a slot-0 switch can occur only when the hardware-saved
PC lies in `proc_idle_loop..proc_idle_loop_end`. This bounds
the apparent arm-tag-to-escrow-store interleaving: a PI6 while
the MRES still executes cannot independently reenter the
slot-0 recovery service. This is source-level reasoning,
separate from the one actual idle-loop PI6 ordering verified.

No production C/ASM, kernel BSS or process RAM changes:

- KCORE SHA256 `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- PURE SHA256 `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`
- Normalized physical SHA256 `fbe72332fc0540331c9d4b131d0efded53e42d3da5b746b089ecc99f0f4cbb52`
- Source-linked physical `.ini` SHA256 `0d39f72ceebce81d2c3865428c7f516d51e94fa201ecb1ff22eada12dbafb45d`

## Repeat

From `daimos-testkit`:

    export DAIMOS_REPO=$HOME/git/DAIMOS
    export PDP10_PREFIX=$HOME/cross TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1909_BUILD=$TMPDIR/pure-brk-pressure-v1614.JInvCL/build
    export V1909_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1909_WORK=$TMPDIR/daimos-k05-held-pi6-v1909-physical-v1
    make test-pure-k05-held-pi6-physical-v1909
    make test-pure-k05-held-pi6-audit-v1909

Rebuild the v1907 guest and re-probe if original KCORE/PURE
image hashes differ. Retain the exact original FULL pressure
setup; do not pretend the v1909 observation covers arbitrary
PI6 arrival times, missing/foreign MM owner resolution,
or terminal cleanup of live saved executive stack. K05 OPEN.

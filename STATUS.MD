## 2026-11-04 v1143: historical RUN rollback controls restored

The v893 256K PDP-6 full guest passes against the current source
after its test-only injection anchor was moved to the current
`proc_discard_vm_done` entry. It observes one real pin, two busy MM
refusals, one unpin, three release calls, two deferred reaper passes,
and no test errors, with normal parent/bystander progress. The v894
native standalone fixture now supplies the existing scheduler timer
word required by `proc_finish_mark_pending_v892`; its staged VM and
u-area retry assertions PASS. Neither repair changes production code.

## 2026-11-04 v1142: physical unpublished RUN u-area MM_BUSY

The full 256K PDP-6 APR/EXEC/late failed-RUN guest now also includes
an opt-in, test-only physical u-area fault. The first actual MM free
of the unpublished slot-3 child is preceded by `mm_pin` on its real
allocated base and returns MM_BUSY (-5). The original discard code
retains the slot; the test unpins the same exact base only after
observing that refusal, allowing the normal deferred finalizer to
retry the real MM free. No production release or allocator routine
is replaced with a fake result.

`test-daimos-fatal-exec-physical-uarea-v1142` PASS on two fresh,
independently built full guests, with identical witnesses: two target
MM-free calls, one pin, one MM_BUSY, one unpin, no hook errors,
parent recovery and final EXEC child WAIT/ZOMB; APR fault and FILE
refusal/retry remain part of the same guest. The parent polls its
normal process-word/slot accounting until the deferred release
finishes. This supplies the remaining physical-u-area component of
D13 but not D14-D16 or the overall OOM activation. Production
`PROC_OOM_BRK_ENABLED_V1000` stays OFF.

## 2026-11-04 v1141: cross-object local relocation fold fix

The corrected installed PDP10-TOOLS `p10fold` and `dlink` prevent an
unsafe cross-object LOCAL TEXT alias: equal numerical section addends
outside a folded block belong to different objects and are not equal.
The new `test-daimos-p10fold-local-section-v1141` passes with both
corrected tool source trees. Old P10FOLD proposes the invalid fold,
and old DLINK accepts the injected invalid fold; both are detected by
the regression. Corrected DLINK rejects it before linking.

The formerly failing full 256K PDP-6 nested APR/EXEC/failed-RUN guest
now PASSes *uninstrumented*: FILE refusal/retry, late unpublished RUN
rollback, parent continuation/WAIT, `finish_zombie=1`, `error=0`.
The historical uninstrumented v890 EXEC/FILE/WAIT guest, native v1129
VM_NONE sentinel test and independently rebuilt v197 RUN rollback
(16 rejected post-VM fd maps, three live children) also PASS. The
second freshly rebuilt, uninstrumented nested v1126 guest independently
PASSes with the same late RUN, parent WAIT and exact terminal ZOMB.
The unsafe fold of `proc_discard_ok` into syscall-dispatch TEXT is absent
from the corrected production link. There was no DAIMOS source change
or OOM policy change. Physical MM_BUSY RUN rollback and remaining
activation signoff remain separate.

## 2026-11-04 v1140: D13 timing-sensitive MM-return trace

A fresh unchanged-production 256K guest with expanded simulator-only
breakpoints reached `mm_free` return, `proc_discard_ok`, child rollback
return, RUN epilogue and EXEC ZOMB=1. The previous narrower v1138
breakpoint set reached u-area release but then trapped with ZOMB=0.
This outcome difference is debugger-sensitive and is not D13 release
acceptance. Preserve the failing uninstrumented guest as the control;
the production OOM switch remains disabled.

## 2026-11-04 v1138: stage-only nested RUN rollback diagnostic

The disposable 256K PDP-6 v1138 guest was built with unchanged
production source. Simulator execution breakpoints trace the late
claimed-child rollback through VM completion and child u-area-release
entry. The same failed RUN does not reach its return epilogue before
invalid UUO; later u-area-release visits for slots 1 and 2 are
post-trap activity. This is a diagnostic PASS, not D13 acceptance.
Next inspect the MM-free return and parent-stack state immediately
around child u-area release. Production requester OOM remains OFF.

## 2026-11-04 v1130-v1133: D13 RUN rollback boundary isolation

The v1129 production VM_NONE fix is independently boot-verified by the
original v890 EXEC/FILE/WAIT guest. Its unrelated native VM sentinel
mutation test also PASSes. D13's combined APR+postcommit EXEC+late
unpublished RUN is still OPEN; its fresh, uninstrumented v1126 guest
reaches `<EA`, triggers the same simulator UUO word
`340000774047`, and never writes the parent's R or publishes a
terminal EXEC-child ZOMB. The first original v1126 guest reaches
the real RUN fdmap rejection (`late_run=1`), but a success result is
not implied by that entry count.

Two independently rebuilt full 256K PDP-6 RUN rollback controls
PASS: unchanged v197 under inherited groups, and new testkit v1130
under NEW groups. Both reject 16 real post-VM child RUN fd maps under
three live children, preserve slots/words, and later RUN/WAIT cleanly.
NEW process groups alone therefore do not reproduce the D13 fault.

Three test-only v1126 diagnostic variants give distinct outcomes:

- v1131: 13 guarded entry/return counters on the real RUN rollback
  path: `rollback_slot/new/live/vm_retry/vm_done/uarea_retry/ok/return`
  and `rollback_claimed/run_return` all equal 1; refusal/defer/fail
  counters are zero; the EXEC owner reaches ZOMB=1 and parent prints
  `<EARH`. This instrumented success is **not** D13 acceptance.
- v1132: only 13 unused BSS words in the disposable kernel, no new
  executable instructions, still gives `<EA`, the same UUO word and
  ZOMB=0. The selected BSS padding alone does not change behavior.
- v1133: just two counters at production `proc_run_claimed_bad` and
  `proc_run_return`: claimed=1 and returned=2, the latter including
  one earlier successful APR-child RUN. It still gives `<EA`, the
  same UUO and ZOMB=0. Reaching the return label does **not** prove
  successful return through `native_sys_mapped_return` into user code.

The code-layout/execution sensitivity warrants additional isolation
of the syscall mapped-user-release boundary and saved parent state.
Do not add production padding or speculative workarounds. The
historical original v890 guest remains passing, but this is not a
signoff on mixed D13 lifecycle, nor on physical MM_BUSY unpublished
RUN rollback. No v1130-v1133 production source, KCORE, MRES or ABI
change; requester OOM remains OFF, P0-D13 and E/F activation OPEN.

## 2026-11-04 v1129: exact VM_NONE idempotence and booted v890 repair

A disposable stage-level v1128 PDP-6 probe isolated the previously
failing v890 post-commit EXEC owner: its normal VFS FILE close had
succeeded after two refusals, yet the real VM destructor returned -1
once, with zero TTY failures, VM successes, u-area deferrals or
ZOMB publications. Source inspection identified the production bug:
`vm_space_destroy` interpreted the full-word `VM_SPACE_NONE` (-1)
as a nonzero 18-bit physical base and entered inappropriate XIP/MM
release. The old VM was already destroyed by the EXEC loader.

Production `vm_pdp6.s` now distinguishes the *full-word* VM_NONE
sentinel after storage-mode verification, then continues through
the real swap-backing detach without freeing a nonexistent MM/XIP
extent. The fix has no persistent data/RAM or ABI addition, just two
instructions in the resident VM destructor. The new source-linked
native PDP-6 `daimos-vm-none-idempotent-v1129.sh` PASSes two calls
with no MM/XIP free, two ordinary backing detach calls, retained
VM_NONE and rejection of invalid storage mode. The unsafe inverted
sentinel and skipped backing-detach mutants both fail as required.
The existing real-XIP VM release v1109 and swap-detach v880 native
regressions also independently PASS. New Make target and source-
linked P0-D release matrix row are present.

Most importantly, an independently rebuilt, **unmodified historical
v890 full PDP-6 boot guest** now PASSes: EXEC post-commit failure,
two genuine injected VFS FILE refusals, one eventual success, exact
descriptor/witness release, one exit and final parent WAIT. This
same original guest had previously timed out at both 65 and 180
seconds before the VM fix; the v1129 correction repairs that real
baseline failure rather than merely increasing a simulator limit.

The expanded v1126 nested APR/EXEC/unpublished RUN combined test
remains OPEN despite that repair: the new full guest reached `<EA`
and subsequently failed with a simulator UUO before the late RUN
marker, so its finalizer trace cannot establish exact terminal WAIT.
No D13 checkbox is changed. OOM remains OFF in production. Full
`P0D_FULL=1` and final enabled/disabled OOM matrices are not claimed.

## 2026-11-04 v1126: D13 integrated APR/EXEC/RUN reproducer (OPEN)

**v1126r1 exact-v890 baseline check:** In a clean TMPDIR fixture,
restore the *previously committed*, unmodified v890 test .c/.sh
from Git and build a completely new 256K PDP-6 image against current
production DAIMOS. With the historical 65-second simulator limit,
the original test prints `<E` and times out (exit 124). A second
fresh image from the same original files, changing **only** the
host-shell timeout to 180 seconds, likewise prints `<E` and times
out (exit 124; last reported PC 016424 octal). Neither image uses
the new v1126 APR/RUN/file-stage or timer test instrumentation.
Therefore the v1126 modifications alone cannot explain the
noncompletion, and simply increasing the host timeout did not
restore this baseline. The exact production vs emulator/PI6 cause
remains unproven. Investigate the original unmodified fatal EXEC
handoff first; D13 remains OPEN and the v1126 combined guest is
still NOT an accepted test. No production OOM enablement.

The opt-in `daimos-fatal-exec-apr-run-v1126.sh` extends the v890
post-commit EXEC fatal-FILE guest without changing production KCORE.
It exercises an EXEC owner whose old process VM has genuinely been
destroyed, test-injected VFS -5 FILE-close refusals on its retained
private stack, a separate child with a real APR protection fault,
and an unpublished child RUN rejected by the real fd-map validator.
The APR child's expected WAIT status is the existing flagged TERM
event (`SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM`), not plain status 1;
the first guest caught and corrected that test expectation error.

The extended guest next reached `<EAR` and the parent's immediate
post-failed-RUN MM slot/word accounting check. The EXEC owner then
completed its VFS retry with 5 VFS calls, 4 injected refusals and
one successful close (FD0 and private FILE witness cleared, one
`proc_exit_current`, zero test-ownership errors). Nevertheless the
parent's bounded NOHANG WAIT did not observe the EXEC child as
reaped: `<EAR1!t` followed by the guest's controlled HALT. A later
test-only finalizer trace did not establish the cause; it encountered
an additional simulator UUO after `<EA` and host timeout. The
diagnostic-only v1126 variants are **not acceptance** and must not
be mistaken for a passing child WAIT/VM cleanup test.

The experiment verifies that the APR and failed RUN can be reached
during an earlier EXEC FILE retry and that a late real VFS success
is possible. It does **not** prove the combined terminal owner/WAIT
handoff; it also does not yet inject physical MM_BUSY into this
guest's unpublished RUN rollback. Existing independent booted
v893/v895 prove real physical RUN u-area/VM rollback retries, but
are not a substitute for the combined scenario. **D13 stays OPEN.**
No change to production source, OOM activation or RAM allocation.

## 2026-11-04 v1125: booted physical MM wrong owner plus held FS lease

New `daimos-fatal-mm-provider-v1125.sh` runs the established v909/
v1101 full PDP-6 fault guest with a private extra mode; it does not
modify production kernel source. The test corrupts the owner field of
slot 2's actual MM_TYPE_KERNEL_DYNAMIC u-area extent exactly once.
The real MM free path refuses all seven reaper attempts with -4;
the parent sees MM teardown stage, exact wrong-owner probe code 0402,
and WAIT(NO-HANG)=0. No forged MM result or forced finalization.

Distinct slot 4 acquires the real filesystem-provider gateway lease
and retains the original kernel continuation at `fs_provider_unlock`,
yielding on its own private process stack. The actual provider lease
word is `5,,0` during the wrong-owner `mm_free` attempt and at the
final simulator sample, with one acquisition, 80 sleep cycles and
zero observed errors. Slot 3's separate spinner advances around the
delayed APR fault and the parent reaches a clean HALT. Other counts:
one APR fault, one MM descriptor owner poisoning, six reaper visits,
seven MM invalid owner returns, zero busy/pins or test errors.
At HALT, a separate descriptor observation confirms that slot 2
still has its transition/u-area ownership flags and its saved
u-area base equals the originally faulted physical MM target.
The parent also observes NOHANG for the live provider owner and
spinner. These checks exclude silent slot recycling or premature
retirement of a different process.

The initial run had correct MM/provider counters but failed its
historical transcript order assertion because the new F child waits
for the provider owner before faulting. The corrected harness checks
the new interleaving and the exact provider lease during real MM
refusal; the independent rebuilt full guest PASSes. The standalone
v1101 wrong-owner full guest was also independently rebuilt and
rebooted: PASS with seven real -4 refusals, six reaper visits and no
early WAIT. The entire source-linked v1096 P0-D matrix PASSes. v1125
is included in `P0D_FULL=1`, not yet rerun as a whole. D12 CLOSED;
34/65 mandatory checked, 31 open (29 pre-activation).
D13-D16 and P0-E/F remain OPEN and
production requester OOM remains OFF; no persistent KCORE/MRES/ABI
or memory increase.

## 2026-11-04 v1124: physical TTY/HUP, VM and post-VM u-area refusal

The new `daimos-tty-vm-uarea-v1124.sh` full 256K PDP-6 regression
PASSes three actual physically pinned MM release refusals in one
INIT process lifetime, not synthetic error returns. On the first
real user EXIT the owner-side session-HUP preflight encounters a
physically pinned canonical TTY line; the syscall returns -1 and
retains the original session/TTY owner. On the second user EXIT the
real TTY line is unpinned and released, allowing the ordinary exit
to publish PREVM. Its process VM is pinned and produces a genuine
MM_BUSY; the real clock-driven slot-0 reaper sees VM retained and
unpins it, pins the still-owned u-area and allows VM destroy to
commit. The next original u-area free produces its own MM_BUSY;
the following reaper cycle verifies VM_NONE with exact retained
u-area, unpins and releases the original owner once.

PASS counters: TTY MM_BUSY=1, VM MM_BUSY=1, u-area MM_BUSY=1;
each pin/unpin=1, TTY retention/retry=1, VM retained/destroyed=1,
u-area retained=1, final owner release=1, test errors=0. The test
checks both the stable process slot and final released TTY/line
resource. A failed first design was arming the obsolete v969 hook
after owner HUP; a second invalid synchronous cleanup attempt left
the VM physically pinned and timed out in the real reaper. Both
test-design errors were corrected, and the accepted fixture passes
using real owner-side HUP and asynchronous slot-0 cleanup only.
The cleaned generator was rebuilt/rebooted independently with the
same exact counts. The old v969 TTY-only fixture was updated to arm
at the current owner-side HUP entry rather than proc_exit_current;
its own independent full 256K PDP-6 guest PASSes with one physical
TTY pin, preserved owner, successful retry and zero errors.

New Make target `test-daimos-tty-vm-uarea-v1124` and optional
`P0D_FULL` row added; D11 marked complete. OOM readiness is now
33/65 mandatory checked; 30 preenable blockers remain, plus
F12/F13 post-signoff actions. D12-D16 and P0-E/F remain OPEN.
All hooks are confined to isolated test images, with zero change
to production KCORE code, MRES, RAM, ABI or disabled OOM policy.

## 2026-11-04 v1123: executable OOM scope and checklist audit

The active DAIMOS `TODO.MD` now has a fine-grained OOM activation
checklist, with fixed IDs S01-S08, A01-A04, B01-B07, C01-C04,
D01-D16, E01-E13, F01-F13 and optional X01-X08. The initial
checked baseline is **32/65 mandatory and 2/8 optional XIP**;
33 mandatory requirements remain OPEN (31 pre-enable blockers;
F12/F13 are necessarily performed after signoff). The canonical explanation
and release conditions are in
`pdp10-doc/KERNEL/OOM-ENABLEMENT-CHECKLIST-V1123.MD`.

The new `daimos-oom-scope-v1123.py` is a source-only guard proving
that production OOM is still default-OFF and ordinary RUN/EXEC
call `vm_space_startup`, which writes user memory even with argc=0;
neither loader uses the private MEMFS op 027 XIP admission. Six
deliberately unsafe mutations fail the guard. This permits the
*disabled* root-only XIP process-creation feature to remain outside
the current ordinary-process OOM activation scope. It does not
prove real scheduled XIP lifetime safety and must be extended if
XIP process admission is actually enabled later.

`daimos-oom-readiness-v1123.py` validates every checklist ID/status,
rejects five malformed/premature-enable mutations and reports the
open IDs. `make test-daimos-oom-scope-v1123` PASSes inventory and
scope while explicitly reporting `OOM ACTIVATION BLOCKED`.
`make check-daimos-oom-ready-v1123` correctly fails (exit 2)
on 31 unfinished pre-enable tasks; the two post-signoff actions do
not create a circular prerequisite. It never alters production code.

The entire current source-linked v1096 P0-D release-stage matrix
PASSes, including XIP release/VM ownership v1108/v1109, TTY,
PIPE, DPY, VM and SWAP, plus v1087 fatal graph audit. This is
native/component coverage: `P0D_FULL=1` disposable 256K guest
requalification and the other open P0-E/F gates are not completed.
Production OOM remains disabled with no KCORE/MRES/data/ABI delta.
The source-linked v981 requester-only policy, v998/v999 BRK cause,
v1113 real MM -2/-3 via BRK (three mutants rejected), v1092 provider
quarantine (14 mutants rejected), and v1086 slot-0 PI6 callback
closure all independently rerun PASS. v1123 audit counts 33 open
mandatory items, distinguishing **31 pre-enable blockers** from
F12/F13 post-signoff release actions.

## 2026-11-04 v1122: two real failures, PIPE MM_BUSY then DISK bitmap

`daimos-session-hup-pipe-swap-v1122` PASSes a full 256K PDP-6 guest
with two independently owned resources and a single session-HUP
teardown. The first member owns a real PIPE dynamic MM extent. Its
first delivered HUP enters the production final FILE/PIPE close;
a test-only MM pin makes the actual MM free return -5. The first
session HUP fails without releasing that owner, PID, or the session.
On the next HUP scan the first member is visited exactly once more;
its original PIPE extent unpins and frees successfully. Only then
does the second member reach its independently owned, real DISK
swap record created by production `proc_swap_reclaim` in SWAP MRES.

The second member's actual `backstore_verify_allocated_v795` verifier
detects a test-corrupted allocated bit and refuses checked detach.
The terminal slot-0 PREVM reaper retries after the recorded clock
delay, restores precisely that physical bitmap bit, and releases
the original backing record once. No invented DISK record, synthetic
second-member return code, or production change is involved.

The accepted boot measures first member ID=3, leader ID=2,
PIPE calls=2/pins=1/busy=1/unpins=1/frees=1/owner errors=0,
first-member HUP repeats=1, physical DISK swap-outs=1,
bitmap verifier calls=2/corruptions=1/restores=1,
swap-free calls=1/swap errors=0, and final exact DISK record=0,
block count=0. First-member u-area pins=1/unpins=1,
session pending=1 and final leader/member WAIT and TTY ownership
PASS without duplicate committed HUP or premature leader WAIT.

The test composes v1104 PIPE and v1107 DISK injection only in
disposable kernel copies and explicitly uses three leader HUP
attempts to traverse two distinct real physical refusals. The two
original single-provider entry modes remain available unchanged.
`P0D_FULL` and a versioned standalone Make target include v1122.
This is a genuine PIPE+DISK bitmap combined-failure P0-D subset;
booted MEMFS XIP, sustained simultaneous provider-liveness and the
full P0-D/E/F enable decision remain OPEN. Production requester
OOM remains disabled, with no production KCORE/MRES/ABI/RAM change.
The original v1104 PIPE-only and v1107 real bitmap-only guests were
independently rebuilt and rebooted after the v1122 generator change.
Both PASS their original fault/retry, owner, WAIT and TTY checks;
v1107 retains exactly two verifier calls, one deliberate bitmap
corruption, one restore and one physical backing free.

## 2026-11-04 v1121: real DISK swap-out/in during physical DPY HUP refusal

The `daimos-session-hup-dpy-swap-v1121` full 256K PDP-6 guest PASSes
one new combined resource-lifecycle scenario. The second session
member first publishes a real Type-340 display list; a test-only
production `proc_swap_reclaim` call then swaps that exact slot out
to real DISK backing. Its first HUP attempts private DPY final-close
and physically pins the exact MM raw-list extent, returning the real
MM_BUSY (-5). Private FILE-close retry restores the original process
from DISK using the genuine SWAP MRES `proc_swap_in` path and then
unpins/releases the display extent on a later HUP continuation.

An initial guest reached clean HALT and all physical DPY counters
but failed the old swap-only expectation `second=0`: DPY refusal
legitimately delayed terminal finalization, causing one later
second-member HUP attempt. The recorded swap bitmap verifier count
was zero; assuming an actual DISK detach refusal here would be
incorrect. The revised v1121 fixture therefore records real SWAP
MRES restore entry and successful return into KCORE-owned test-only
words, and requires exactly one successful restore, zero direct
bitmap-verifier invocations, one backing free and final zero backing
record/block count. The original v1107 bitmap-failure path remains
separately asserted in its original mode, unchanged.

The corrected guest PASSes: one genuine swap-out and one genuine
swap-in, DPY calls=2, pin=1, MM_BUSY=1, unpin=1, free=1, errors=0,
118 PI6 display refreshes (90 while held after busy), leader/member
WAIT/TTY success, first-member u-area pin/unpin, one second-member
HUP retry, no repeated first-member delivery, zero swap errors,
one backing free and no retained DISK record or blocks. All test-only
instrumentation lives in disposable kernel and SWAP MRES copies.

This is valid integration of physical DPY release with swap-out and
swap-in in one process, NOT simultaneous DPY MM_BUSY and bitmap
detachment failure. The latter requires an owner/lifecycle capable
of retaining a DISK record at the point of actual checked detach;
physical MEMFS XIP integration and wider P0-D/E/F remain OPEN.
Production code, MRES footprint, ABI and default OOM state are
unchanged. New Make and optional P0D_FULL rows run this regression.
The unmodified v1107 swap-only full 256K PDP-6 compatibility guest
was independently rebuilt and rerun after v1121: PASS with two real
bitmap-verifier calls, one deliberate bitmap corruption, one exact
restore and backing free, no duplicate member-HUP delivery, and zero
terminal DISK record/blocks. The new mode does not weaken v1107.

## 2026-11-04 v1120: full guest numeric PID reuse after real physical OOM

Two independent disposable 256K PDP-6 images PASS the new
`daimos-oom-pid-reuse-v1120` regression, once with production-default
requester OOM disabled and once with the OOM policy enabled only in
the isolated kernel image. The original v1075 real physical-memory
exhaustion and independent blocked witness run first. The disabled
guest returns the normal BRK -1; the enabled guest fatally retires
only the exhausted child. The witness survives both modes and all
process-MM accounting returns to baseline before PID reuse begins.

The same parent then RUNs, waits for and fully reaps 24 consecutive
children whose distinct alternating statuses are 062 and 063 octal.
All 23 consecutive adjacent pairs reuse the exact same numeric PID;
the current process-slot model has no PID generation number. After
each reap and before the next RUN, a second WAIT and a directed TERM
against the now-unallocated number must both return -1. After each
cycle SYS_MEMINFO process slots and process words equal their original
post-OOM baseline. Any mismatched WAIT, stale event acceptance,
unexpected number allocation, failed RUN, extra slot or MM leak is
a guest-fatal assertion. The disabled transcript ends `<DNWQP`, the
test-only enabled transcript `<KWQP`, both with a clean simulator HALT.

Native source-linked `daimos-xip-vm-retry-v1109` and the v1087 fatal
release graph audit also PASS after this work. New guest code is C89,
uses the original syscall ABI and adds no production PID generation,
MM/FILE bookkeeping, kernel code or resident RAM. This closes the
sequential numeric PID-reuse-after-OOM P0-E subset, not the required
concurrent HUP/PIPE/DPY/XIP/swap provider cross-products, stale PID
after reuse (which legitimately names the new owner), or full P0-E/F.
Production OOM remains disabled. Two dedicated Make targets and the
optional full P0-D acceptance matrix invoke the test modes.

## 2026-11-04 v1119: physical PIPE and DPY faults during the same session HUP

`daimos-session-hup-pipe-dpy-v1119` now boots one disposable 256K
PDP-6 guest whose second session member owns both a real PIPE and a
published Type-340 DPY display list. The existing v1104 and v1105
fault hooks are composed at `mm_free` and at its busy/delete paths,
preserving each type/owner guard. Both hooks arm at the original
session-HUP delivery point; v907's first member remains physically
pinned during the partially committed HUP. The source fixes a C89
declaration-order problem exposed by activating both test modes.

Two independent fresh-image full-system boots PASS, including the
final `make test-daimos-session-hup-pipe-dpy-v1119` run. Each resource
has a distinct nonzero MM base, two release attempts, exactly one
real physical pin, one MM_BUSY (-5), one unpin and one successful
physical free. No PIPE or DPY owner error is reported. The DPY raw
list stays published while its first release is refused, with 14
actual PI6 refreshes and 8 refreshes after MM_BUSY but before unpin.
The first session member retains its original pinned u-area, HUP
commit/retry happens once, no duplicate first-member HUP occurs, and
the expected leader/member WAITs and TTY ownership handoff PASS.

All hooks and counted state are test-only; production DAIMOS code,
fixed KCore/MRES RAM, ABI and OOM activation are untouched. This
proves one combined physical PIPE+DPY session fault/retry scenario,
not a simultaneous VM/XIP or DISK bitmap fault, permanent refusal,
actual PID-number reuse, or complete P0-D/E/F acceptance. Production
requester OOM remains disabled. The new scenario is registered in
optional `P0D_FULL` and as a standalone Make target.

## 2026-11-04 v1118: booted physical PIPE plus process-VM mixed teardown

The independent `daimos-oom-physical-mixed-v1118` full 256K PDP-6
guest PASSes. Previously separate v1103 PIPE/HUP and v1106 real VM
pin/MM_BUSY hooks are now composed at the same `mm_free` entry in one
disposable kernel, without skipping either production owner/type path.
The initial combined run stopped before build because both private
injections required a different exact `mm_free` insertion anchor;
the v997 test generator now preserves both hook chains. No production
kernel source was changed.

Observed in the single completed boot: exactly two final PIPE frees
with one -5 refusal and no PIPE ownership errors, two actual process-VM
MM frees with one -5 from a physical VM pin, one physical VM unpin,
one successful deletion and one swap detach, two HUP-stage calls with
one deliberately injected refusal, three FILE closes with two
refusals, and two final u-area frees with one MM refusal. Exactly one
EXIT/CHLD/finalization, zero provider errors, intact foreign FS lease,
and 37 observed unrelated spinner cycles all PASS. The v1117 sequence
of 48 post-reap stale WAIT and PID-directed TERM refusals also PASSes,
with no growing process slot or MM-word accounting. This versioned
full guest is included in optional P0D_FULL and has its own Make target.

This closes a *specific combined physical PIPE+VM* release-and-liveness
subset. Session HUP rejection here is a stage injection, not a physical
DPY/HUP fault. No live MEMFS XIP lease, simultaneously failing swap
bitmap and full numeric PID-reuse stress are covered by this boot.
P0-D/E/F remain OPEN and production OOM remains disabled.

## 2026-11-04 v1117: mixed-fault stale WAIT/PID and bystander liveness

The opt-in full 256K PDP-6 `daimos-oom-wait-churn-v1117` extends
the booted v1103 PIPE/FILE/HUP-stage/VM/u-area fatal-release case.
After the parent reaps its fatally retired child, it repeats 48
stale-PID WAIT requests and PID-directed TERM requests, requiring
ordinary -1 rejection every time. After every pair it verifies that
process slots and process-MM words do not grow. The foreign FS lease
remains held, and the unrelated spinner continues runnable throughout.
The original v1103 test still reports exactly 2 PIPE physical frees
with 1 refusal, 3 FILE close attempts with 2 refusals, 2 HUP-stage
calls with 1 refusal, 2 VM calls and 2 u-area calls with 1 refusal,
one EXIT/CHLD/finalization, no ownership/provider errors, and 36
observed bystander cycles. v1117 PASSes as one disposable boot.

An initial version attempted new RUNs after the provider lease was
deliberately held. It could not complete because the executable
loading path legitimately blocks on that lease; this was an invalid
test assumption, not evidence of a kernel RUN deadlock. The final
test instead probes stale WAIT/PID/event behavior, independent of
new executable loads. It does not prove numeric PID reuse or
general multi-provider liveness. The optional P0D_FULL matrix now
includes this booted regression. Production code/BSS/MRES and OOM
policy are unchanged; P0-D/E/F remain open.

## 2026-11-04 v1116: booted exact RUN MM descriptor failure cause

Two separately built and booted 256K PDP-6 disposable images PASS
the opt-in `daimos-oom-run-cause-v1116` test. Tracked physical MM
allocations fill the real extent-descriptor table before a valid
child RUN. Test-only captures immediately following the production
MM allocator calls in `vm_space_create` and `proc_run_block` prove
the failing stage returned -3 (descriptor exhaustion). The other
stage returned 0 or was not executed (-7 test sentinel). The public
RUN returns -1; no extra process slot or process RAM remains after
the rejection. Every tracked temporary extent is released by its
physical base, original type and owner.

Both default-disabled and disposable OOM-enabled boots PASS, then
successfully repeat the existing invalid-RUN and BRK controls, true
physical-exhaustion requester, WAIT and independent witness checks.
The genuine physical-OOM requester alone is terminated when OOM is
enabled in the test copy. Native v1111, v1113 and v1000 regressions
also PASS. No production text/data, MRES, ABI or OOM switch changed.
These results do not close the remaining P0-D/E integrated liveness
and fault cross-products or authorize production OOM enablement.

## 2026-11-04 v1115: booted real MM fragmentation with exact BRK cause

The opt-in full 256K PDP-6 v1115 guest links an isolated test-only
BRK sentinel extension into a disposable syscall kernel copy. It uses
the production `mm_alloc_aligned_noreclaim` and `mm_free` to construct
physical fragmentation from real 040000-word (16K) kernel-dynamic
extents, freeing alternate blocks while retaining every remaining
physical base. A test-only export of production-private `mm_find_fit`
verifies that at least 0200000 (64K) words remain free in aggregate,
yet no contiguous 64K extent exists. The parent requests a 64K BRK;
real `vm_space_brk_current` returns -1 and exposes the exact internal
-2 fragmentation cause through the test-only syscall observer. The
original logical break, requester and its MM process words survive.
All recorded temporary extents are freed using exact base/type/owner.

An earlier 40K test correctly observed a failed full-image fit, but
BRK was able to grow in place using only its smaller delta. The 64K
request also excludes that adjacent-gap path. The initial cleanup
fixture incorrectly required the global extent count to remain
identical after ordinary VM/FS reclamation: a boot showed one fewer
descriptor, while every tracked temporary free succeeded. The final
fixture rejects an increased descriptor count and confirms all exact
test-owned frees and unchanged parent process-MM accounting.

Both separate full-system boots PASS: default-disabled OOM prints
`<FRILDNWP`, and disposable enabled-policy OOM prints `<FRILKWP`.
The fragmented requester survives even with OOM enabled; a later
genuine physical exhaustion still retires only its requester under
that test policy. Subsequent failed-RUN, invalid-BRK, WAIT and blocked
witness cases pass with final process-MM accounting restored.
The test instrumentation and data are absent from production kernel
code and BSS. P0-F still needs direct RUN -3 cause tracing, and P0-D/E
integration remains open; production OOM stays disabled.

## 2026-11-04 v1114: booted real MM descriptor pressure with child RUN

The opt-in full 256K PDP-6 guest v1114 adds a test-only extension to
the disposable syscall BRK entry. Two invalid logical break sentinels
fill the actual `mm_extent_count` to its configured
`mm_extent_capacity` using real `mm_alloc_aligned_noreclaim` calls,
record each one-word kernel-dynamic extent base, and release them
with exact `mm_free` type/owner checks. The original kernel source is
neither edited nor committed. A structurally valid RUN of the same
real executable used by the v1110 child tests returns -1 while the
descriptor table is fully occupied. The exact internal RUN/MM error
is not directly traced. Exact allocation cleanup restores the parent
to its baseline process slot and process-MM accounting.

Both separately built, booted 256K variants PASS: default-disabled
OOM produces `<MRILDNWP`, and test-only OOM-enabled produces
`<MRILKWP`. The later ordinary RUNs, invalid BRKs, real physical
exhaustion requester and independent witness still behave correctly;
only physical exhaustion fatally retires the requester with the test
policy enabled. Test-only temporary kernel code and scratch storage
are not part of production KCore/MRES. Booted BRK fragmentation and
direct -3 RUN-cause tracing remain open under P0-F, as do P0-D/E.

## 2026-11-04 v1113: MM failure causes through actual VM BRK and syscall

The native PDP-6 `daimos-oom-brk-real-mm-v1113` regression combines
unchanged production `mm_find_fit`, `mm_extent_insert`,
`mm_alloc_aligned_noreclaim`, `mm_alloc_aligned`, `mm_compact`,
`vm_space_brk_current`, and OOM-enabled `native_sys_brk`. Its physical
arena includes an actual current process extent, neighboring extents,
and disjoint gaps. The current image cannot grow in place; the VM
fallback enters actual MM allocation. In the fragmented case no gap
fits the requested 04000-word image although 06000 words are free:
the allocator returns -2 through VM and syscall. In the descriptor
case a fitting gap exists but both descriptor slots are occupied:
the allocator returns -3 through the same path. Both preserve the
exact original process VM, logical BRK and MM count, with no fatal
requester selected. Three unsafe source mutations (lost VM cause,
collapsed fragmented cause, collapsed descriptor cause) are rejected.

This is a source-linked native PDP-6 test, not a full-system boot.
The native harness provides no-progress FS/swap reclamation, a
refused MM move, and a fatal-call witness. These are test-only stubs,
not new production behavior. Real booted resource-pressure BRK/RUN
and PID/WAIT acceptance remain open under P0-F; production OOM stays
disabled and KCore/MRES occupy no additional words.

## 2026-11-04 v1112: failed RUN remains nonfatal in booted OOM matrix

The optional v1112 extension of the real 256K PDP-6 v1075 guest
submits a structurally valid RUN request to a nonexistent absolute
executable. The kernel rejects the request with -1, retaining the
calling parent and leaving its process-slot and process-memory counts
unchanged. The parent continues through the v1110 invalid BRK controls,
then through the established genuine BRK physical-OOM requester and
independent blocked witness.

Both separately built and booted disposable configurations PASS:
`<RILDNWP` with the production OOM default disabled, and `<RILKWP`
with the OOM switch enabled only in the isolated test kernel. Normal
failed RUN never terminates the requester; only genuine physical
exhaustion triggers fatal requester selection when enabled. The
witness survives, final MM accounting returns to baseline, and no
production code, data, default policy or ABI changes. This covers
a missing-executable failure, not a RUN that fails under real MM
descriptor exhaustion or fragmentation; those P0-F gates remain open.

## 2026-11-04 v1111: real PDP-6 MM error classification

`daimos-mm-exhaustion-class-v1111` links the unchanged production
`mm_find_fit`, `mm_extent_insert` and `mm_alloc_aligned_noreclaim`
assembly. With two live extents in one 010000-word arena, it verifies
real insufficient-total-RAM (-1), fragmented-but-sufficient-total
free words (-2), and full descriptor capacity despite a fitting gap
(-3). Failed allocations preserve both existing extent descriptors
and their count. Increasing the descriptor capacity allows the same
small allocation to succeed, inserting the new middle extent in sorted
order. Both unsafe error-collapse mutations are rejected. This is a
native allocator leaf test, not a booted BRK/OOM integration test.
Production memory and OOM defaults are unchanged; P0-F remains OPEN.

## 2026-11-04 v1110: booted invalid BRK versus real physical OOM

The opt-in `daimos-oom-brk-negatives-v1110` full 256K PDP-6 guest
extends the established v1075 requester/witness test with two child
BRK validation failures: below image floor and overflowing the 18-bit
APR limit after rounding. Both return -1 without changing break,
terminate normally and leave child WAIT/slot/MM accounting correct.

The test PASSes in two separate disposable image boots. Default-off:
`<ILDNWP`, with physical exhaustion returning -1 and no fatal requester.
Test-only enabled OOM: `<ILKWP`, with only the exhausted requester
fatally retired. The independent witness survives both tests and final
MM accounting matches the baseline. Legacy v1075 is unchanged unless
the versioned test option is set. Production OOM remains OFF; no kernel
code or resident data is added. Other P0-F and P0-D/E gates remain open.

## 2026-11-04 v1108: real MM refusal and repair of MEMFS-owned XIP

`daimos-xip-physical-retry-v1108` reuses the real v1086 source-linked
MEMFS direct-provider dispatch and MM leaves. With an owned XIP ref
but zero physical MM pins, the first release returns -4 and retains
the ref, original extent and foreign provider lease. Production
`mm_pin` repairs the extent; a second release consumes the ref and
unpins once, and a third reports no remaining XIP owner. No provider
clock wait occurs. Baseline v1086 and existing v1094 fault/mutation
tests PASS. This native test does not close the booted XIP/VM P0-D gate.

## 2026-11-03 v1087: transitive fatal-release P0-A CLOSED

The new source-linked `daimos-oom-transitive-release-v1087.py` follows
current BRK/APR/EXEC fatal entry, ordinary EXIT, private and foreign
FILE close/VFS SYNC (DTFS validation and D6FS no-op), HUP with partial
member retirement, TTY canonical release, PIPE/FIFO, DPY STOP,
VM/MEMFS-XIP, MM/backstore bitmap, U-area and parent notification.
All direct callbacks and ownership/error ordering are asserted.
No new MM or backstore allocation occurs in the bounded current graph.
Eleven deliberately unsafe source mutations are rejected. The
dedicated `test-daimos-oom-transitive-release-v1087` Make target
executes that contract and native PDP-6 v870 PIPE, v904/v912 DPY,
v957 actual C disk/resident detach, v905/v922 partial HUP, v995
private fatal owner FILE/HUP retry, v1078 foreign lease contention,
v1081 last TTY PREVM and v1085 unpublished RUN rollback. All PASS.
The historical v922 fixture needed the checked v897 TTY release
success stub, matching v905's existing no-canonical-line fixture.

The full 256K v1077 physical requester OOM/D6FS/MM guest PASSes
with two D6FS refusal attempts, one actual MM_BUSY and a surviving
independent witness. Production code is unchanged: zero KCORE/MRES
code/data growth, end `023126` octal. The production OOM gate remains
disabled. P0-A is closed for the current graph, not for a permanently
nonreturning already-active foreign provider; that is P0-B. P0-D/E/F
still require error-stage, mixed guest and enable regression coverage.

## 2026-11-03 v1086: P0-C PI6-masked slot-0 teardown CLOSED

The source audit found a real second session HUP when `proc_exit_current`
switched onto the idle stack with scheduler PI6 inhibited. The ordinary
EXIT and APR/EXEC fatal owner paths already preflighted HUP on the
private stack, but the unmarked `proc_finish_slot_owner_v932` could
perform HUP again on the idle stack, potentially sleeping during PI6
masking. The direct self-fatal event path lacked private preflight.

v1086's production fix publishes existing FINALIZE+PREVM and
TRANSITION state under disabled global PI before switching stacks;
the permanent idle finalizer therefore skips HUP. Immediate self-
fatal delivery now uses the existing private FILE/HUP retry.

New acceptance target: `test-daimos-slot0-pi6-v1086` (source-linked
contract, seven negative source mutations, real MEMFS XIP provider
dispatch with a foreign-held serialized lease, real MM unpin, actual
EXIT-stack transition with pre-v1086 negative control, and marked
finalizer whose HUP stub refuses if called). Every v1086 test PASSes.
Older v974 self-fatal priority and v926 owner-return fixtures gained
their missing v995-era session-HUP success stubs; both PASS with the
new self-fatal route. Existing v970/v995 private HUP retry and v993
EXIT preflight native tests PASS as well.

Full 256K v1077 physical-OOM provider/MM test PASS: two D6FS SYNC
refusals, one MM_BUSY, exactly one requesting victim, independent
witness progress. Full session-teardown guest PASS (running/stopped
jobs HUP, TTY detach/reattach); full process-events guest PASS
(PID/PGRP signaling, TSTP/CONT, CHLD, fatal WAIT and ALRM).
Matched KCC KCORE low end rises by seven octal-address words
(`023117` -> `023126` octal), no new permanent state or MRES vectors.

Note: the historical v918 noncurrent-fatal standalone fixture still
encodes an obsolete pre-v926 assertion that a fatal signal to a
WAIT_EVENT owner is immediately rejected. Current code defers it for
owner delivery. It was not used as v1086 acceptance; the full
process-events guest and current native fatal-owner tests PASS.

P0-C is closed specifically for the OOM slot-0 finalizer entry graph.
P0-A/B/D/E/F remain open. No hardware APR clock failover is required;
automatic OOM killing remains disabled in production.

## 2026-11-03 v1085: SIDL RUN rollback TTY gate before VM teardown

The unpublished RUN discard can remain SIDL/TRANSITION after an
unsuccessful VM rollback, allowing the parent to leave the inherited
session while the child still owns a potential last-member TTY line.
Old `proc_slot_discard` destroyed the VM, then dropped the return from
`proc_tty_release_session`. A refused TTY/MM free could retain the
canonical line record after the final retry process and u-area were
gone. The full process was incorrectly reported as discarded.

v1085 performs checked TTY retirement before VM destruction and
routes refusal through the existing SIDL VM retry marker and shared
slot-0 backoff. No additional retry table, allocator, kernel ABI or
permanent data is needed. Source-linked native PDP-6 positive test
checks TTY refusal, retained VM/U-area, SIDL reaper mark, successful
retry, exact-once VM/U-area destruction, and no EXIT/HUP/WAIT paths.
The pre-v1085 source negative control specifically confirms the old
successful-discard-with-unreleased-TTY ownership failure. Both PASS.

Previously stale v892/v894 extracted-fixture constants now include
`PROC_FINALIZE_PREVM_LH`; the v894 TTY callback returns the checked
zero-success ABI, and its expected call count reflects v1085's TTY
preflight on each pre-VM retry. Native v892, v894 and v1081 PASS.
The full 256K physical-OOM v1077 D6FS/MM fault guest and v969 actual
MM-pinned TTY exit/unpin/retry guest PASS as well. Matched KCC KCORE
low end rises one word (`023116` -> `023117` octal), zero new BSS.

OOM activation still requires a complete transitive teardown and
provider-ownership proof, safe behavior for nonreturning in-flight
callbacks, a slot-0 PI6-mask reachability proof and cross-product
full-system regressions. Physical failure of the APR line clock is
not an OOM recovery requirement; software-induced blocked PI6 is.
`PROC_OOM_BRK_ENABLED_V1000` remains disabled in production.

## 2026-11-03 v1084: FIFO OPEN rollback cannot abandon a pinned PIPE

An interruptible named FIFO OPEN acquires a provisional FILE descriptor
and a live PIPE reference before its reader/writer rendezvous. On
interruption the former `pipe_fifo_open_intr` discarded the result of
`pipe_close_ref` and returned failure unconditionally. A refused final
MM free kept the PIPE object allocated and counted but `file_open`
erased the only FD which could retry its release.

v1084 replaces a single `JRST` with `JUMPE`: successful rollback still
reports interrupted OPEN; failed rollback commits the already
reserved descriptor, so the caller receives a usable FD and can
close it after MM becomes releasable. This is failure-atomic ownership
transfer without a new retry table or global collector. Matched KCC
`__kcore_low_end` remains `023116` octal; no new BSS or MRES words.

The native PDP-6 v1084 acceptance links actual FILE OPEN/NEWFD/CLOSE,
PIPE FIFO find/open/close/unlink and real MM free/unpin. An injected
physical pin prevents the first rollback; the returned FD, PIPE
reference and MM owner remain intact. A second close also refuses;
after physical unpin the same FD closes and the allocation disappears.
An ordinary unpinned interrupt still returns failure and frees the
object. The pre-v1084 negative control specifically confirms retained
MM ownership with a cleared FILE descriptor. PASS.

The full named-FIFO guest PASSes rendezvous, shared runtime, rename,
unlink, mount-busy and D6FS persistence. The old wordfifo-v2 test's
`!2` check was obsolete after v901 added PIPE character operations;
the test now expects an exact `'X'` character round-trip before the
original opaque-word FIFO tests. OOM termination remains disabled.
The corrected full wordfifo-v2 guest PASSes, as does the v901 native
character-stream test. The testkit Make target for anonymous PIPE now
also executes its genuine v902 guest regression instead of only the
wordfifo prerequisite. Full 256K physical-OOM guest v1077 PASSes two
D6FS and one MM refusal, with owner retry and independent witness.
The actual v902 anonymous PIPE guest PASSes create, character I/O,
EOF, EPIPE, duplicate and RUN references, and blocking wakeup.

## 2026-11-03 v1083: direct fatal-release leaf audit (no kernel delta)

The new executable source contract
`test-daimos-fatal-release-scope-v1083` checks the precise production
PDP-6 destructor bodies for newly introduced MM/backing allocation:
FILE close, PIPE/FIFO close, TTY canonical line and session release,
U-area free, VM destroy, C swap detach, MEMFS XIP ownership/unpin and
the zero-word DPY STOP path. It also asserts the important failure
branches and ownership-preserving ordering, including the guarded
zero-word DPY branch before the positive-length `mm_alloc` path.

Existing native acceptance PASS: v870 last PIPE/FIFO release with
real faulted MM and retry; v904 DPY pinned/wrong-owner STOP and retry;
v912 double-faulted DPY replacement and recovery; and v957 actual C
resident/disk swap-detach and backing verifier semantics. No kernel,
resident KCORE, persistent-data or ABI changes were required.

These are DIRECT leaf guarantees only. Session HUP cascades, foreign
in-flight provider ownership and retry liveness do not become proven
by the source contract. The interrupted FIFO OPEN cleanup is a
separate ownership gap: if the last transient `pipe_close_ref` refuses
MM free, `pipe_fifo_open_intr` discards its error while `file_open`
discards the provisional descriptor. Ordinary close has an FD retry
owner, this abort path does not. A legitimate physical pin on that
not-yet-published pipe is not established; the failure-injection case
still needs explicit design/testing rather than a forced MM free.
Production OOM termination remains disabled.

## 2026-11-03 v1082: NEWSESSION TTY release is transactional

The former PROCCTL_NEWSESSION path rewrote the caller's group, session
and TTY state before calling the last-member TTY release. A pinned
canonical input allocation could therefore retain the old TTY session
after its only process abandoned that identity, and the syscall still
reported success.

The new path calls the existing checked TTY/MM release before publishing
the new identity; refusal leaves the caller in the old session and
returns -1, preserving a natural owner for retry. The session scan
already excludes the leaving slot, so other old-session members keep
their TTY without attempting a release. The production PDP-6 native
fixture passes refusal, unpin/retry and peer-member cases. The
pre-v1082 code fails the corresponding negative control as intended.
The earlier v1081 owner-finalizer/MM regressions also pass. A complete
process/TTY simulator guest passes with the current kernel. The
noninstrumented KCC KCORE low end increases 4 words
(`023112` -> `023116` octal); no new BSS. Production OOM killing is
still disabled pending transitive provider teardown audits.
Additional full simulator regressions PASS: session leader HUP and
TTY reattach, TTY detach/reattach state of every live member, and the
256K physical-OOM requester-only test with two D6FS SYNC refusals and
one MM_BUSY refusal (owner and independent witness recover).

## 2026-11-03 v1081: final-member TTY MM owner is not orphaned

Source-linked PDP-6 finalizer test v1081 verifies that a TTY release
refusal leaves VM and u-area intact under the existing PREVM marker,
that the idle stack retries TTY then VM in order, and that post-VM
MM_BUSY retries do not repeat TTY or VM release. Existing native
v967/v968 real MM pinned/wrong-owner cases and v881 deferred-uarea
case pass. Source-contract gate checks the production checked-return
TTY API and no new provider cancellation. The full 256K v1077
requester-OOM D6FS/MM faulted guest passes. The older v969 full-guest
fixture originally injected a pin into a TTY whose session owner
was already zero. v1081's fixture now explicitly sets a genuine
session owner before arming that test case.
The corrected v969 booted guest passes with retained/retried witnesses
equal to one and error witness zero. Against the original pre-v1081
finalizer, the new source-linked v1081 test correctly fails before
VM ownership can be established. Comparable noninstrumented KCORE
low-end grows two words (octal 023110 -> 023112), with no new BSS.

## 2026-11-03 v1080: DRM236 third concurrent request waits correctly

The v1079 DRM watchdog introduced an accidental unconditional retry in
`drm236_runtime_queue_full`: it masked the watchdog LH to get the
active descriptor pointer but retained a bare JRST instead of the old
conditional SKIPN. One active + one pending request could leave a
third caller busy-spinning instead of sleeping on the active owner's
private three-word completion descriptor.

`test-daimos-drm236-queue-full-v1080` links the actual PDP-6 DRM
runtime service. With both older descriptors owned, a third caller
must enter `proc_wait_event` on the active request's completion word,
then retry/claim the freed engine and wait for *its own* completion
word. It checks the new 300-tick watchdog, two exact event addresses,
successful return and cleared engine state. PASS. The unchanged v1079
driver FAILS the same native test as a negative control. The corrected
driver uses one JUMPE instead of JRST; **no added RAM words**.

The v1079 watchdog sequence and real-SIMH DRM online read/write/queue
tests still PASS. The full 256K v1077 requester-OOM guest remains PASS
with two D6FS SYNC refusals and one MM_BUSY refusal, restored memory
accounting and an independent witness. Clock-inhibited slot-0 device
waits and generic provider cancellation remain open.

## 2026-11-03 v1079: real DRM236 in-flight timeout and KINIT hook

`test-daimos-drm236-watchdog-v1079` source-checks the new 60-Hz
storage clock chain (DSK direct call followed by DRM tail call) and
runs real PDP-6 DRM236 MRES/clock assembly for two hardware-stalled
runtime descriptors. The first times out after three simulated ticks
with its remaining count preset to 3. The pending second request is
promoted with a *fresh* 300-tick deadline, times out once after exactly
300 clock ticks, and leaves both stack-owned events at `-1`. The
owner-wakeup and existing DRM storage error counters each advance
twice, with no early or duplicate completion: PASS.

A deliberately disabled DRM watchdog fails the same native test as
expected. The Type-167/236 real-SIMH `daimos-drm236-online-v1` read/
write/queued-runtime suite also PASSes after correcting an obsolete
test-only `drm236_read_jump` symbol to `drm236_read_call`.

The complete 256K physical-OOM v1077 guest still PASSes on the new
clock/DRM code (D6FS FILE 3/2, u-area MM 2/1, `<KWP`, unrelated
PIPE witness survives). Independently, direct `ROOT=drum` Stage1
boot with DSK0 unattached reaches DRM236 OK, D6FS LOADED, INIT and
LOGIN: PASS. The linked KCORE low end rises one word (`023157` to
`023160` octal), DRM MRES residency rises 17 words (124 to 141);
zero added persistent data words. General provider cancellation,
clock-inhibited callers and transitive no-allocation teardown are
not proved; production OOM termination remains OFF.

## 2026-11-03 v1078: fatal FILE owner does not wait on a foreign provider

`test-daimos-provider-fatal-contention-v1078` extracts the real PDP-6
serialized provider gateway and verifies an owner in fatal FILE cleanup
returns `-5` *without waiting, dispatching or releasing a foreign-held
lease*. Ordinary foreign callers still wait and retry; a free provider
still executes even for a fatal caller, and self-recursion refuses.
The test checks the 7-AC private frame/stack restoration and negative
provider/result witnesses. **PASS**. The original v1077 gateway fails
the same test as a deliberate negative control.

The newly used resident `file_table` symbol is provided as a null
fixture by earlier isolated gateway tests. Missing historical current
slot/event/refusal stubs in the v428 interleave and v466 rename
fixtures have been supplied only in the testkit. Native target suites
v326, v327, v866, v915, v916, v917, v428, v681 and v466 all PASS;
static source/ownership guards v325, v954, v986 and v987 PASS.

The full 256K PDP-6 physical-OOM v1077 combined D6FS/MM regression
also PASSes on the updated kernel, counting exactly 3/2 FILE
attempts/refusals and 2/1 u-area MM releases/refusals; the requester
alone exits, the independent PIPE witness resumes and MM accounting
recovers (`<KWP`, controlled HALT). KCORE low end advances six code
words (`023151` to `023157` octal), without new resident data or ABI.
Actual active-provider cancellation and transitive no-allocation
proof remain unresolved. Production OOM termination remains disabled.

## 2026-11-03 v1077: full-guest OOM with D6FS and MM fault injection

`test-daimos-oom-requester-provider-mm-v1077` builds a disposable 256K
PDP-6 image with the existing BRK OOM branch test-enabled. The requester
holds an actual D6FS `/SYSTEM/INIT` descriptor across physical OOM.
Test-only faults reject two real D6FS SYNC requests; the FILE/VFS
boundary counts 3 close attempts and 2 refusals. The u-area release
then returns MM_BUSY once; the existing idle finalizer succeeds on its
second MM free attempt. Actual counters: 3/2 and 2/1.

The parent verifies the requester-only OOM exit status, unblocks and
reaps a separate PIPE child and confirms restored process-memory
accounting. Guest `<KWP`, controlled HALT: **PASS**. No production code
or resident RAM changed. Indefinite provider refusal and full
allocation-free fatal cleanup remain open.

## 2026-11-03 v1075: full-guest physical OOM requester and negative control

New native 256K PDP-6 fixture `daimos-oom-requester-live-v1075.sh`
enables the existing BRK OOM branch only inside a disposable kernel
source copy. It validates a real memory shortage with an exit-status-1
requester, a separately PIPE-blocked child that survives, resumes and
exits, and process memory accounting restored to its baseline.
Full-guest output `<KWP` with HALT: PASS. A separate disposable build
with production's default-OFF branch returns from BRK instead,
then exits normally. The parent reaps it, releases the PIPE witness
and verifies restored process accounting (`<DNWP`): PASS. Targets are
`test-daimos-oom-requester-live-v1075` and
`test-daimos-oom-requester-disabled-v1075`.

This closes the successful physical-OOM requester/other-process-safety
test only. No production kernel code, OOM default or permanent RAM was
changed. Stalled providers, fatal FILE/HUP/MM refusal and transitive
allocation-freedom remain unaccepted for production OOM termination.

## 2026-11-03 v1070: compiler and assembler closeout regressions

The full ~/git branch consolidation integrated the KCC compiler
fixes from its former 15-commit development branch, and the DAS DXR2
ST2 validation from its historical metadata branch. Their former
branch tips are ancestors of current main in their respective repos;
obsolete remote references have been deleted.

Testkit now provides two host-side reproducible checks:

* `test-dxr2-st2-v1070`: compiles the current DAS checker with warnings
  as errors, and validates seven hand-constructed 36-bit DXR2 headers.
  ST2 minimum and maximum stack reservations pass; out-of-range and
  PURE ST2 headers are rejected; TX2 remains accepted with an in-range
  text prefix and rejects an overlong text prefix. All seven passed.
* `test-kcc-excluded-long-directive-v1070`: runs the built host KCC on
  a program containing a long unknown directive in an excluded
  conditional. It must generate the retained function without an
  internal compiler failure. The v1070 test passed against the merged
  15-commit KCC compiler. KCC still emits an ordinary warning for the
  unrecognized directive; this is not an internal compiler error.

The current GCC stack-byte boundary regression also compiles with
the expected 9-bit word-aligned LDB address. The new SIMH DCS readiness
source builds with -Werror and passes GO/PC plus console smoke tests,
but a live network-backed DCS queue saturation test was not run.
The repaired pdp10-tools runner passes the native PDP-6 FILE target.
These validations are not 32K boot or KCORE optimization tests.

## 2026-11-03 v1064: classify last startup-snapshot test branch

All independent testkit changes on the historical v72 startup branch
were checked before folding its original commits into main ancestry.
The v101 swap-dependency check was recovered as a passing v1063 target
and revealed four missing outer boot Makefile prerequisites, now fixed.
The old FILE test's extra mount-extension storage was also needed by
the modern native runtime: v1064 reserves and initializes those words.
The native FILE target passes without warnings.

Other v72 tests depend on removed startup snapshot or optional SYSINFO
MRES APIs, an obsolete FILE service-jump ABI, or old 48K media layouts;
they are preserved as historical commits, not activated. The current
native PDP-6 VFS parent-AC3 v1037 regression passes; MonitorFS GCC
reader v1033 selection passes with KCC and GCC kernel configurations.
`tests/archive/startup-snapshot-history-v1064/README-v1064.md` records
the boundaries and original tip SHA. No 32K-specific tests were run.

## 2026-11-03 v1063: recover swap composition build-graph check

The October v101 startup-snapshot branch included a host-only check
that compared `proc_swap.s` direct source prerequisites in the inner
kernel Makefile against the outer boot Makefile's `KERNEL_INPUTS`.
The recovered check still applied to current code. Before the fix it
identified four missing outer inputs: the PURE backing assembly,
storage-runtime assembly, PURE attach C source, and storage-map header.

DAIMOS main now tracks all four in its outer Makefile. Testkit target
`test-daimos-kcore-swap-input-deps-v1063` passes against the repaired
source with five composite `proc/` prerequisites; the same test
correctly fails against the original unfixed main source with the four
specific missing filenames. The test uses Python's standard library
and has no PDP-6 boot, KCORE sizing, or 32K requirements.

## 2026-11-03 v1062: integrate historical test archives into main ancestry

The previous grouped-D6CODEC and legacy DSH/SUPERVISOR test archives
have no uncommitted work. Their original branch tips are now retained
as ancestors of testkit main using history-only `ours` merges, and
their two archive descriptions have been added to the main tree:

- `tests/validation/D6CODEC-GROUPED-ARCHIVE-v1027.md`
- `tests/validation/LEGACY-DSH-SUPERVISOR-ARCHIVE-V1049.md`

Original archived tips before ancestry merges: `e1bdb96` (D6CODEC)
and `d924203` (DSH/SUPERVISOR). Their unaccepted experimental code
and historical test results are preserved through Git ancestry only,
not introduced to current active test targets. The independent
`test-daimos-startup-snapshot-v72-20261020` branch remains deferred
with the corresponding KCORE startup work. No 32K tests were run.

## 2026-11-03 v1060: restore native PURE swap test integrity

The original `swap-pure-target-completion-v156-20261015` branch
identified a serious target-test false-positive risk: an uninitialized
result word was zero in BSS and could satisfy `--expect ...=0` without
the test function reaching its final return. The current target now
initializes the result to a nonzero all-ones sentinel; `_start` stores
zero only after the target function successfully completes.

The production swap assembly has since acquired additional exchange
services. The target now links the unmodified production PURE swap
out/in transaction bodies and the real backing-store bitmap verifier,
without pulling unrelated two-process exchange code into the fixture.
It supplies `proc_current_slot=0` (the standalone test's slot-zero
executive) while swapping slot one. No production kernel code changed.

The test also follows current PURE ownership semantics: a resident
restored process retains executable backing until `proc_swap_detach`;
after detach the backing and mount are no longer busy. It verifies
this transition instead of expecting backing to disappear at swap-in.

`make target-swap-pure-text-pdp6` now passes both real native PDP-6
cases: normal raw/compressed PURE suffix swapping and the deliberate
PURE integrity assertion. Both also pass with
`EXTRA_TEST_FLAGS=-DTEST_MOUNT_ID=26U` (the fifth mount-slot bit).
The builds complete without warnings after removing a redundant
target system include path. This is a standalone PDP-6 target
regression, not a 32K boot or KCORE optimization.

The historical v156 and v157 branch reports describe earlier test
configurations and must not be replayed over newer fixture APIs.

## 2026-11-03 v1056: retired Type-340 C fixture

The original migrated C-based Type-340 terminal test no longer built
because current DAIMOS implements the retained Type-342 terminal
in native assembler and no longer contains `dpy_text.c`. The two
historical files were retained unchanged in
`tests/archive/type340-c-obsolete-v1056/`; no default test depends
on them. Current detached-TTY, native-block Type-340, and DPY
interrupt-policy tests pass. This fixes the obsolete test inventory;
it is not a new production display-code change or guest acceptance.

## 2026-11-03 v1055: complete historical v115/v54 artifact recovery

The old SIMH v115 worktree's four otherwise untracked DTFS probes and
scripts are now preserved in `tests/archive/dtfs-v199-v200-unaccepted-v1052/`
with verified SHA-256 hashes. Their scripts contain incomplete single-
phase experiments, not the two-boot persistence acceptance they claim.
The obsolete local v115 branch was deleted after detaching and cleaning
the old worktree; its tracked commits were already reachable from main.

The historical nested-UUO v54 worktree's twelve untracked probes and
modified runtime report are now preserved in the versioned v1053
testkit archive, with verified hashes. Its commits are ancestors of the
retained legacy DSH/SUPERVISOR archive. The obsolete local v54 branch
was deleted after cleaning and detaching its worktree. The existing
media-isolation regression passes, but historical nested-UUO failures
are not claimed fixed by that test.

The native MAKE v1054 lazy scratch source and 256K runtime tests are
accepted separately; peak process RAM and full MAKE ALL self-hosting
remain unmeasured. No 32K-specific test or KCORE optimization ran.

## 2026-11-03 v1054: native MAKE recursion scratch 256K guest check

DAIMOS native MAKE now caches its implicit-rule scratch record lazily
for each recursion depth reached instead of allocating all 33 records
after parsing. The v1054 probe file exercises a six-level dependency
chain and a dependency cycle in a real isolated full-profile 256K
SIMH PDP-6 guest. Both tests passed on the modified KCC MAKE image,
and on an unmodified MAKE control image.

The opt-in testkit target `test-daimos-make-lazy-depth-v1054` requires
`DAIMOS_MAKE_BOOT_INI` pointing to an independently built 256K image
using explicit disk-root selection. It verifies the matching lazy
source-code contract, so an unmodified bulk-allocator binary source
cannot give a false positive. The target passed against the modified
DAIMOS worktree and rejected the unchanged baseline source.

This is a behavior-and-source regression, not a measured process
peak-memory test. No native `MAKE ALL` self-hosting run or 32K test
was performed. Further KCORE optimization remains deferred.

## 2026-11-03 v1050: historical DSH/INIT test archive consolidation

The obsolete source-dependent test histories
`dsh-phase0-history-repair-tests-20261012-v7` and
`supervisor-idle-tty-activate-testkit-20261013-v5` are preserved by
`archive/legacy-dsh-supervisor-tests-v1049-20261103`. Their old
local/remote branch names were removed after verifying both original
commits as archive ancestors. These experimental tests depend on
the discontinued standalone INIT/SUPERVISOR design or DSH lock-based
history repair, and are not presented as current main acceptance.

The historical host-only D6FS bounded-undo model was recompiled and
passed 5,805 append/replay interruption cuts. It assumes per-block
write persistence and is not production journal or disk format code.
The matching source implementations remain in the DAIMOS archive
`archive/legacy-dsh-init-experiments-v1050-20261103`.

The restored standalone SIMH interactive PC regression v1048 and the
existing v155 GO-PC regression both pass. The original v115 local
branch remains attached to a separate dirty DevSpace2 worktree, with
untracked DTFS diagnostics; no removal of that local worktree
or its untracked files was attempted. No 32K tests ran, and KCORE
optimization remains deferred.

## 2026-11-03 v1048: historical PDP-6 console-PC regression restored

The independent `pdp6-simh-console-pc-20261021-v115` branch retained a
standalone SIMH regression missing from main. It checks that typing an
interactive command does not modify the simulated PDP-6 PC (which can
collide with a host terminal library's `PC` symbol), then executes a
breakpoint and single-step sequence with separate PC oracles. The
restored `test-daimos-simh-console-pc-v1048` passes against the
installed PDP-6 simulator. The existing v155 `GO address` PC-first
regression also passes. Neither result involves a DAIMOS guest boot.

The historical v115 branch additionally records several failed or
inconclusive TSFS-root DTFS FSCK/mount diagnostic experiments. Their
probe files are historical evidence, not current accepted test cases;
do not replay those old fixtures into main or imply that DTFS writable
root acceptance was achieved. The v115 history may be retained through
an ancestry-only merge, after extracting the independent PC test.

## 2026-11-03 v1043: recovered standalone compiler and DSH provenance checks

The historical v155 test branch supplied a genuine GCC PDP-6 packed
`char[256]` indexing regression. It builds and executes an independently
initialized local character array at `-O0`, `-O1`, `-O2` and `-Os`.
All four native PDP-6 configurations pass on the installed GCC toolchain.
The historical DTC test changes are already superseded by the current
stronger second-boot native FSCK check; only opt-in artifact retention
(`DTC_TEST_KEEP_LOGS=1`) was recovered, with shell syntax validated but
no new DECtape boot acceptance.

The historical DSH nested-UUO stress branch supplied a useful image
provenance checker. The opt-in helper compares exact DXR image bytes
before attributing any simulator outcome to a DSH build. Its v1043 host
self-test passes for matching, modified and missing image files. This
does not claim a booted nested-process regression or that an installed
DSH image has been independently verified in this pass. The old nested
stress branch and its unaccepted feature tests remain under review.

## 2026-11-01 v891: persistent fatal FILE refusal containment

`daimos-fatal-file-persistent-v891.sh` boots a copied PDP-6 kernel
with a real user APR fault and an isolated VFS-sync hook that always
returns -5 for the victim's FD 0. The victim's private executive
continuation must retain its FILE ownership while retrying; no
automatic OOM victim cleanup or forced provider release is enabled.

The separate user-mode bystander prints `S` every 020 octal ticks;
INIT sleeps 02400 octal ticks, then uses the production
`GETTEARDOWN(pid|0400)` interface to verify live FILE stage, FD 0
and actual error class 5. INIT's final exit is intercepted by a
**test-only HALT** before it could terminate the live victim.

Full-system PDP-6 SIMH PASS: owner 2, one real APR fault,
11 consecutive failed VFS calls / 11 fatal FILE passes / 11 private
timer sleeps, exponential delay through the 01000-octal-tick
(512 decimal) cap, 11 retained FD checks, zero accidental FD or
word-067 witness clears, zero victim exits, bystander progress,
the final user diagnostic and zero assertion failures. The initial
0300-octal-tick short test also PASSed with eight refusals; the
longer 02400-tick end-to-end run replaces it as the acceptance gate.

No production sources or permanent RAM were modified. This proves
bounded retry frequency and non-destructive ownership preservation
under an indefinitely rejecting FILE provider for the observed
run, not eventual reclamation. Malformed MM ownership, provider
repair and safe automatic OOM termination remain separate work.

## 2026-11-01 v890: real destructive EXEC failure in booted PDP-6

`daimos-fatal-exec-integration-v890.c` performs a valid user-mode
`dsys_exec`. Its companion
`daimos-fatal-exec-integration-v890.sh` copies the production
kernel, injects `EXEC_LOAD_NOMEM` only at the selected child's
staged loader, then runs the real low-memory EXEC fallback,
including real `vm_space_destroy`. The temporary kernel
asserts `VM_SPACE_NONE` before injecting a failure of the
replacement loader. Normal `EXEC_REPLACE_FATAL` dispatch
enters the unchanged fatal FILE private-stack loop.

The isolated test's VFS provider rejects FD 0 twice with -5
and accepts the third close. Full-system PDP-6 SIMH PASS:
one staged NOMEM, one actual old-VM destruction, one
post-commit loader rejection, 3 VFS calls, 2 rejected closes,
3 fatal FILE passes, 2 private timer sleeps (1, 2 ticks),
2 retained-FD checks, observed `GETTEARDOWN` FILE stage/
error class 5, one successful FD release, one cleared
u-area word-067 witness, one process exit and parent
`WAIT` status 1. The console prints `<EH`, reaches
normal HALT and reports zero assertion errors.

The native v878/v879 fatal EXEC, v885 FILE backoff, v888
FILE and MM error paths, v887 descriptor diagnostic and
v881 deferred MM release fixtures all PASS. Production
KCORE is unchanged at `022124` octal = 9,300 words
and adds no static RAM. The post-commit EXEC test is a
transient-provider recovery demonstration, not proof of
safe recovery from indefinite resource refusal.

## 2026-11-01 v889: true full-system APR fatal FILE recovery

`daimos-fatal-file-integration-v889.sh` compiles a disposable
kernel/image with temporary test hooks in CLK PI6, FILE, VFS
and process sleep/EXIT code. Its user program genuinely faults
by reading outside the APR-mapped virtual range. The real PI6
APR-fault trampoline enters the normal private-stack fatal
cleanup, rather than the test directly calling a standalone
assembly leaf or manufacturing an EXEC fatal return.

Only the faulting process's FD 0 receives two test-only VFS-sync
returns of -5 before the real VFS entry proceeds normally.
SIMH full-system PASS: owner slot 2, one APR fault, three VFS
calls and two rejections, three fatal close passes, two timer
sleeps of 1 and 2 ticks, FD 0 retained after both refusals,
stage FILE and ERR 5 from production GETTEARDOWN, FD and
word-067 witness cleared after provider success, exactly
one process exit, matching parent WAIT fault status, CTY
`<FH`, final HALT, and zero error counters.

The KCORE production tree is untouched; test-specific data
exists only under `$TMPDIR`. The native v888 actual FILE
error/real MM error, v885 fatal-close backoff, v878/v879 fatal
EXEC, and v887 teardown-detail regressions PASS. KCORE remains
`022124` octal (9,300 words) with no added resident data.
Unrecoverable providers and booted post-commit EXEC failures
are separate future tests; automatic OOM killing remains off.

## 2026-11-01 v888: actual fatal FILE provider rejection

`daimos-file-provider-error-v888.sh` directly executes current
PDP-6 `file_close_all_at_v865` and
`proc_control_getteardown_v886` with mocked provider outcomes.
The first fatal pass fails two FILE entries; it records the
first actual negative return -5 and its FD without clearing
either rejected descriptor. A second pass replaces this with
-2 and clears the other descriptor. The third pass completes
and clears the word-067 witness and all descriptors. A later
failure on FD 3 with -4 proves correct nonzero FD capture.
A nonfatal bulk-close pass is not allowed to touch word 067.
All cases PASS; pre-v888 code FAILs this negative control.
The extended test also validates that FD 3, rather than FD 0,
is recorded when it alone rejects close with -4.

`daimos-mm-release-cause-v888.sh` executes real PDP-6
`mm_free`, `mm_unpin` and the matching extent-detail reader.
It verifies MM_ERR_BUSY (-5) on pinned u-area without loss of
ownership; MM_ERR_INVAL (-4) on missing, wrong-type and
wrong-owner extents; and successful release after a legitimate
unpin. PASS.

The full-system session teardown regression PASSes with the
updated FILE runtime: leader exit, running/stopped job HUP,
TTY detach and subsequent reattach. This is not a full-system
test of an injected private-stack FILE provider rejection;
that separate acceptance is still open.

Existing v887/v886 detail and dispatcher, v885 fatal
FILE backoff, v879 fatal close and v883 external HUP
regressions PASS unchanged. The production `ps` now adds
a numeric `ERR` column: 0 means no recorded rejection,
1..5 map to actual -1..-5 provider returns, and 6 means
other nonzero return. Original error and first FD reside
only in the owned u-area word 067, never static storage.

KCORE link PASS at `022124` octal, 9,300 resident words,
+26 over v887 and no new permanent data. This tests
native provider-error attribution and nonfatal scanning,
not guaranteed recovery from a permanently refusing provider.
OOM victim termination remains disabled.

## 2026-11-01 v887: on-demand FILE and MM ownership snapshots

`daimos-teardown-detail-v887.sh` invokes the production PDP-6
teardown query with PID detail bit 0400. It checks ordinary and
invalid slots, FILE descriptor count and first remaining FD,
PIPE and DPY provider classes, later first-FD selection following
a successful close, plus the original non-detail FILE/zero-MM
query contract. The native test also executes the real
`mm_find_base` and `mm_uarea_probe_v887` assembler routines
with an exact u-area extent: 2 physical pins, zero after an
unpin, missing extent, wrong type and wrong owner. PASS.

Existing v886 native leaf and dispatch tests PASS without
changing their expected ABI. The disposable full-system
`daimos-teardown-detail-full-v887.sh` compiles a user-mode
query of an ordinary and invalid PID and injects a read-only
detail snapshot into the real post-VM MM_BUSY path. A pin
must still exist, and successful unpin/reaping/HUP must complete.
The full-system PDP-6 guest PASSes: detail stage 2 reports
exactly one live MM pin (octal 06), two actual MM_ERR_BUSY
releases followed by successful unpin/reaping, two slot-0
reaper passes with another process runnable, and normal
PIPE/HUP/TTY shutdown. The pre-v887 source FAILs the native
negative control as expected. The `ps` DETAIL column also
compiles with the target PDP-6 C compiler.
Production KCORE links at `022072` octal (9,274 words),
+72 versus v886, no new permanent data.

## 2026-10-31 v886: read-only process teardown diagnosis

`daimos-teardown-query-v886.sh` executes the compiled production
PDP-6 `proc_control_getteardown_v886` leaf, including invalid/0/
FREE rejection, normal and zombie stage zero, fatal FILE stage
one, and deferred MM stage two with actual shared 020- and
01000-octal-tick retry values. A stale finalizer marker without
VM_SPACE_NONE or TRANSITION is not misreported. Native test PASS.

`daimos-teardown-query-full-v886.sh` uses the disposable
full-system MM pin/unpin integration image to check the real
`dsys_procctl(GETTEARDOWN,pid)` UUO route from user mode and
read back the MM-pending stage and shared delay while the
process remains quarantined. The test retains the continuously
runnable companion, two real MM_ERR_BUSY responses and eventual
ordinary session HUP/TTY finalization. All instrumentation stays
under `$TMPDIR`, not in production KCORE.

The operator-facing `ps` utility now exposes TD and RETRY
columns and compiles with the target PDP-6 C compiler.
KCORE link PASS at `021762` octal (9,202 words), +37 over
v885 and no new permanent data. Automatic OOM killing stays off.
The first full-system attempt exposed an important ABI collision:
op 020 was already the PIPE extension. The corrected op 041 is
forwarded to PROCCTL; the full dispatcher native fixture PASSes
and the old reserved-op negative control FAILs as expected.
The final rebuilt full-system v886 test PASSes. User-mode
`dsys_procctl` returns stage NONE for an ordinary process and
-1 for invalid PID, and temporary in-kernel witnesses read
MM-pending stage 2 with 020-octal retry ticks while the extent
is genuinely pinned. Two MM_ERR_BUSY results, one pin/unpin
pair, two reaper passes with a nonempty run queue, normal
PIPE/HUP/TTY processing and final HALT are all accepted.

## 2026-10-31 v885: bounded retries under permanently failing providers

`daimos-fatal-close-backoff-v885.sh` invokes the production PDP-6
APR/EXEC fatal FILE cleanup with 14 rejected FILE provider calls,
then a successful close. It checks the exact sleep sequence from
1 to the 01000-octal-tick (512) cap, exit-status stack ownership,
duplicate-fatal-event exclusion, and successful finalization: PASS.
The pre-v885 constant-tick source FAILs the negative control.

`daimos-reaper-backoff-v885.sh` executes the production compact
shared MM interval updater and first-u-area-defer path, verifying
repeated doubling to the 01000 cap, retention over permanent
failure, clearing on successful release, resetting the delay for
one newly pending owner, and retaining backoff for the same owner:
PASS. The v884 scheduler's real 17-bit timer gate now uses this
variable interval; prior runnable-user, RT, disk-swap, timeout,
v879 fatal owner, v881 finalizer, v883 fatal HUP and v880 backing
rollback tests PASS.

The disposable full-system PDP-6 guest with a separate nonstop
spinner and genuine pinned-u-area MM_BUSY twice still reaches
normal HUP/TTY completion and HALT: PASS. All resource fault
injection stays in testkit; production KCORE link ends at
`021715` octal (9,165 resident words), +30 over v884 and no
new permanent data. The bounded retry *interval* is not bounded
resource reclamation: permanently rejecting providers continue
to retain their descriptors. Automatic OOM termination stays off.

## 2026-10-31 v884: deferred MM reaper runs despite a spinner

`daimos-reaper-sched-v884.sh` executes the native production
`proc_sched_tick_select`: ordinary dispatch before the throttle,
one slot-0 maintenance turn after 020 octal ticks with pending
cleanup, no maintenance when not pending, 17-bit clock wrap, and
preservation of runnable RT and pending disk-swap priority PASS.
An RT lease retained by a sleeping job does not block maintenance:
PASS. Against pre-v884 code, the scheduler fixture FAILs as
expected, proving it detects the original starvation.

`daimos-reaper-fair-v884.sh` builds a disposable PDP-6 guest with
the production MM operations. A second user process spins without
sleeping while a different process is terminated by non-current
HUP. A real MM pin causes two `MM_ERR_BUSY` frees before unpin.
An idle-service test-only counter records reaper execution with a
nonempty runnable queue: 2 observations. The guest completes HUP
delivery, zombie WAIT, kills and waits for the spinner, and
completes its TTY detach/reattach scenario and normal HALT: PASS.
Three release attempts, one pin/unpin and zero test errors were
recorded. All fault injection remains in the testkit-generated
`$TMPDIR` kernel; no production instrumentation was committed.

Previous native VM-less executive, v881 deferred u-area finalizer,
v883 non-current HUP and other teardown regressions PASS. The
production KCORE lowmem link PASS at `021657` octal (9,135 words),
39 words above v883, with no new persistent data. Real-time
indefinite running and permanent provider refusal still require
explicit policy before OOM killing can be enabled.

## 2026-10-31 v883: non-current fatal HUP commit contract

`daimos-noncurrent-fatal-v883.sh` extracts and executes production
PDP-6 `proc_event_apply`, `proc_finish_slot` and idle reaper code.
The non-current target has no live FILE entries; its VM destruction
succeeds and first/second u-area releases fail. Before that, the
fixture injects a VM-destroy error and confirms it is reported as
uncommitted, with TRANSITION rolled back and no u-area release.
The subsequent HUP must
return success (irreversible delivery committed), duplicate HUP must
be refused, and later slot-0 finalization must preserve fatal status
and publish ZOMB/notify parent exactly once. Native test PASS;
unmodified pre-v883 source FAILs the new negative control.
Older v865/v867/v868 FILE/EXIT, v869/v876 finalizer, v879 owner
close and v880 backing-detach native tests PASS.

The v882 full-system pinned-current-EXIT test remains accepted. The
new `daimos-noncurrent-uarea-pin-v883.sh` full-system test PASSes
independently: a non-current HUP target is pinned through real MM,
two releases return MM_ERR_BUSY, the third succeeds after unpin,
and the original session HUP/TTY completion reaches normal HALT.
Guest counters: slot 2, 3 releases, 2 busy, 1 pin, 1 unpin, no
instrumentation error. Re-running the v882 current-EXIT test on
the new code also PASSes. Both temporary kernels are generated
without production fault-injection hooks.
KCORE link PASS at `021610` octal (9,096 resident words), +17
text words above v882, no new permanent data. OOM remains disabled.

## 2026-10-31 v882: full-system real MM_BUSY and deferred release

`daimos-uarea-pin-integration-v882.sh` creates a disposable,
source-instrumented PDP-6 kernel from the production sources and
boots the unchanged session teardown test userland. The temporary
hooks select the first process entering its own `proc_exit_finish`,
pin that stable kernel u-area through real `mm_pin`, observe two
real `MM_ERR_BUSY` results from `mm_free`, and unpin before the
third attempt. After the final normal guest HALT, SIMH inspects
exported test-only counters. Observed: slot 1/2 across runs,
3 attempts, 1 pin,
2 busy, 1 unpin, 0 hook errors, full session HUP/TTY completion:
PASS. All injected assembly and C code stays under `$TMPDIR`;
the DAIMOS production kernel is not altered.

First-encountered non-current victim slot 3 gave a different
failure contract: its caller received a transient error before
the expected synchronous session conclusion. This route remains
unaccepted for full-system fault injection. Other open gates:
sustained runnable-process progress, irrecoverable MM errors,
and automatic OOM victim killing.

## 2026-10-31 v881: post-VM u-area release retry

`daimos-deferred-uarea-v881.sh` runs production PDP-6
`proc_finish_slot` and the new idle finalizer service, rejecting two
MM u-area releases before successful retry. It confirms intact
TRANSITION/VM_NONE ownership, original exit status, unchanged session
control, no repeated HUP/VM/TTY teardown, and exactly one final
run-queue removal, child adoption and parent notification: PASS.
Unrelated transitioning jobs are not accepted as pending.

`daimos-exit-deferred-v881.sh` compiles the production KCC
`proc_exit_finish` and executes its native PDP-6 leaf: deferred
release returns to slot-0 idle, other errors remain failures, and
successful EXIT preserves the existing live-user return: PASS.
Older v869/v876 finalizer and v879/v880 fatal-close/VM tests PASS.
The marker/status occupy preallocated u-area word 067; session ID
bits remain intact. Only one new permanent retry-clock word is
allocated. KCORE lowmem link PASS at `021567` octal (9,079 words;
+100 above v880).

Still open: full-system failure injection with MM pinned u-area,
PI6 fairness under sustained load, permanently failing MM providers
and automatic OOM victim termination.
The normal full-system session HUP/TTY regression also PASSes on
v881; it is not an injected MM-busy finalizer test.

## 2026-10-31 v880: disk-swap detach retains ownership on failure

The native PDP-6 `daimos-swap-detach-v880.sh` runs the production
`vm_space_destroy` assembly, injecting a rejected backing detach.
It verifies unchanged VM state and retained retry ownership, followed
by successful detach and VM_SPACE_NONE publication: PASS. Its
pre-v880 negative control FAILs as expected. The actual C
`proc_swap_detach` is compiled and tested by
`daimos-swap-detach-state-v880.sh`: incomplete bitmap, invalid
range, count underflow and zero count must not clear the record or
counters; a valid retry releases once and repeat detach is a no-op:
PASS. Existing backstore verify and free regression tests PASS.

The verifier is installed through the existing SWAP MRES at new
export index 6; KCORE uses one patchable default-error entry. The
actual SWAP MRES link PASSes and contains the verifier export.
Lowmem KCORE link PASS at `021423` octal (8,979 words), +16
resident words over v879; no new persistent table. Post-VM u-area
MM-free rejection and full-system OOM acceptance remain open.
The full-system normal session/HUP/TTY regression also PASSes with
the v880 SWAP verifier export installed. This does not exercise
live backing corruption or persistent cleanup failure.

## 2026-10-31 v879: process-owned APR/EXEC fatal FILE retry

`daimos-fatal-close-retry-v879.sh` executes the real PDP-6
owner-stack fatal-close continuation, injecting two rejected closes
and verifying one-tick yields, retained FILE status and exit code,
duplicate fatal-event exclusion, final successful closure and no
unnecessary yield: PASS. `daimos-vmless-fatal-v879.sh` verifies that
a tagged fatal-cleanup continuation without a user VM is schedulable,
including RT ownership, while an ordinary VM-less job is not; its
executive restore skips APR activation instead of loading
VM_SPACE_NONE: PASS. The additional v879 native selector and
restore fixtures cover VM_SPACE_NONE (-1), tagless refusal, RT and
ready-once behavior, genuine zero-base swapped admission, and
unchanged APR restoration: PASS.

The new native direct swap-out guard tests tagged fatal-cleanup
ownership, user-map hold, VM transition and ordinary admission:
PASS. It FAILs against pre-v879 code as expected, demonstrating
the absent exclusion. Both native swap-out and exchange admission
now check the existing fatal-cleanup bit.

The updated v878 EXEC test runs the real common retry routine and
checks failed-release recovery. Updated v865/v867/v868 event fixtures,
v863/v866 OOM selection (including rejecting an active cleanup
owner), and v875/v876 teardown regressions PASS. Lowmem KCORE link
PASS, exclusive end `021403` octal (8,963 words, +108 resident text
words from v878 and no extra permanent data). Real full-system PI6/clock
sleep and actual blocked provider-failure injection are not yet
accepted. Persistent errors may cause indefinite repeated retries,
so do not claim OOM victim termination safety.

The final v879 ordinary full-system session-leader HUP/TTY regression
`daimos-session-teardown-v1.sh` also PASSes in headless mode. It does
not inject a failing FILE provider into the new private-stack retry.

## 2026-10-31 v878: post-commit fatal EXEC closes FILE descriptors

Native PDP-6 `daimos-exec-fatal-close-v878.sh` extracts and executes
the production `native_sys_exec` entry. For `EXEC_REPLACE_FATAL` it
checks `file_close_all` runs before the nonreturning exit, that
successful close clears a live descriptor, and that a failed close
retains it. Pre-commit error, successful replacement and mapping
failure must not attempt the fatal cleanup: PASS. Pre-v878 code FAILs
the new test at its missing-close check, as expected. Native v867,
v868, v869, v875, v876 regressions PASS. Lowmem KCORE link PASS,
exclusive end `021227` octal. Persistent provider failures and
full-system EXEC-fatal injection remain unverified; no OOM kill.

## 2026-10-31 v877: full-system session teardown PASS on v876 kernel

The post-v876 `daimos-session-teardown-v1.sh` headless guest PASSes:
leader exit delivers HUP to running/stopped session members, detaches
the TTY and permits reattachment. The isolated CTY guest disables
unrelated WCNSLS/OCNSLS graphics, avoiding the prior pre-INIT SDL
crash (exit 139). This is a valid ordinary session-lifecycle
regression, not a full-system injected-MM-failure or OOM-kill test.
Native failed-HUP/VM and RT owner tests PASS separately. The v877
checkpoint changes only documentation.

## 2026-10-31 v876: RT ownership and finalizer transition safety

Native PDP-6 `daimos-finish-rt-v876.sh` executes the real resident
finalizer. A slot already TRANSITIONing is rejected. While HUP runs,
the target is unschedulable and retains its RT lease; failed HUP and
failed VM destroy restore scheduling eligibility without losing RT
ownership. Successful VM destruction commits RT revocation and normal
zombie publication. Native v876 PASS; pre-v876 source FAILs as an
expected negative control. KCORE link PASS at `021226` octal.

The existing full-system session-teardown regression PASSed after
isolating its CTY workload from unrelated SDL color-scope devices.
The original environment run had exited 139 in SDL before INIT; it
was not a session HUP result. A post-v876 rerun also PASSed; see v877.
No OOM kill has been enabled.

## 2026-10-31 v875: session HUP failure leaves controlling TTY intact

The native PDP-6 `daimos-session-hup-v875.sh` runs the real resident
session teardown. A failed second member HUP preserves the original
controlling-TTY state, and a successful retry commits the route-only
TTY record. Nonleader and non-attached leader paths also PASS. The same
test FAILs against pre-v875 source, demonstrating the early-detach
regression. Lowmem KCORE link PASS at `021222` octal (+4 words).
This native test does not establish full-system session teardown,
nonreturning APR/EXEC resource recovery, or OOM kill acceptance.

## 2026-10-31 v874: DPY replacement rollback and negative control

Native PDP-6 testkit `daimos-dpy-replace-v874.sh` executes the real
Type 340 replacement service. Fault-injected old-extent MM free failure
retains the old program/IOWD and releases the unpublished new extent;
recovery, successful replacement, allocation failure, stop and initial
install PASS. The same fixture FAILs against pre-v870 source, as
expected. Updated v709 gateway checks, v871 final close, v870 PIPE and
Type 340 PI policy also PASS. DPY MRES assembler/link and lowmem KCORE
link PASS. No full-system post-failure replay PASS is claimed.
The unrelated named-FIFO full-system timeout remains open from v873.

## 2026-10-31 v873: named-FIFO full-system baseline comparison

The existing KCC `daimos-pipe-fifo-v2.sh` full-system test times out
with exit 124 after D6FS startup on current v871. A controlled run
against detached pre-v870 v869 commit `8b4e7d9` also reaches D6FS
startup and times out without the final marker. This is not yet a
diagnosed root cause or an accepted full-system test. The native v870
failed-MM-free fixture FAILs on v869 as an expected negative control,
and PASSes on v870/v871. No userland workload or kernel source was
changed for this comparison.

## 2026-10-31 v872: FILE/PIPE/DPY native regression linkage

The v871 DPY-close default changed from `kret_neg1` to `kret_zero` for an
absent display module. The v865, v867, v868 and v870 isolated native
fixtures link the real FILE close leaf and must now define both return
stubs. All four were corrected; v865, v867, v868, v870 and v871 native
tests PASS together. The v709 DPY gateway tests and Type 340 PI policy
also PASS. The v870 full-system opaque-word PIPE regression PASSES.
The separate named-FIFO full-system test timed out after D6FS startup;
its pre-v870 baseline comparison is outstanding and it is not counted
as an accepted regression. No production kernel change in v872.

## 2026-10-12 P10FOLD I/O SKIP AND MULTI-TTY REGRESSION

- `test-daimos-p10fold-io-skip-20261012-v1` protects the PDP-6 BLKI,
  BLKO, CONSZ, CONSO and XCT skip/fall-through boundaries, with a genuine
  non-skipping fold as a positive control. Included in the `target` matrix.
- `test-daimos-userspace-multitty` passes under GCC and KCC after fixing
  P10FOLD's unsafe GE polling-loop fold. Its process census now excludes
  the one transient PS process, but still checks persistent process slots,
  words and file counts after repeated login cycles.
- The GCC/KCC compiler selection test passes under both compiler choices.
  DSH size acceptance remains unchanged and deferred.

# 2026-10-12 GCC/KCC COMPILER SELECTION

THE TESTKIT ACCEPTS `COMPILER=gcc` OR `COMPILER=kcc` (DEFAULT). THE
SELECTION IS EXPORTED THROUGH THE REGRESSION RUNNER TO DAIMOS KERNEL
COMPILATION, WITH SEPARATE TESTKIT BUILD ROOTS AND REGRESSION CHECKPOINTS.
HOST UTILITIES CONTINUE TO USE HOST_CC. BOTH `MAKE CHECK` VARIANTS PASS,
AS DO THE DIRECT GCC BACKSTORE PROBE AND KCC SIX-ARGUMENT CHAR PROBE.
THIS VALIDATES SELECTION, NOT THE ENTIRE TWO-COMPILER REGRESSION MATRIX.
KCC-SPECIFIC CODEGEN PROBES CONTINUE TO EXPLICITLY TEST KCC.

# DAIMOS TESTKIT STATUS

DATE: 2026-10-06

STATUS.MD IS THE SOLE CURRENT-STATE DOCUMENT.  README.MD DESCRIBES STABLE
PROJECT USAGE; TODO.MD CONTAINS ONLY OPEN TESTKIT WORK.  HISTORICAL CHECKPOINTS
BELONG IN GIT HISTORY.

## PURPOSE

DAIMOS TESTKIT CONTAINS DAIMOS-SPECIFIC TARGET, SYSTEM, VALIDATION, BOOT,
DEVICE, FILESYSTEM, AND RUNTIME TESTS.  GENERIC COMPILER, ASSEMBLER, ABI, AND
TOOLCHAIN TESTS BELONG IN PDP10-TESTKIT.

## CURRENT TEST INVENTORY

THE CURRENT TREE COVERS:

- DIRECT PDP-6 TARGET TESTS FOR DAIMOS MEMFS AND FILE INTERFACES;
- HOST MEMORY-MANAGER, PROCESS, COMPACTION, SWAP, PIN/HOLD, AND FAILURE PATHS;
- PDP-6 KERNEL IMAGE, DEVICE, AND STANDALONE BOOT INTEGRATION;
- D6FS RUNTIME, MULTIMEMBER, RECOVERY, BADMAP, LOGSTORE, AND RESIDENT SIZE;
- DTFS/TSFS NATIVE, TENEX, AND ITS TARGET/RESIDENT/RUNTIME PATHS;
- PROCESS, PROCESS-GROUP, SESSION, DOMAIN, EVENT, TTY, PIPE/FIFO, RUN, EXEC,
  STACK-WATERMARK, SCHEDULER, RT, AND RT_REQUIRED VALIDATION;
- PDP-6 APR USER PROTECTION, NXM, AND PUSHDOWN-OVERFLOW FAULT DELIVERY ON SIMH,
  PLUS A FOCUSED PRODUCTION-CLK-MRES EXECUTION TEST ON THE AAP PDP-6 EMULATOR;
- DSK270, DRM236, DTC, MTC516, MONITORFS, DISKSET, AND STORAGE ACCOUNTING;
- PRIVILEGED REALTIME `/DEV/WCNSLS` RAW DATAI/CONO/DATAO USERSPACE ACCESS;
- COMPRESSED DSK/DRM/DTC/PTR/MTC STAGE1 LOADERS;
- DSK/D6FS, DRM/D6FS, AND DTC/TSFS EXPLICIT ROOT CLASSES;
- AUTO ROOT PRIORITY DSK -> DTC -> DRM;
- THE SUPPORTED INDEPENDENT BOOT-SOURCE/ROOT-CLASS CROSS-MATRIX;
- ROOT LOGIN/LOGOUT/RESPAWN LIFECYCLE COVERAGE;
- REAL PDP-6 SIMH RUNTIME PROBES AND DTFS PERSISTENCE PHASES;
- DAIMOS-SPECIFIC PDP10-TOOLS INTEGRATION.

THE MAIN RUNTIME PROBE FILE CURRENTLY CONTAINS 60 PROBES.  INIT MULTICALL
COVERAGE CURRENTLY REQUIRES ALL 27 COMMANDS.  THE DTFS NATIVE PERSISTENCE SUITE
USES SIX PHASE FILES AND 142 PROBES.

## HARNESS AND BUILD ASSUMPTIONS

THE INTERACTIVE SIMH HARNESS USES TOOLS/PTY-RUN-V1.C AND A PERSISTENT FIFO;
PYTHON, PEXPECT, AND TCL EXPECT ARE NOT REQUIRED.  PROBES SUPPORT TEXT/REGEX/
LINE ASSERTIONS, PER-PROBE TIMEOUTS, AND DSH, SIMH, OR EOF TERMINATION.

THE TOP-LEVEL MAKEFILE CURRENTLY REQUIRES GNU MAKE.  PDP10_PREFIX, DAIMOS_REPO,
AND TMPDIR ARE REQUIRED BY THE MAIN TARGET AND SIMULATOR PATHS.  THE AAP APR
REGRESSION ALSO USES AAP_PDP6_REPO (DEFAULT `../pdp6`).  HOST HELPERS ARE BUILT
AS C99.

## CURRENT DAIMOS COMPATIBILITY

THE COUNTED-SIXBIT RUN/EXEC AND CURRENT PROCESS U-AREA CONTRACTS ARE ALREADY
REFLECTED BY THE LANDED PROCESS/LOGIN TESTS.  THE FORMER SYS_RUN_V1 AND STACK-
OFFSET REBASE ITEMS ARE NOT CURRENT OPEN FAILURES.

THE CURRENT SOURCE-WIDE SIXBIT CONSTANT INTERFACE IS PDP10_SIX6.  THE TESTKIT
REBASE NOW USES ONE SHARED TEST-SIDE SIXBIT HELPER AND NO LONGER REFERENCES THE
REMOVED VFS_SIX6 COMPATIBILITY MACRO.  THE HOST MM AND DIRECT PDP-6 TARGET
TESTS PASS THIS REBASED INTERFACE.

THE HOST MM REGRESSION LOCKS SWAP BACKING LIFETIME, SLOT-0 RESTORE,
FRAGMENTED RECLAIM, MAPPING-HOLD/PINNED ISLANDS, FAILURE CLEANUP, AND
BACKING-AWARE VICTIM SELECTION.  A DIRECT PDP-6 TARGET REGRESSION COVERS
RAW AND D6LZ36 PURE-TEXT SUFFIX SWAP, NON-PURE WHOLE-IMAGE SWAP, EXECUTABLE
VNODE/MOUNT PINNING, AND THE PROC_SWAP_VERIFY_PURE ASSERTION PATH.  REAL 32K
SWAP-WAIT AND SWAP-STRESS REGRESSIONS COVER SWAPPED/BLOCKED/STOPPED PROCESS
PATHS.

## BOOT, ROOT, AND LOGIN ACCEPTANCE

DIRECT D6LZ36 LOAD/DECODE ACCEPTANCE EXISTS FOR DSK, DRM, DTC, PTR, AND MTC.
EXPLICIT ROOT-CLASS TESTS EXIST FOR DSK/D6FS, DRM/D6FS, AND DTC/TSFS.  AUTO
ROOT PRIORITY IS TESTED WITH DISTINCT VALID ROOTS.  THE INDEPENDENT BOOT-SOURCE/
ROOT-CLASS CROSS-MATRIX AND ROOT LOGIN-LIFECYCLE TESTS ARE LANDED.

THESE TESTS REMAIN PERMANENT ACCEPTANCE COVERAGE, BUT THE PRE-DSH GATE IS NOT
CLOSED UNTIL THE TOP-LEVEL SERIAL REGRESSION REACHES AND PASSES THEM IN ONE
COMPLETE RUN.

## FILESYSTEM AND TOOL COVERAGE

D6FS HAS ONE CURRENT TOP-LEVEL RESIDENT-SIZE TARGET.  DTFS-MRES-V3 IS THE SOLE
AUTHORITATIVE DTFS RESIDENT-SIZE REGRESSION.  THE CURRENT DAIMOS BUILD ALWAYS
INCLUDES NATIVE, TENEX, AND ITS DECtape PERSONALITIES; TEST-SIDE DTFS_TENEX OR
DTFS_ITS OVERRIDES ARE LEGACY SPELLINGS AND DO NOT DEFINE THE RELEASE PROFILE.

THE DAIMOS-SPECIFIC HOST-TOOLS SUITE COVERS DBOOT MEMBER LAYOUT, D6FS
CREATION/CHECK/REPAIR/MAINTENANCE, BADMAP D6FS/LOGSTORE/SWAP PRESERVATION,
INITFS0, DXR INITFS INPUT, BOOT BANNERS, AND CURRENT DTFS/TSFS FOLD ACCEPTANCE.
RUN IT WITH `MAKE TEST-PDP10-TOOLS`; `PDP10_TOOLS_REPO` NAMES THE INTEGRATED
`DAIMOS/TOOLS/HOST` SOURCE TREE.

## COMPLETE REGRESSION ENTRY POINT

`MAKE REGRESSION` IS THE PATCH-ACCEPTANCE ENTRY POINT.  IT SERIALIZES TEST
GROUPS WHICH SHARE SIMULATOR MEDIA OR BUILD DIRECTORIES EVEN WHEN AN OUTER MAKE
USES -J.  IT INCLUDES FORMAT/COVERAGE CHECKS, HOST MM, TARGET TESTS, RESIDENT
AND PERMANENT SIZE GATES, PROCESS/TTY/IPC/SCHEDULER/RT VALIDATION, STORAGE AND
FILESYSTEM TESTS, BOOT/ROOT/LOGIN MATRICES, KERNEL/STAND RUNTIME, USERLAND
PROBES, DTFS RUNTIME, AND INTEGRATED HOST-TOOLS COVERAGE.

THE REGRESSION ENTRY POINT IS RESUMABLE. THE MACHINE-READABLE V1 MATRIX HAS
32 SERIAL ROWS AND THE RUNNER CHECKPOINTS EACH PASS UNDER `$TMPDIR`. EACH PASS
RECORDS THE DAIMOS SOURCE FINGERPRINT, TESTKIT SOURCE FINGERPRINT, AND MATRIX
CHECKSUM IT ACTUALLY TESTED. A SOURCE FIX THEREFORE RESUMES AT THE FIRST
UNFINISHED ROW INSTEAD OF DISCARDING HOURS OF EARLIER RESULTS, WHILE
`MAKE REGRESSION-STATUS` MAKES MIXED-REVISION PASSES EXPLICIT. `MAKE
REGRESSION-RESTART` DISCARDS THE CHECKPOINTS FOR A CLEAN SINGLE-REVISION RUN.

THE 2026-09-30 PRE-TSFS SERIAL REVALIDATION PASSES FORMAT/COVERAGE, HOST MM,
DIRECT PDP-6 TARGET TESTS, RESIDENT/PERMANENT SIZE, THE COMPRESSED BOOT-SOURCE
MATRIX, AND ALL THREE EXPLICIT ROOT CLASSES.  THE FIRST REMAINING FAILURE IS
AUTO ROOT PRIORITY WITH ALL ROOT MEDIA ATTACHED: THE HARNESS DOES NOT REACH THE
DSH PROMPT BEFORE ITS EXISTING 300-SECOND BOOT LIMIT.  A FOCUSED RERUN
REPRODUCES THE SAME FAILURE.  DO NOT MASK IT WITH A LONGER TIMEOUT; THE DAIMOS
PRE-DSH TODO ALREADY TRACKS ROOT/TSFS STARTUP LOCALITY AS THE NEXT WORK ITEM.

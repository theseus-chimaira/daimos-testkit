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

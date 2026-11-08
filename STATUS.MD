## 2026-11-08 v1344: diagnose stalled slot-0 device/event wait (preflight PASS)

The v1343 booted 256K PDP-6 guest remained after 26 read-only
samples with PC 015624 (`proc_wait_boot`), scheduler request 000404,
27 swap-outs/9 swap-ins, zero MM failures, and no process completion.
This is an **unaccepted** guest. The original linked address map,
all 26 raw samples and filtered guest output were copied and SHA256
manifest-verified before interrupting that stalled disposable run:
`$TMPDIR/daimos-swap-slot0-wait-v1344-evidence-r1/`.

The new v1344 read-only SIMH sampler additionally reads the actual
PDP-6 AC1 event pointer, AC17 stack pointer, and linked production
`drm236_active_request`, `drm236_pending_request`, `storage_state`,
and `proc_sched_kick`. Its Ctrl-E-safe output, negative truncated
postflight and early HALT regression PASS; the derived disposable
v1343 guest and source-linked symbol-address preflight PASS.

The v1344 guest is diagnostic only unless all original strict
full-guest validators pass. Its bounded diagnostic mode explicitly
stops after samples and never claims a successful full guest. The
current question is whether slot-0 is waiting for a genuine pending
drum/device event, and why the scheduler request cannot progress.
Do **not** change production kernel, PI6, swap or device code from
PC alone. No permanent KCORE/MRES words were added.

## 2026-11-08 v1343: confirm and correct disposable provider-release dependency

The v1342 source-linked **booted** 256K PDP-6 guest confirms the
previously suspected test-only circular dependency. At sample 12,
`daimos_test_real_oom_v1150=1`, the original fatal provider-busy
counter was **12**, the holder entered once, and the actual
provider lock remained owned. Nevertheless the disposable-only
release flag and holder-return counter were both **zero**. The
real process table simultaneously showed INIT slot 1 in CHILD
wait, gateway slot 4 waiting on the FS provider, and holder slot
6 waiting on `daimos_test_hold_event_v1150`. PI6 timer and the
independent spinner continued to run; four physical MM owners
and the spinner pin had already been freed correctly. The test
was deliberately interrupted after sufficient conclusive evidence;
it did **not** reach HALT or final cleanup acceptance.

Evidence archive:
`$TMPDIR/daimos-swap-provider-dependency-v1342-evidence-r1.tar.gz`
SHA256 `9a286c2a48e635d19411fab3fa2cbc453c99763561608200fcf704130bbb875b`.

The v1343 **disposable-only** injector lets the already-running
spinner invoke the *same original* guarded v1150 provider-release
routine once `real_oom` is nonzero and at least two actual fatal
provider-busy failures exist. It does not synthesize OOM, unlock
the FS lease, change the MM allocator, alter PI6, or bypass the
original holder's private-stack unlock. Three deliberately broken
injection inputs are rejected; the versioned full-guest runner
passes source preflight. **Final guest HALT and strict postflight
remain unverified until the v1343 full guest finishes.**

## 2026-11-08 v1341/v1342: identify post-release wait dependencies

The **completed, timed-out** v1340 256K physical guest is not a
full-system acceptance. At the last of 24 read-only samples the
PI6 clock was 0177102 octal, the timer frontier remained active
and advanced with the clock, but swap-in and swap-out successes
remained 18 and 34. Four typed owner MM extents were already freed
and the independent spinner's pin was released. Guest output after
the repaired Ctrl-E boundary includes the real `@%&*` markers.

The new v1341 **offline-only** process dependency decoder reads the
unchanged raw SIMH transcript, linked process table and kernel map.
It finds INIT slot 1 in CHILD wait, requester slot 3 in timed SLEEP,
gateway slot 4 waiting on `fs_provider_wait_event_v917`, spinner
slot 5 in a two-tick sleep, and the foreign lease holder slot 6
waiting on the disposable `daimos_test_hold_event_v1150`. The
physical clock/timer continue to run. This is evidence of a held
provider dependency, **not yet** evidence of a production scheduler
or provider defect. The original test-only v1150 provider completion
is signaled only by an INIT sleep after observing real OOM and two
busy failures; INIT is instead blocked in CHILD wait.

The v1342 versioned full-guest diagnostic retains the original
production kernel and test fixture, but adds source-linked read-only
sampling of the actual `real_oom`, `fatal_busy`, `release`, holder,
provider and predispatch counters. Its PTY boundary, early-HALT,
process-table and strict-postflight selftests PASS. The new full
guest must establish which original test-owned release condition
was never satisfied before any change to the fixture is justified.

## 2026-11-07 v1340: real independent MM release, Ctrl-E output defect fixed

The booted 256K v1338 PDP-6 test observed one genuine typed swap-in
MM_ERR_NOMEM and no-partner cooldown, then a source-linked independent
spinner query read cooldown 1 and entered the original owner release
exactly once. All four real 8K-word MM extents were freed by production
`mm_free` (count 0, prepared 4, freed 4, error 0) and the spinner's
real MM pin was released (base 0, released 1). Successful swap-ins
increased from 13 to 18 afterward, with no exchange or fatal swap-in.
This establishes true physical pressure, independent owner release
and immediate post-release progress in a booted guest.

The guest subsequently remained stalled after the `^` milestone:
20 live samples, 34 swap-outs, 18 swap-ins, no completed HALT or final
zero-leak accounting. It was deliberately interrupted and **cannot**
close full-system liveness. The next independent trace adds the real
`proc_timer_next` value to distinguish idle/timer/scheduler issues.

The original v1338 raw SIMH PTY trace contains a genuine `@%&` user
milestone sequence directly before `Simulation stopped` after Ctrl-E.
The guest-only stream lost those bytes because the sampler discarded
all data between sending Ctrl-E and the simulator stop acknowledgment.
This is a host test-harness defect, NOT evidence of missing guest
output or a DAIMOS TTY failure. The new v1340 sampler retains the
guest prefix BEFORE the exact debugger stop marker and still strips
SIMH prompts after that boundary. A versioned self-test emits `@%&`
in that race and requires its exact preservation, as well as normal
HALT, early HALT, source-linked process data and truncated-postflight
negative rejection. Self-test and generated v1340 guest preflight PASS.

No production KCORE, MM, scheduler, swap or MRES code changed. Full
booted end-to-end acceptance remains OPEN until real process cleanup,
backstore release and final source-linked postflight validation pass.

## 2026-11-07 v1338: isolate independent releaser poll before liveness acceptance

The previously staged v1336 booted 256K guest reached a real slot-0
MM_ERR_NOMEM/no-partner cooldown (one event), after 18 additional
admissions, with 34 successful swap-outs and 18 swap-ins. Its
independent user release witness did NOT appear during 18 live
samples. PI6 time advanced and the cooldown expired, but further
swap progress and normal HALT did not occur. This intentionally
interrupted guest is **not** a release, cleanup or full-guest PASS.

The versioned v1338 diagnostic fixture adds three read-only BSS
counters to the disposable kernel only: number of spinner cooldown
queries, last actual observed cooldown value, and number of entries
to the exact MM-owner release path. The v1338 sampler also reads
the original test owner count/prepared/freed/error, saved spinner
pin base, release count and release-pressure witness by source-linked
addresses. The real PI6 scheduler, MM/BRK, swap service and disk I/O
remain unchanged. Source-injection, syntax and generated-runner
preflight PASS. Its booted full guest requires separate evidence;
no current diagnostic sample alone can close swap liveness.

## 2026-11-07 v1336: booted real-MM no-partner pressure independently verified

The retained **unfinished** 256K KCC PDP-6 v1335 live SIMH trace
contains 93 genuine typed `MM_ERR_NOMEM` swap-in allocation failures
and 93 slot-0 no-partner cooldown events, no exchanges, no fatal
swap-ins, 54 successful swap-outs and 37 swap-ins. Four owner-tagged
8K MM extents occupied 32K of the actual managed physical RAM.
`daimos-swap-live-pressure-v1336.py` now decodes the source-linked
counter addresses directly from the raw read-only SIMH transcript
and independently checks typed MM error, request/owner, fit and
reclaim/cooldown consistency. Eight unsafe counter mutations fail.
The preexisting strict v1303 full-guest verifier's `swapout_fail`
assertion is not applied to a *live* sample: the production label
is also entered by refused reclamation attempts and those refusals
were observed under pressure. No final safety check was weakened.

**NOT full-guest acceptance:** v1335 was interrupted with INIT
waiting for the 18th child to acknowledge RUN. Its own test-owned
MM reservation could not be released by that blocked owner, and
there is no final HALT, restoration-after-release, or leak proof.
The separately staged v1336 independent resident-spinner owner
release fixture requires a complete, fresh guest and strict final
postflight verification before closing that acceptance. Production
KCORE/MM/scheduler/swap/MRES code remains unchanged.

## 2026-11-07 v1336: independent user-MM release fixture (preflight)

The booted v1327 early-owner run recorded 93 typed physical
MM_ERR_NOMEM swap-in failures, 93 genuine no-partner cooldowns,
zero exchanges, 54 normal swap-outs and 37 normal swap-ins after
17 extra child admissions. Its INIT could not free the four real
8K-word MM owner extents while it was waiting for the next RUN/ACK.
The test was intentionally interrupted, not accepted as liveness.
Exact original linked traces and source are archived at
`$TMPDIR/daimos-swap-early-owner-pressure-v1335-evidence-r1.tar.gz`,
SHA256 `6da56d34d55108c1105910e26a675b7c46caa05d54b120ab7166c7bfae2b3a65`.

The versioned v1336 fixture now pins the existing resident spinner
slot 5 using production `mm_pin`, then polls the actual production
cooldown counter from user mode through a test-only read-only BRK.
Once a real cooldown appears, that independent process frees the
four typed test-owner MM extents through production `mm_free` and
releases its own pin through production `mm_unpin`. Exact physical
trigger, release count, pin/base and backing witnesses are checked
by `daimos-swap-independent-release-verify-v1336.py`. This avoids
inventing an MM error or freeing memory from a kernel timer.
The source injector passed direct production PDP-6 assembly, and
the generated 256K guest runner preflight PASSed. Booted end-to-end
recovery is **NOT ACCEPTED** until a real guest reaches HALT, all
owner/pin counters clear, and all backing is freed. Production KCORE
and MRES source and permanent RAM remain unchanged.

## 2026-11-07 v1334: early 32K real-MM owner full-guest fixture (partial)

The versioned v1327 disposable 256K F07 guest moves four genuine
8K-word MM_TYPE_KERNEL_DYNAMIC owner-075 extents to the stage with
only six original resident user processes, before the 18 additional
24K-BSS RUN admissions. It retains the unchanged production
`mm_alloc_aligned_noreclaim`, `mm_free`, process scheduler and swap
sources, with strict v1203 physical-MM, v1327 owner-release and
v1303 no-partner final evidence requirements. Source injection and
generated-runner preflight PASS; the first live PDP-6 guest entered
additional child RUN with no early allocation rejection. No final
MM-pressure, no-partner, exchange or leak-free acceptance is claimed
from these intermediate observations. See
`tests/validation/daimos-swap-early-owner-v1334-README.md`.

## 2026-11-07 v1333: optional read-only live PDP-6 process descriptors

The versioned v1332 SIMH sampler extends the accepted prompt-safe
v1326 host utility with opt-in `--kcore-map` inspection of the real
`proc_table`, `proc_high_slot` and `proc_current_slot` linked words.
It reads the physical three-word process descriptors without
writing kernel memory, deriving RUN/SLEEP/WAIT state, residency,
process image extent size and descriptor flags for each live slot.
The original 29 linked swap/MM counters and early-HALT/postflight
validation remain unchanged when the optional map is omitted.

The v1332 scripted PTY self-test PASSes actual descriptor decoding,
normal early HALT, raw/guest prompt separation and rejection of
missing symbols, truncated final postflight and malformed inputs.
The previous v1326 self-test also PASSes on the same checkout.
This is diagnostic instrumentation only, not real no-partner
full-system acceptance. No production DAIMOS source or resident
memory is modified.

## 2026-11-07 v1325: 8K booted owner-pressure admission rejection classified

The v1322 genuine 256K PDP-6 F07 guest reached 18 extra 24K-word
child admissions and entered the additional, test-only 8K MM owner
reservation. The actual `mm_alloc_aligned_noreclaim` call refused
that allocation; INIT emitted `!t` and HALTed. Its post-HALT
`f07h_error` is 36-bit -1, with `f07h_prepared=0`, `f07h_count=0`,
`f07h_freed=0`. All swap-in MM failure, swap-service cooldown and
exchange counters remain zero. This was **test setup exhaustion**,
not a reproduced swap-in no-partner condition or a production bug.

The new strict v1325 postmortem verifier requires those exact
source-linked counters and terminal markers and rejects altered
owner/error/pressure/cooldown values. Its Makefile target PASSes.
SHA256-verified raw evidence:
`$TMPDIR/daimos-swap-owner8k-rejection-v1325-evidence-r1.tar.gz`,
SHA256 `bf5304eb2ce0de91d463b8137c601e9c77f4223bea7cf67ebb3a3e4582800e31`.

The separate v1323 1K owner-tagged fixture was already running when
v1325 postmortem was completed. It has no full-system no-partner
acceptance yet. No production kernel source or RAM size changes.

## 2026-11-07 v1320: native production DEVICE backing gateway integration

The v1319 PDP-6 native test extends the accepted v1317 production
`proc_swap_in`/MM/pin/storage/backstore-bitmaps fixture through
the actual `fs_mres.s` `backstore_read` DEVICE gateway. The DSK270
hardware endpoint alone is test-controlled. For logical backing
blocks 1 through 8, the real bridge validates the range, translates
DEVICE base 020 to sectors 021..030 and advances both device address
and physical output pointer by 0200 words per sector. The fixture
checks the translated sector numbers and both endpoint payload words.
Production swap-in performs MM allocation, pin, unpin, resident
publication, bitmap free and READY_ONCE; eight sector reads observed.

The same native test verifies first-sector and third-sector I/O
failure, both handled through the unchanged production swap-in
rollback: no orphan MM extent, original DISK record and backing
retained and exactly one TERM event. An executable mutation that
omits the production gateway buffer advancement fails the real
PDP-6 payload assertion. The original v1317 transaction regression
is run before these gateway checks, and the new v1319 Makefile target
passes twice. No production kernel source or permanent resident
footprint has changed.

The endpoint is NOT a physical DSK270 device, and scheduler work,
exchange candidate admission and real user-process release are
not executed as a booted 256K guest. Thus this is native gateway
integration acceptance, NOT full-system no-partner liveness.
Evidence: `$TMPDIR/daimos-swap-device-gateway-v1320-evidence-r1.tar.gz`;
SHA256 `c63d3f14a09d0873bb4958bbf40de7dd61bff84c3a4cf7901d1c54e06348bbab`.

## 2026-11-07 v1317: production swap-in native commit and rollback

The native v1316/v1317 test now extracts the entire actual production
`proc_swap_in` transaction and unmodified slot-0 service, as well as
the native MM allocator/find-fit/compaction/free, MM pin/unpin, packed
process storage mode expectation/publication, backing bitmap free,
PI6 timekeeping and scheduler swap-pressure selection. An occupied
010000-octal-word arena makes the first real swap-in allocation
return typed NOMEM. All three test-controlled exchange candidates
are rejected; the swap record remains intact and cooldown is 0100.
After 63 actual production clock-timekeeping calls, the cooldown
remains active and the resident scheduler path is selected. Releasing
the independent physical owner through production `mm_free` allows
the 64th clock tick to expire the cooldown, the scheduler to request
another swap-in, and the unchanged `proc_swap_in` to succeed.

The successful native transaction executes actual MM pin, physical
backing-read destination placement, MM unpin, resident VM publication,
packed DISK -> RESIDENT mode publication and real `backstore_free`
bitmap accounting. The backing bitmap and both swap counts become
zero; the process extent has the correct owner and no outstanding
pins. The disk `backstore_read` itself is a test-only provider which
writes two distinctive words into the allocated physical memory.
Its payload is subsequently checked at both ends of the image.

A separate disk-read failure returns a genuine nonzero result from
the test provider, causing the production rollback branch to unpin
and free the physical process extent, preserve its original disk
record and bitmap allocation, keep the packed state DISK, clear the
TRANSITION marker and return a single fatal TERM event. Three
executable source mutations (lost MM rollback free, lost backing
bitmap release, lost storage-mode publication) are rejected.

This establishes a native PDP-6 production transaction under real
MM pressure; the physical backstore device, exchange eligibility,
hardware PI6 interrupt entry and independent user process remain
test-controlled or untested. Thus **booted full-system 256K no-partner
liveness is not yet accepted**, and no production kernel RAM or code
change is justified.

## 2026-11-07 v1315: actual PI6 cooldown and scheduler selection

The native real-MM physical pressure test v1313 now additionally
executes the unchanged production `proc_sched_pi_tick` timekeeping
prefix, followed by the production `proc_select_rt_normal_swap_v879`
gate. After a real MM_NOMEM result, all three rejected exchange
partners and a preserved disk record, 63 production PI6 tick calls
leave the 0100-octal cooldown at 1 and the scheduler selects the
independent resident path. The 64th tick expires it and the actual
scheduler gate raises the swap request. The independent owner was
released with exact production `mm_free`, permitting the production
allocator and unchanged slot-0 swap service to succeed and emit
READY_ONCE. Five earlier mutants plus an executable scheduler-gate
bypass are rejected (six in total). Neighboring v1300/v1301 and
v756 regressions PASS. No production kernel changes.

The native PI6 tick prefix is actual PDP-6 assembler, but is invoked
by the test fixture, not through a hardware clock interrupt. The
resident runnable-path marker is test-controlled, and the swap-in
disk transfer and exchange admission are still modeled, rather than
the production backstore/restore transaction. Full 256K-booted
no-partner liveness remains OPEN; do not infer full acceptance.

## 2026-11-07 v1315: exact PI6 cooldown and scheduler admission gate

Building on accepted v1314 real-MM pressure and no-partner native
recovery, v1315 executes the unchanged production
`proc_sched_pi_tick` timekeeping section and
`proc_select_rt_normal_swap_v879` scheduler gate as PDP-6
instructions. Following real MM_ERR_NOMEM and a fully rejected
three-candidate exchange scan, 63 real clock-prefix calls leave
backoff 1, with scheduler gate taking the independent runnable
process path and leaving the pending request unraised. A real typed
`mm_free` releases the occupying physical extent. The 64th clock
call expires the cooldown, and the production scheduler gate itself
issues cursor 0402 (rather than the test synthesizing a swap request).
The unchanged slot-0 service then allocates through production MM,
publishes READY_ONCE and does not apply TERM or exchange.

Six executable negative mutants are rejected, adding disabled PI6
aging and unconditional bypass of the cooldown scheduler gate to
the original four MM/service mutations. Neighboring v1300/1301,
v756, v1303, v1111 and v1260 tests PASS. Production kernel code
was not changed.

The native fixture substitutes a return after the PI6 timekeeping
section and models `proc_swap_in` disk completion and the exchange
candidate decision. It therefore does not run real hardware PI6
preemption, authentic backstore read/rollback or a booted independent
process lifecycle. Full-system no-partner liveness remains OPEN.

Archived PDP-6 positive and six negative reports, source and linked
map with SHA256 verification:
`$TMPDIR/daimos-swap-native-clock-gate-v1315-evidence-r1.tar.gz`;
SHA256 `17f4d19c56b7776c608cfc88a0e94f0c3674cb62ce2d09094e503193ebb87134`.

## 2026-11-07 v1314: actual MM allocation-pressure / no-partner native test

The v1313 36-bit PDP-6 test extracts the unchanged production MM
find-fit, noreclaim allocator, bounded allocator, arena capacity
filter, compaction and free leaves, plus the actual slot-0 swap
service. A physically occupied 010000-octal-word arena cannot fit
the pending 02000-word process image. Actual MM returns typed
MM_ERR_NOMEM (-1), after two filesystem reclaim attempts and one
process reclaim attempt; these deliberately refuse to free the
fixed kernel-dynamic extent. The unmodified slot-0 service scans
three exchange candidates, rejects all, preserves disk-backed
ownership, sets the 0100-octal cooldown and does NOT terminate the
waiting process. Independently freeing the occupied extent through
the production `mm_free` permits a subsequent real allocator
success, correct process extent owner 2 and READY_ONCE dispatch.

The native test models the disk transfer and candidate admission
with separate stubs. It is therefore **not** a booted full-system
no-partner forward-progress acceptance; timed cooldown aging,
physical backstore reads, complete restore transaction and rollback
are still pending full-guest evidence. It does not establish that
the ordinary 256K F07 workload reaches no-partner pressure.

The positive native test and four executable negative mutants PASS:
pressure error collapse, skipped filesystem reclaim, skipped
process reclaim and lost cooldown all fail their assertions.
Neighboring v1300/v1301/v756, v1111 and v1260 checks PASS on the
same production source. No production DAIMOS kernel changes.

Versioned raw native evidence (positive, four rejects, source,
symbol map and SHA256 manifests):
`$TMPDIR/daimos-swap-real-mm-no-partner-v1314-evidence-r1.tar.gz`,
SHA256 `c30cccf491176a4488ffcf8933dff0b0485ce85dc198c3d10db60e06c884ed92`.

## 2026-11-07 v1311: full 24K guest completed; PTY postflight replay

The first v1308 256K PDP-6 live-sampled 24K-BSS guest emitted all
15 periodic v1306 snapshots, admitted all 18 pressure children,
performed all 18 TERM/WAIT reaps, completed requester OOM/provider
milestones, and reached HALT. The final linked source counters show
51 successful swap-outs and 51 successful swap-ins, zero swap-in MM
allocation failures, exchanges, fatal failures, and cooldowns.

The original runner exited nonzero after the v1075 requester-only OOM
PASS, because its already-running v1306 revision prefixed SIMH's
post-HALT `examine` output with interactive `sim> ` prompts. Its v1150
provider parser rejected the address formatting, not the kernel
counter values. This was corrected in testkit v1309 `3fa4792` and
verified with a PTY full-postflight protocol selftest; that fix was
committed after the running simulator had already imported its older
sampler source. Do not misstate v1308 as a direct full-runner PASS.

New v1311 replays the **unchanged original v1075 postflight checks**
from the original testkit source against a separate copy of the guest
log with only line-leading `sim> ` prefixes removed. The immutable
original guest log remains available. Recorded output then passes
v1150 provider ownership/retry, v1159 protected processes, v1203
physical MM, v1205 actual-process APR/BRK, v1207 real swapping and
stack bounds, and v1160 release-media SHA256 evidence. A separate
disposable negative fixture changing the one real v1150 `armed`
counter from -1 to 0 is rejected as an invalid owner/oom condition.

This is verified completed guest behavior with an offline diagnostic
postflight replay, NOT another completed direct SIMH runner acceptance.
The genuine full-system no-eligible-exchange-partner swap-in liveness
case still was not exercised and remains OPEN. Production DAIMOS
kernel source remains unchanged. All test fixtures are testkit-only.

## 2026-11-07 v1308: live SIMH swap-pressure observability

Current production DAIMOS `f78145db` remains untouched.  The native
256K KCC PDP-6 F07 requester-only OOM guest with 16K-word process BSS
completed with 18 RUN/TERM/WAIT children and 41 successful swap-ins;
read-only v1209/v1219 probes recorded **zero** swap-in MM allocation
failures, exchange requests and no-partner cooldowns.  A distinct
24K-word-BSS disposable guest admitted all 18 children and yielded
49 swap-outs/33 swap-ins with no failure or cooldown at a controlled
pre-cleanup interrupt; that older v1304 r1 run was NOT a guest PASS.
These facts do not establish no-partner liveness.

v1303 now provides a source-linked physical no-partner evidence
classifier, optional diagnostic-only partial-snapshot mode (exit 3),
positive synthetic classification and five negative mutations.
v1304 makes the 24K-BSS pressure image in a disposable source copy,
retaining production MM/swap semantics and the original full-guest
acceptance checks.  Its distinct full guest has a bounded 1800s
budget and can be prepared without compiling via the preflight target.

v1306 adds a read-only PTY-based SIMH live sampler.  It interrupts
the CPU at an operator-selected interval, examines the actual linked
PC, scheduler/timer, swap, cooldown, backing and MM-failure counters,
then resumes the CPU.  It retains the guest-only console transcript
separately from the full debugger trace, executes normal post-HALT
diagnostics, restores the original boot.ini unchanged and fails closed
when counters cannot be sampled.  Stub protocol, missing-symbol
negative control and a real two-sample PDP-6 smoke PASS.  Short
stop-after-samples runs explicitly do NOT qualify as full guest PASS.
The opt-in long v1308 24K guest was running under 15 periodic samples
at this documentation checkpoint; completion is not yet certified.

## 2026-11-07 v1302: swap-in no-partner current-source regression

The accepted DAIMOS v1298 production OOM tree (`283b54dc`) passed a
full 256K PDP-6 GCC/DSK/D6FS 16-child scheduler-pressure guest via
v852 and the existing native v855 incoming, v958 rollback, v666
late rollback and v757 scheduler-contract tests. No production
swap source change was necessary for these observed cases.

New v1300 is a current-source guard for the slot-0 swap-in pressure
classification, all-candidate scan, disk ownership and cooldown;
it rejects six negative mutants. New v1301 executes the actual
slot-0 service assembly on a PDP-6 with an allocator reporting
pressure and three exchange candidates rejected: the swapped record
is retained, the request is consumed, 0100 retry cooldown is set,
TERM is not generated, and separate fatal/success returns behave
correctly. These are native no-partner control-flow tests, not a
full-system liveness proof under actual physical exhaustion.

The old v756 test expected the removed C swap-in implementation.
It now compiles current assembly and verifies the -3..-1 resource
pressure distinction, fatal classification and four unsafe mutants.
All three new/repaired Makefile targets PASS. The next required
diagnostic is a physical 256K no-eligible-partner guest with actual
memory/backing pressure and eventual progress/cleanup acceptance.

## 2026-11-07 v1278: retain native v1260 MM arena leaf in F04 BRK fixture

The exact-source Linux F04/v1113 real MM/VM/BRK test failed during
native image linking with `undefined symbol: mm_arena_fits_v1260`.
The v1260 production allocator now calls this real aligned-arena
feasibility function before reclamation; the old v1113 test extracted
the allocator but omitted its new native leaf. The kernel did not
execute and no BRK/MM failure was demonstrated by that build error.

The v1278 native test fixture now extracts the **actual production**
`mm_arena_fits_v1260` implementation along with the unchanged full
allocator, compactor, VM BRK and fatal-enabled dispatch. It does not
stub or assume the preflight succeeds, and the original three unsafe
typed-cause mutants remain mandatory. Android native v1113 now PASSes
all real -2/-3 MM/VM/BRK paths and three mutants; the independent
v1260 alignment/no-reclaim test with two mutants also PASSes. The
exact Linux F04 suite still requires re-execution with corrected
testkit and the newly installed Linux v1277 linker tools. No
production DAIMOS/MM source or OOM policy changed.

## 2026-11-07 v1277: host linker/folder bug uncovered by OOM F11

The current frozen Linux v1112 failed-RUN physical guest initially
halted at PC zero after `<` on DAIMOS `226e7a5f`, but identical
Android guest and historical DAIMOS `96e6c695` passed. An isolated
37-commit Linux source bisect identified the first bad revision as
`4dcaca20` (v1257 scheduler u-area locality guard). The native
v1141 cross-object-local-relocation test then proved the Linux host
still used an October 13 `p10fold` binary incorrectly folding two
distinct LOCAL TEXT targets. A clean rebuild from current DAIMOS
tools source restored correct relocation and v1112 PASS without
touching the production kernel. The Linux and Android INIT executables
were byte-identical throughout, and corrected KCORE low endpoints
both equal `023267` octal for this test.

v1277 adds an exact six-column fold-plan regression: a valid empty
plan is accepted by both `dlink` and `p10fold`, while seven malformed
or empty/extra-field plans are rejected by each with typed diagnostics.
Combined with the existing v1141 relocation and v1257 native selector
tests, the clean rebuilt Linux and Android tools PASS. The Linux
update was installed from a versioned `local.tar.gz` into
`$PDP10_PREFIX`, preserving the old binaries before replacement.
The current release source F11 integration matrix still must be rerun
with this corrected host toolchain. No production OOM enablement is
implied by the host fix.

## 2026-11-07 v1275: exact-revision E13 cross-host PASS and F10 media-note audit

Two independently built 256K KCC DSK/D6FS release-media OOM pairs
PASS on Android aarch64 and Linux x86_64 with identical DAIMOS
`226e7a5f` and testkit `ee9d92b` sources. Both default-disabled
(requester BRK returns -1) and disposable-enabled (only PID 3 retired)
policies PASS real OOM, held provider, protected process and resource
cleanup checks. Independent simulator binary hashes differ; KCORE
low ends agree exactly (`023503` OOM OFF, `023521` disposable ON).
Original evidence SHA256: Android
`c87799ba1ecda40f07bbbf718d5ca20e0d5be896549df3be80d075ed0c8990ef`,
Linux `a59d9b90338a0c23fd084fb7153160bd4068fd4233eabfcf7cd0205fb8b6a720`.

The v1190 build-diagnostic audit originally demanded identical media
warnings, despite explicitly accepting either legacy D6FSR2 or modern
explicit-reservation layouts. Linux reports the approved legacy
layout warning, Android does not. v1275 normalizes ONLY that
preapproved optional layout note across hosts; the 12 compiler and
assembler diagnostic classes remain exactly identical, all unexpected
notes remain fatal. Self-test/three unsafe tool-note mutants and all
four actual full build logs PASS with zero unexplained diagnostics.

An exact-source F02/P0-D complete fault-injection matrix PASSes on
Linux. An additional exact-candidate F03 regression run subsequently
encountered an unexplained early guest UUO in v1112 failed-RUN after
v1110 pair PASSed; this is NOT accepted, needs root-cause diagnosis.
E13/F11 approval and production OOM remain blocked until independent
coverage and full release matrix are reconciled. F07 v1274 is CLOSED.

## 2026-11-07 v1274: F07 full 64-slot/descriptor/physical-OOM acceptance PASS

A fresh 256K KCC DSK/D6FS PDP-6 guest built from clean DAIMOS
`226e7a5f` and disposable testkit `027fc3f` completed within the
original 900-second limit: 57 additional RUN/BRK acknowledgments,
physical requester-only OOM, original foreign FS lease and gateway
cleanup, all 57 normal TERM/WAIT/reaps, witness survival, exact final
VM/FILE/backing cleanup and expected `KWP` HALT. The kernel's
production requester-OOM switch remains OFF.

At the single real physical-OOM snapshot: 64 configured process slots,
63 live user processes, 55 resident APR extents and 8 nonresident/swap
processes, 127/136 real MM descriptors, 239576/242085 managed words
allocated, 2509 free, 31642 exact APR-rounding words, 128-word shared
FS workspace, 180/206-word private and 63/256-word idle stack peaks.
Every real child (slots 7..63) published its distinct logical BRK.

The tightened v1205/v1207 verifiers require all expected real u-areas,
near-full MM/descriptor occupancy and original provider ownership;
`daimos-f07-64slot-host-v1274.py` validates the real evidence and
rejects 13 unsafe mutations. The old 24-process evidence still passes
its unchanged requirements. All evidence manifests verify.
Archive `$TMPDIR/daimos-f07-64slot-acceptance-v1274-r1.tar.gz`, SHA256
`0fb22920bfd9f66c155ef3bb61f8db0c0f146f80f89bbc3e6e1b3406d9599e1b`.
This closes the bounded S07/S08-profile F07 quantitative acceptance,
NOT E13/F11/F12/F13 or production OOM activation.

## 2026-11-07 v1272: bound 64-slot guest VM footprint (qualification running)

The first v1271 64-slot guest reached 18/57 extra RUN acknowledgments
at approximately seven minutes while still making forward progress.
It was deliberately stopped rather than misreported as deadlocked:
cloning the original 16K-word INIT BSS 57 times puts more than the
configured swap backing at risk and makes the unchanged 900-second
24-process timeout inappropriate for this different workload.

The v1272 64-slot-only fixture now keeps a real BSS corruption sentinel
in a 1K-word array; the original v1075/v1207 16K-word pressure array
remains unchanged in every other mode. The actual 64-slot guest must
still pass true RUN/BRK, 63 live user slots, nonzero real disk swap,
physical requester-only OOM, 57 individual TERM/WAIT/reaps, exact
MM/FILE/backing cleanup and original private/idle stack watermarks.
The two C89 modes compile; no production code is changed. The fresh
v1272 full-system guest is currently under verification, not accepted.

## 2026-11-07 v1271: full 64-slot F07 stress fixture (qualification running)

A new opt-in `V1271_TEST_FULL_SLOTS=1` mode attempts 57 extra real
RUN children in addition to slots 1..6, filling the 64 configured
slots including kernel slot 0. Each child has its own real RUN/BRK,
acknowledgment, TERM, WAIT and teardown; no descriptor is synthesized.
The existing 24-user stress remains the default. The 64-slot verifier
requires `proc_high_slot=64`, 63 live user descriptors, and distinct
logical BRK deltas for *every* child slot 7..63. The normal swap mode
now also checks all 18 children (not merely the first six).
The clean production SWAP MRES is auto-detected by the disposable
probe, retaining the explicit v1266 comparison guard when requested.
Both C89 guest modes compile; the 24-slot archived physical guest
passes strengthened process verification; its incorrect 64-slot
reinterpretation fails; v1266 negative mutations and v1207 native
host tests pass. A real 64-slot guest is being qualified separately.
**No F07/E13/F11 release gate is closed by these preparation checks.**
Production OOM remains disabled.

## 2026-11-07 v1270: preserve historical F07 diagnostic probes

The 27 previously untracked diagnostic-only F07 files (v1075-2000s,
v1207, v1212-v1250) are now versioned rather than left in the working
tree. All Python files passed AST syntax parsing and both shell runners
passed `sh -n`. These are historical fault-isolation fixtures, not new
production features or a claim that each injection case has current
full-system acceptance. Their opt-in flags remain off by default.

Both clean and experimental v1266 swap probes plus v1263/v1264
protection and v1207 accounting native/host tests PASS. The final
256K clean committed-source 24-process guest v1269 passes the full
900-second F07 workload; SHA256 evidence is documented in DAIMOS.
The optional v1208/v1211 swap runtime experiment was discarded from
production after a clean guest passed without it. Its exact reversible
source diff is archived in DAIMOS `design/`, not installed in KCORE or
SWAP MRES. No no-equal-partner failure case has established a reason
to add the 16-word SWAP MRES growth. F07 remains open for 64-slot
and combined descriptor pressure qualification.

## 2026-11-06 v1264: successful 24-process F07 stress run (gate still open)

The fresh PDP-6 256K KCC/DSK/D6FS guest reached the expected `KWP` HALT within the original 900-second limit: 18 additional RUN children admitted, true disk swap under 24 live user slots, requester-only physical OOM, held provider lease and gateway contention, every child terminated and individually reaped. The v1150/v1159 owner/protected-slot probes and v1203/v1205/v1207 independent MM/process/swap/stack verifiers PASS. The original provider error is zero. Batch TERM v1262 queues the same 18 TERM events before the 18 normal WAIT/status/teardown checks. Provider mode v1264 and protected mode v1263 retain strict expectations in standalone tests; their native mutant controls PASS.

Evidence `$TMPDIR/daimos-f07-v1264-acceptance-r1.tar.gz`, SHA256 `0fc008be42997a81138f4513d603bb828a0a978903ef60d1c761dd08e2068fea`. The passed guest was built from DAIMOS b6db5372 with uncommitted experimental v1208/v1211 swap edits; it is NOT a clean production-tree qualification. F07 still requires the 64-slot/high-descriptor combined matrix. F07/E13/F11 stay OPEN, 59/64 OOM gates, production requester OOM OFF. See `pdp10-doc/KERNEL/OOM-F07-24PROCESS-SWAP-CLEANUP-V1264.MD`.

## 2026-11-06 v1253: 18-child guest PID scheduling trace (F07 OPEN)

The 256K KCC DSK/D6FS guest ran with disposable, native-assembled
per-slot dispatch and normal swap-request counters. It admitted all
18 additional RUN children and reached `^@%*` but neither the
requester WAIT checkpoint nor any child reap. Controlled SIMH stop
after about 12 minutes preserved full build, map and raw counter data.
INIT PID 1 was dispatched 2,125 times (16 swap requests), requester
PID 3 21 times (seven swap requests), spinner PID 5 3,103 times
(16 swap requests). Extras PID 13..24 each logged 145 dispatches and
zero swap requests, unlike PIDs 7..12 which each had one dispatch.
This excludes *complete* requester starvation but does not prove its
progress, nor explain the common extra-child dispatch count.
Source-only injection/negative controls and native PDP-6 execution
of both counter hooks PASS. The exact copied guest had unaccepted
v1208/v1211 swap experiments, so no production F07 acceptance.

Archive: `$TMPDIR/daimos-f07-v1253-dispatch-evidence-r1.tar.gz`;
SHA256 `5a18fec660cb2f955d06ce482fe8edbe44f52128710613e52f40845553066f1a`.
An independent follow-up is sampling descriptor RUN/SLEEP states via
the preexisting disposable v1238 probe. E13/F07/F11 remain OPEN,
59/64, production OOM disabled.

## 2026-11-06 v1253: per-slot scheduler/swap diagnostics prepared (F07 OPEN)

The v1252 full 256K guest resumed due timers but still made no
requester WAIT progress before an operator interrupt. Aggregate swap
counters cannot distinguish repeated successful slot-0 exchanges from
starvation of the actual requester (PID 3). v1253 supplies a strictly
disposable, bounded 64-slot dispatch counter and a separate 64-slot
nonresident swap-selection counter, plus one slot-0 selection count.
All hooks are in the copied native proc_pdp6.s; there is no production
scheduler, swap, or OOM policy change and no output from interrupt
context. The decoder checks exact per-slot addresses and rejects
missing/repeated simulator observations. The source-injection host test,
native PDP-6 assembly, and two missing-hook negative mutants PASS.

The optional v1253 switch is wired into the ongoing dirty v1075 full-
guest diagnostic harness, which is not an accepted exact-revision F07
candidate. No live v1253 F07 guest result has been accepted yet.
E13/F07/F11 remain OPEN, 59/64 OOM gates, production requester OOM OFF.

## 2026-11-06 v1252-r1: 18-child guest advances through timers; F07 OPEN

The 256K KCC DSK/D6FS guest (production OOM OFF) acknowledged all
18 added RUN children, reached `^@%*`, and then continued swapping
without reaching the requester's `?` WAIT marker. A controlled stop
before the 900-second timeout preserved the full simulator and map
snapshot. At stop `proc_timer_next=0`, with 52,315 elapsed clock ticks,
32 successful swap-outs, 20 ordinary swap-ins, 32 successful exchanges,
zero swap-in/out failure branches, 1,800 swap blocks and 46 MM
descriptors. The genuine physical BRK OOM sample remained zero and
no added child had been reaped. This is partial diagnostic evidence,
NOT complete F07 acceptance or evidence of a lost DRM completion.

The copied guest contained the experimental v1208/v1211 swap paths
and the first unguarded v1252 scheduler fix; the committed v1252
path adds a DUE-only fast guard. Evidence is retained at
`$TMPDIR/daimos-f07-v1252-fullguest-snapshot-r1.tar.gz`.
Further F07 testing must measure per-slot dispatch/swap selection to
distinguish requester starvation from heavy but finite swapping.
E13/F07/F11 remain OPEN, 59/64, production OOM OFF.

## 2026-11-06 v1252: software PI6 deferred-timer service PASS (F07 OPEN)

The source-backed PDP-6 native v1252 regression executes the actual
proc_sched_resched_choose, proc_timer_service and proc_runq_add leaves.
After slot-0 synchronous swap I/O, software PI6 must service a timer
frontier marked DUE before choosing the next runnable process. The new
test verifies wakeup and run-queue insertion, and a second scenario
preserves an active but not-due timer. Its negative mutant removes the
timer hook and demonstrably leaves the sleeping job blocked. The
existing timer-frontier and v884 reaper native tests also PASS.

Full 18-child F07 RUN/swap/WAIT guest acceptance is still pending;
v1208/v1211 remain experimental. E13/F07/F11 OPEN, 59/64 OOM checks,
production OOM OFF. No size-optimization work is required for v1252.

## 2026-11-06 v1232-v1234: D6FS FCB cache/source divergence (F07 OPEN)

Full disposable v1232/v1233 256K PDP-6 DSK/D6FS guests (idle-stack
experiment `0400` octal) reproducibly acknowledge 9/18 extra RUN
children, then fail the tenth RUN. v1232 proves FCB block lookup and
FCB decode both **succeed** (`block_fail=0`, `decode_fail=0`), but the
provider rejects the resulting file type (`reason=6`, `type_fail=1`).
The affected FCB index is `037` octal, from logical block `0741`.
v1233 captures raw FCB META, decoded type, flags and size **all zero**:
the in-guest provider received a well-formed FREE FCB, not the regular
executable FCB. The executable was read successfully on prior RUNs.

Independent read-only host inspection of the exact guest's D6FS disk
set shows the opposite: `d6fsck -n 4 -d disk` reports a CLEAN D6FS
superblock `0734` octal, 360 FCBs; physical member 1 sector `0171`,
FCB offset `0160`, still contains raw META `100005550020` octal,
type **REG (1)**. The disk layout descriptors were checked on all
four members and agree. Thus the guest's FREE FCB does not match the
actual intact on-disk FCB. Remaining candidates include BCACHE/shared
workspace lifetime, an incorrect provider I/O result or overwritten
in-memory data. Do not claim a damaged disk or alter permanent caches
until the direct workspace/cache-path observation resolves this.
Disposable v1234 records the last BCACHE source and the raw FCB
workspace word; full guest result is pending. **No F07 acceptance.**

## 2026-11-06 v1232-v1234: D6FS stale FCB verified against disk (F07 OPEN)

An independently built full 256K KCC DSK/D6FS guest (v1232) with
the diagnostic-only 0400-octal idle stack failed at the same tenth
RUN child. The `d6fs_reader_fcb` instrumentation observed index
`037` (limit `0550`), **zero index/block/decode failures**, but a
single provider type rejection: decoded FCB type `0` (FREE) rather
than REG. The cached metadata word was zero. This was the source of
the `vfs_read_words=-1`, not a disk read failure.

The v1233 guest re-read that exact FCB block directly from the D6FS
backing into a separate 0200-word *disposable* buffer after the
normal type rejection. The cached FCB meta was `000000000000`,
while the **successful physical backing read** returned
`100005550020` from the identical FCB index `037` in block `0741`.
This conclusively demonstrates a stale/incorrect cache or shared
transfer buffer view; it does not demonstrate on-disk corruption.
Investigate whether BCACHE hit slot 0 (workspace) or slot 1 (slab),
and locate the missed invalidation or stale-copy origin before fixing.
The v1234 read-only BCACHE hit-source probe is experimental; no
accepted v1234 guest observation or production kernel fix yet.
F07/E13/F11 OPEN, 59/64, production requester OOM OFF.

## 2026-11-06 v1228-v1231: EXEC payload read failure after idle-stack correction (F07 OPEN)

Under disposable `0400`-octal (256-word) idle stack, the v1227 full
256K guest acknowledged nine of eighteen additional RUN children,
instead of six with a 64/96-word idle stack. This is diagnostic only;
the minimal safe permanent idle-stack bound is still unqualified.
v1228 found RUN failing at `exec_load_process`, returning `-1` for
candidate slot `020` octal. An independently built v1229 guest pinpointed
phase **6 (executable payload loading)**, after lookup/stat, header
validation and VM creation. It also confirmed `exec_load_process=-1`.

The v1230 DSK/D6FS release-media guest identified the exact failed
`vm_space_load_file` operation: D6FS vnode `060101000037` octal,
file offset 3, physical destination `0734020`, request `01572`
octal (= 890) words, actual `vfs_read_words` result `-1`. Thus it is
a provider/read failure, not a short read, failed lookup, or failed VM
allocation. Earlier requests of the same kind succeed. A disposable
v1231 probe now differentiates D6FS FCB/type gate, reader-loop,
and block-I/O failures. Its independently built full guest reproduced
the tenth RUN failure with `provider_calls=060` octal (= 48),
`provider_bad_fcb=1`, `reader_fail=0`, `block_io_fail=0`, and
`provider_result=-1`. The last provider request is exactly the same
vnode and `01572` words as v1230. The failure occurs **before** the
payload reader loop or block I/O, within `d6fs_provider_fcb` or its
subsequent REG/SYMLINK type gate. A successful preceding VFS stat
does not prove FCB state remained valid by the next read. Next
instrument `d6fs_reader_fcb` (block fetch vs decode-validation) and
the provider's post-FCB type gate. Do not treat this as a physical
disk failure, and do not select a permanent idle-stack size yet.
NO production change or accepted F07 closure.

## 2026-11-06 v1224-v1227: F07 idle kernel-stack overflow identified (OPEN)

Hardware SIMH write watchpoint on a *fresh* full v1224 256K release-media
guest stopped exactly as a second `PUSH 17,011` in
`proc_swap_exchange_pair_v826` (runtime PC `033637`, relative MRES
offset `000011`) overwrote PID 1's descriptor meta at physical `047062`
with `000000000003`. Four previous writes were valid transition-bit
updates; KINIT had published the intact descriptor `047645400001`
and process table base `047057`. The standard permanent slot-0 idle
stack is allocated at only `0100` octal = 64 words, before the process
table; this is an actual stack overwrite, **not an ordinary u-area
release**. See `$TMPDIR/daimos-f07-watch-v1224r1.log` for the complete
sequence with physical PC and original MM/descriptor locations.

Increasing both disposable boot allocation and native assembler stack
watermark bound to `0140` octal = 96 words did not fix v1225: it
admitted only six additional children and halted directly in the
checked `proc_swap_storage_invariant_v30` at `023053`. A fresh
v1226 guest with SIMH instruction history captured the reason: the
swap exchange reached `proc_swap_exchange_records_v786`, where the
incoming B VM descriptor already had invalid nonzero resident base
`033445` (full word `340000033445`) although B must be disk-backed.
The exchange correctly refused unsafe publication. The candidate
selection adds a 52-word caller-owned graph on top of the idle swap
stack; 96 words are not sufficient evidence of safety. An isolated
`0400` octal (256-word) disposable-only upper-bound test was started
as v1227; **no permanent stack-budget change has been accepted**.

The test-only v1225 script keeps KINIT C allocation and native
watermark size synchronized. Source/build and host checks pass;
reassess the least safe-size RAM cost from measured highwater after
the complete guest test rather than selecting an arbitrary larger
permanent reserve. F07/E13/F11 remain OPEN, 59/64 gates and production
requester OOM OFF.

## 2026-11-06 v1219/v1220: swap-in fragmentation and lost PID 1 u-area (F07 OPEN)

Diagnostic-only, unaccepted F07 results. The v1219 256K KCC DSK/D6FS
guest stopped at the existing fatal HALT after six of eighteen additional
RUN children. At its first failed real process swap-in, native MM returned
`-2` (fragmentation), with PID 1 requesting `044000` octal = 18432 APR
words, `067075` octal = 28221 total free words, 35 MM descriptors,
and **neither LOW nor HIGH had an aligned fit**. The guest's actual state
confirms pressure is fragmentation, not descriptor exhaustion. The new
v1219 read-only verifier reports these exact values from the preserved
full guest and kernel map; it does NOT certify F07.

The subsequent independently built v1220 guest captured the same failure
class (`-2`, 18432 words, 35 descriptors, 28204 free words). The existing
v1217 fatal-owner probe recorded PID 1 still current and scheduled RUN,
yet its descriptor had `meta=3`, `vm=1` and `file_table=026`, with the
missing-FILE-owner fatal branch taken. The v1220 `proc_uarea_release`
probe observed **zero calls, including zero PID 1 releases**: the lost
u-area flag/base is NOT explained by an ordinary u-area free. The
v1218 swap transaction probe had observed PID 1's descriptor intact at
swap-out/in entry and return. Next isolate the intervening writer or
corrupted process-table pointer / MM extent and do not paper over this
with another scheduler retry. The v1208 fallback and v1211 no-reclaim
allocator are still experimental; no accepted guest or production change.

The diagnostic-only simulator replay of an already booted mutable media
image is not valid acceptance evidence; each new regression must boot a
fresh isolated release-media image. F07/E13/F11 OPEN, 59/64 completed,
production requester OOM OFF; no commit/push of these experimental edits.

## 2026-11-06 v1206: simultaneous real-process and MM-descriptor pressure (partial F07)

The disposable v1206 test composes v1205's 12 genuine user
processes (six original, six distinct user RUN/BRK/independent
sleeping children) with 96 real one-word MM_TYPE_KERNEL_DYNAMIC
extents owned by a unique test owner. The original separate D6FS
provider lease and pre-dispatch waiter remain held during the
real physical BRK OOM failure. The 96 descriptors are freed through
real type/owner-checked MM, with exact final release verification.

Both isolated enabled/disabled 256K KCC DSK/D6FS guests PASS:
**12** resident real process APR extents, **127/136** descriptors,
**231108** allocated MM words (95.4 percent of managed core),
**5499** exact logical BRK/APR padding words, one original 128-word
shared filesystem workspace and original `7,,0` provider lease.
Enabled/disabled free MM words are 11123/11137; managed area
242231/242245 words. All 96 typed frees, protected owners,
requester-only OOM (test enabled) or -1 return (production-off),
TERM/WAIT and full MM/slot accounting PASS. A seven-negative-mutation
host verifier rejects forged owner, missing pressure, invalid
release, insufficient real process images and stolen FS lease.

v1206 removes v1204's 12 large synthetic 8K-word blocks; all
high physical occupancy is from actual executable user VMs.
The experiment does **not** create 64 concurrent logical process
slots or sample simultaneous worst-case private-stack highwater.
F07 remains OPEN, production requester OOM remains disabled.

## 2026-11-06 v1205: real concurrent user-process/BRK snapshot (partial F07)

The disposable v1205 guest extends the v1150/v1159/v1203 256K
DSK/D6FS physical-OOM profile with **six more real RUN children**
before the foreign filesystem provider is held. The 12 live user
processes keep their own executable VM images, private u-areas,
published logical BRK values and actual MM_TYPE_PROCESS ownership.
An allocation-free test-only probe captures up to 64 process slots
at the same genuine BRK physical-OOM decision as the MM extent table.
The host verifier reconciles every resident APR base/extent size,
each exact logical BRK, owner and state; it rejects five bad fixtures.

The OOM-enabled first guest PASSes with 12 resident process extents,
31 descriptors, 231012/242427 managed words allocated (95.3%),
11415 free words, 10377-word largest gap, 151-word actual LOW APR
gap-prefix slack and **5499 actual logical-BRK rounding words**.
The separately booted production-disabled guest PASSes with the
same 12 resident user processes, 31 descriptors, 231012 allocated
words and 5499 exact rounding words; its managed/free words are
242441/11429, exactly 14 more than the test-enabled policy.
All original held-provider, protected-process, requester-only OOM,
final child TERM/WAIT and process-MM accounting assertions PASS in
both policy profiles. Both complete physical-release-media archives
contain raw simulator, map, compiler and checksum evidence.

Two instrumentation errors found in development were fixed properly:
reserved kernel slot 0 is not a user process, and PDP-10 AC0 is
not a valid index register (the sampler now uses AC7). Raw failing
guest snapshots were retained for diagnosis. No production source
change was necessary. The full 64-slot concurrent swap stress and
combined real-process/127-descriptor test are still outstanding;
do not close F07 or enable production OOM from these partial results.

## 2026-11-06 v1204: high physical and descriptor pressure under held provider PASS

F07 disposable `daimos-f07-mm-high-v1204` allocates 12 genuine
APR-aligned 020000-word MM extents plus 96 genuine one-word MM
extents, in the already-booted 256K KCC DSK/D6FS guest while a
foreign filesystem provider holds its original private-stack lease.
This adds 98400 physical words and 108 descriptors without touching
production code. It then triggers the original genuine BRK physical
OOM fault, samples live MM state at that decision, and frees every
test-owned extent through exact type/owner-checked MM release.

Both disposable OOM-enabled and production-disabled guests PASS:
127/136 live descriptors (six APR process images, 121 dynamic
extents), 211092 allocated managed physical words, about 87 percent
of the managed arena, 108/108 exact releases, and zero probe errors.
The provider lease, original gateway owner, unrelated processes,
WAIT statuses and final MM/process accounting are preserved.

The v1204 host fixture rejects seven unsafe mutations. It also
identified a defect in the earlier v1203 host verifier: APR alignment
uses `02000` octal = 1024 words, not 512. The corrected maximal
placement and logical-break rounding bounds are 1023 per gap or
live process extent, not 511. Actual LOW gap-prefix slack is still
measured from the MM table; the bound correction never relaxes
real alignment or overlap validation. Previous v1203 evidence using
the incorrect bound is superseded for those two computed fields.

F07 is not yet closed: six live process images are not the maximum
simultaneous process-slot population, and exact logical-break use
in each process was not captured. Production requester OOM stays OFF.

## 2026-11-06 v1203: simultaneous F07 physical-OOM MM snapshot PASS (partial)

Disposable `daimos-f07-mm-peak-v1203` instrumentation samples the
live 136-slot MM extent table and managed-core arenas at the actual
physical BRK `-1` decision, while a foreign D6FS provider is leased.
It does not allocate, acquire a lease, sleep or push a kernel stack
word in the sample path. The full 256K KCC DSK/D6FS release-media
guests PASS with requester OOM test-enabled and production-disabled.
Both pass original v1150/v1159 owner, scheduler progress and final
release checks; 10 negative host-accounting mutants also PASS.

At the fault each has 19/136 live descriptors, six APR-aligned
process extents, 13 kernel-dynamic extents and 112692 allocated
MM words, with a held 128-word shared filesystem workspace.
Enabled/disabled managed/free words differ by 14 because of test-only
OOM code residency. Exact free-gap/APR low-placement slack metrics
and full SIMH/build/map/media/tool checksums are archived in the
versioned v1203 evidence. F07 remains OPEN: this is an actual
simultaneous observation, **not** maximum simultaneous process,
descriptor, physical allocation or provider-buffer pressure.
Production kernel, OOM switch and ABI are unchanged.

## 2026-11-05 v1196: physical MM peak-boundary subcases PASS (F07 partial)

Fresh current-source PDP-6 256K/full DSK/D6FS disposable OOM-enabled
guests `test-daimos-oom-mm-slots-enabled-v1114` and
`test-daimos-oom-mm-fragment-enabled-v1115` both PASS. v1114
fills real MM descriptor capacity (136), correctly refuses new
RUN without killing its parent and releases original allocations;
v1115 creates real aligned extents and fragmentation despite
sufficient aggregate free RAM, preserves internal MM cause `-2`,
does not kill the requester, and restores allocator accounting.
Both guests also PASS v1075 real requester-only physical OOM,
v1110 invalid BRK and v1112 parent-safe failed child RUN.

Together with current-source v1096 P0-D preflight and private/idle
stack watermark passes, outputs and tool checksums are archived in
`$TMPDIR/daimos-f07-mm-evidence-v1196.tar.gz` (SHA256
`77f7f35141dc1aef84ed0a294b80d6521be8f42de77376f14993891bf54297a8`).
F07 is still OPEN: actual combined maximum-load APR-alignment slack,
MM extent peak and shared provider buffer occupancy remain unproven.
No production OOM policy change; 57/64 acceptance gates complete.

## 2026-11-05 v1195: current candidate P0-D and stack checks PASS

`test-daimos-p0d-release-matrix-v1096` on the current DAIMOS source
PASSed all 18 native/source-linked owner-release tests, v1083 and
v1087 transitive no-new-allocation graph. No `P0D_FULL=1` guests
were run in this batch; A04/F02 remain open.

`test-daimos-proc-stack-watermark` PASSed highwater `0300` octal
(warning limit `0310`, capacity `0316`). After repairing v1192
DBOOT conversion in v1194, the fresh
`test-daimos-idle-stack-watermark` 256K PDP-6 guest PASSed with
idle highwater `025` octal (limit `060`). The initial build failure
was genuine mkauxstore incompatibility, not a stack measurement.
F07 is NOT closed; descriptor/extent, APR alignment and provider
buffer peaks remain to be audited. Production OOM is still OFF.

## 2026-11-05 v1194: AUXSTORE explicit DBOOT conversion regression

The v1192 explicit-zero DBOOT marker exposed a compatible-media
regression in `mkauxstore --convert-dboot`: the auxiliary-drum
precursor was correctly flagged as explicit and rejected by the
old exact-legacy DBOOT allowlist. The corrected converter accepts
only flag `0` or `1` at octal descriptor word `020`, and retains
strict rejection of all other nonzero descriptor metadata.
Expanded v638 destructive-conversion tests PASS for both modes,
unknown flag `2`, high-bit flags, dry-run image immutability and
original D6FS payload survival. Original v636 destructive-format
safety tests PASS. Fresh current-source P0-D component matrix
(`test-daimos-p0d-release-matrix-v1096` without `P0D_FULL=1`)
also PASSes all 18 source-linked release stages and the v1087
allocation-free graph. This is not A04/F02 full-guest acceptance.
Production OOM remains disabled.

## 2026-11-05 v1192: D6FSR2 explicit-zero layout regression PASS

`test-daimos-d6fs-explicit-zero-layout-v1192` compiles fresh host
mkdsk/mkd6fs/d6fsck binaries with strict warnings and PASSes:
modern explicitly zero bootstream/LOGSTORE/BADMAP reservations (no
legacy warning), flag-0 old-media compatibility (legacy warning
retained), malformed flag 2 and high-bit flag rejection, and mixed
flags across two physical disk members. The KINIT BLOCKSET boot
decoder also rejects unknown/mixed flags; DAIMOS compiles its new
kernel code with `-Wall -Wextra -Werror`.

The existing v1190 F10 diagnostics auditor continues to PASS all
four frozen archived release-media builds and its negative mutants.
The legacy warning is recognized when present on old images and
is no longer *required* on new, correctly flagged v1192 media.
This is a disk-format compatibility correction, not an OOM gate.
Production requester OOM remains OFF.

## 2026-11-05 v1190r1: F05 out of OOM scope; F10 evidence accepted

User scope decision retires static 16K permanent KCORE/MRES fit
(former F05) as an OOM gate, without marking it as passed. Its
measured permanent-size overflow remains a separate KCORE/MRES
optimization issue. The OOM count is now 64, not 65.

The v1190 checker independently PASSed its three injected-diagnostic
negative mutants and four complete release-media build logs from
`$TMPDIR/daimos-oom-residency-v1174.zpheEd.tar.gz`
(SHA256 `6f660d1ad5522467332063bffc5f63fb4e2bb162889e9999e7dcf7a5ca36fbbf`)
and `$TMPDIR/daimos-oom-residency-linux-v1176.tar.gz`
(SHA256 `fd0b4cac80677ae7a9eadabfe83c94192ea644f3c800a23ba599020f99e44b87`).
Both policies on both hosts report 13 matching, explicitly cataloged
diagnostic classes and no unexplained compiler/assembler errors.
Known KCC/legacy D6FS warnings remain visible; the filesystem
verification is CLEAN. F10 is CLOSED on this frozen evidence.
Final-candidate source and diagnostic revalidation remains mandatory
under A04/F02/F11, and dynamic peak-MM safety F07 remains OPEN.
**57/64 OOM checks complete, 7 open** (5 pre-enable plus F12/F13).
Production OOM remains OFF; no production changes were made.

## 2026-11-05 v1190: OOM release diagnostics and stress audit PASS

New `test-daimos-oom-build-diagnostics-v1190` examines the complete
KCC/KINIT/DSK/D6FS disabled and test-enabled release-media build logs
from Android/aarch64 and Linux/x86-64. All four logs contain only
the same thirteen explicitly cataloged KCC informational-note or
known legacy D6FSR2-format warning classes; there are zero
unexplained compiler/assembler diagnostics. The legacy warning is
checked against an actual clean d6fsck superblock selection, not
silently removed. Three injected unexpected-warning/error mutants
are rejected by the v1190 checker. Test-only OOM remains isolated
from production source; `PROC_OOM_BRK_ENABLED_V1000,0` is unchanged.

Fresh Linux `v1151` enabled and disabled endurance guests, on
DAIMOS `96e6c695` with KCC `b9cd764`, each PASS 32 true
physical OOM/recovery cycles, 256 PID lifetimes, 512 stale requests,
at least 1024 PI6 ticks and exact stable MM/backing/slot accounting.
The log and SHA256 archive is
`/home/theseus/tmp/daimos-f07-endurance-evidence-v1189.tar.gz`
(`0c01e4e98460a926e829daf85c2c224e20f2f5125d836885ea90dfa6138bfec1`).
Independent process/private and idle kernel-stack watermark tests
PASS (0300 octal below 0316 capacity; idle highwater 025 below 060
limit). Full peak MM/APR/provider-buffer sizing is still F07 work.

Together these results support F10 release-source diagnostics
acceptance; final source/release signoff F11 and 16K-fit F05 remain
OPEN. No production OOM activation, MRES runtime changes or KCORE
code modification.

## 2026-11-05 v1184-v1185: F04 exact cause/ownership PASS

The corrected-toolchain Linux/x86-64 DAIMOS `96e6c695`
acceptance has eight additional positive/negative resource tests
on top of the 14 F03 cases, all PASS: v1113 real VM BRK MM -2/-3
and mutation rejection; v1156 DISK backing exhaustion with BRK
survival in disabled/enabled policies; v1158 independent RUN parent
surviving -3 and another requester's physical OOM in both policies;
v1157 APR/postcommit EXEC under held foreign FS provider plus
unpublished RUN retry; v1106 real pinned VM/u-area MM_BUSY and
v1077 actual D6FS SYNC/MM_BUSY through physical OOM.

Evidence: Linux `$HOME/tmp/daimos-f04-cause-evidence-v1184.tar.gz`
SHA256 `5c12dce02fe1877a47c19afa9e9339e1a466a39f79526d1960617a048ee69096`.
F04 is CLOSED for ordinary writable RUN/EXEC/BRK. F09 is also
recorded as a separate complete operator document in
`pdp10-doc/KERNEL/OOM-FAIL-CLOSED-RECOVERY-V1185.MD`; it
expressly does not promise bounded completion of a dead provider.
DAIMOS mandatory checklist 54/65; production OOM OFF.

## 2026-11-05 v1181: F03 seven-scenario, two-policy guest matrix PASS

On fresh Linux DAIMOS `96e6c695`, corrected KCC `b9cd764`
and independent Open SIMH `edd19b17`, all 14 required booted
positive/negative OOM guests PASS: v1075 real physical requester OOM;
v1110 invalid-floor/address BRK; v1112 failed child RUN; v1114
descriptor saturation; v1115 fragmented physical MM with -2 cause;
v1116 descriptor-shortage RUN with exact -3 cause; v1120 repeated
PID reuse and stale WAIT/TERM refusal. Enabled cases kill only the
eligible requester on real -1 MM exhaustion; disabled cases preserve
the requester and return BRK -1.

The v1175 compiler fix makes full 256K MM capacity correctly 136
descriptors, exposing an obsolete 32-base cap in the disposable
v1114 assembly test. Testkit `03e8325` expands its scratch base
array to 136 words; disabled and enabled reruns PASS. This is a
test-only fixture change, not an MM allocator or kernel change.
The full 14 PASS logs, SHA256 manifest and source/toolchain IDs
are archived at `/home/theseus/tmp/daimos-f03-verified-evidence-v1181.tar.gz`
on the Linux host, SHA256
`dab45fce94cd6350bfb32e7b1683010f85bb7d93e4a6fd60b4996d17d49bb6bc`.

F03 is complete. DAIMOS mandatory checklist 52/65; production
requester-OOM remains OFF. E13 and F02/F04-F11 remain open and
post-enablement F12/F13 cannot run yet. No test result justifies
runtime unloading or OOM reclamation of boot-installed MRES.

## 2026-11-05 v1174-v1176: measured OOM guest residency and compiler fix

The new v1174 release-media residency test boots both isolated physical
requester-OOM policies with actual 256K DSK/D6FS media, and checks the
userland SYS_MEMINFO resident count against the KINIT-patched MOVEI at
the actual SIMH memory address. It independently checks the 256K
process-slot count (64), the 136-entry MM descriptor capacity, and the
initialized/BSS KCORE map boundaries. Android aarch64 and Linux x86_64
archives both PASS. v1176 independently accounts for all installed
MINIT MRES images, rather than all linked packages: 22 permanently
installed modules, 8837 words on Android and 8839 on Linux. Differences
reflect actual independent host/source-built packages, not unloadable
MRES. No MRES is dynamically loadable, unloadable or OOM reclaimable.

With v1175 corrected KCC on Android, the test-only disabled guest
records 9944 KCORE + 272 permanent MM descriptor words + 8837 MRES =
19053 resident words, and enabled records 9958 + 272 + 8837 = 19067.
These are instrumented guest sizes; neither is an uninstrumented
production memory acceptance. The disabled guest exceeds the separate
octal 040000 (16K) permanent address budget by 2717 words, enabled by
2731 words. F05/F06 remain OPEN; no budget relaxation or OOM enable.

Real compiler defect identified during the audit: optimized KCC could
drop a live incoming argument held in preserved AC10 while flushing a
MOVE/MOVEM peephole, making 256K MM capacity appear as 24 instead of
136 entries. The six-line compiler correction in KCC b9cd764 retains
copies into preserved registers. New v1175 reproducer and actual
production mm_boot_init code-generation test PASS under that compiler,
and the pre-fix negative control fails. The KCC commit exists locally;
upstream publication remains an independently verified prerequisite.

The evidence closes no new release gate by itself. Checklist remains
51/65, production requester-only OOM remains disabled, and final F02,
F03-F11 and E13 review continues.

## 2026-11-05 v1163: second E13 host and cross-platform counter audit PASS

Fresh Linux x86_64 Open SIMH PDP-6 V4.1-0 (`a6b511e5`) E13
`test-daimos-oom-release-media-v1160` guests PASS with real DSK/D6FS
release media in both isolated requester-OOM-enabled and default-off
modes against DAIMOS `90dfc8d0` and testkit `4e7dd86`. Exactly one
real physical BRK OOM occurs per guest, with exclusive slot-3 fatal
selection when enabled, zero selections when disabled, preserved
INIT/witness/waiter/spinner/foreign filesystem owner, original held
provider lease and final FILE/WAIT/MM recovery. Both show 160 spinner
advances and zero integrity errors. The Linux evidence archive
`/home/theseus/tmp/daimos-e13-release-media-v1160.wPB6WE.tar.gz`
has SHA256 `b80eb98991845b89fb56344cb621c22eb3e8fd79aff185912163c5406f3e86fd`.
An independently verified copy is kept under
`$TMPDIR/daimos-e13-linux-x86_64-v1163.tar.gz` on the Android host.

New `test-daimos-oom-cross-platform-v1163` checks the complete Android
and Linux archived boot profiles, original simulator SHA256 fingerprints,
physical-OOM process table and provider counters and KCORE low ends.
Both hosts agree: disabled `023410`, test-enabled `023426` octal.
Those are *disposable instrumented* kernels, not final production
KCORE/MRES residency or 16K limit proof.

Linux first revealed an outdated installed `mkauxstore` that did not
accept the current destructive-format confirmation protocol. Strict
glibc C99 rebuild also exposed undeclared POSIX `fileno`, `fdopen`
and `lstat`; DAIMOS `90dfc8d0` sets `_POSIX_C_SOURCE=200809L` before
headers. v636 safety and v638 DBOOT conversion PASS on Android and
Linux; corrected `/usr/local/bin/mkauxstore` installed on Linux with
the previous binary backed up. No production kernel change.

E13 remains OPEN: first Android guest used DAIMOS `27acb950`, while
Linux used `90dfc8d0`, and independent OpenBSD/other required targets
have not yet been reproduced. Linux KCC notes (identifier truncation,
unused symbols) and legacy D6FS layout warning remain F10 review
items. Mandatory acceptance remains 51/65, production OOM OFF.

## 2026-11-05 v1161: frozen-candidate A04/P0-D component preflight PASS

On DAIMOS `fe0f3c0e`, the unmodified
`test-daimos-p0d-release-matrix-v1096` (without `P0D_FULL=1`)
PASSes all 18 source-linked/native release-stage fixtures:
PIPE/FIFO typed final close, DPY replacement and MM ownership,
swap/backing detach and retry, HUP, u-area/MM typed free,
PREVM clock and reaper backoff, unpublished RUN discard,
TTY/VM finalization, XIP/MM release and VM_NONE idempotence.
The included v1083 direct-scope audit and v1087 transitive
BRK/APR/EXEC -> FILE/VFS/FS -> PIPE/DPY -> TTY/VM/XIP/MM/SWAP/WAIT
allocation-free graph PASS, with error/owner transitions checked.

This is a **component preflight only**. The script explicitly
reported `disposable full guest matrix skipped (set P0D_FULL=1)`.
Therefore neither final-candidate A04 nor F02 is closed; both need
the booted matrix at the final frozen release revision. The
production OOM switch remains OFF. No source changes required.

## 2026-11-05 v1160: explicit E13 256K DSK/D6FS boot/media PASS

Fresh 256K KCC PDP-6 `test-daimos-oom-release-media-v1160`
PASSes on Android aarch64 Open SIMH V4.1-0 `pdp6` (`edd19b17`)
for both production-disabled and disposable-enabled requester BRK
OOM. The test explicitly builds `BOOT=dsk ROOT=disk ROOTSET=1`,
full 256K, PCLK REALTIME/60 Hz, CTY headless, real generated DSK
root and drum AUXSTORE. It uses the normal image construction
and only a disposable INIT and fault probes. Actual D6FS, BLOCKSET,
LOGSTORE, MEMFS and TTY initialization is seen in the simulator.

In both guests a real physical MM shortage occurs while a separate
filesystem gateway owner retains its lease. Disabled returns -1
with zero fatal selections; enabled selects exactly requester slot 3.
Both verify protected INIT/witness/waiter/spinner/holder at the OOM
point, original-owner return/unlock, 160 spinner advances, zero
integrity errors and exact final FILE/MM/process WAIT bookkeeping.
Full simulator/counter transcripts, build logs, KCORE/init maps,
real boot.ini, host tool and D6FS-root media SHA256 are archived:
`$TMPDIR/daimos-e13-release-media-v1160.qel3Zm.tar.gz`.

The 256K DSK/D6FS first release candidate is described in
`pdp10-doc/KERNEL/OOM-RELEASE-PROFILE-V1160.MD` (S07/S08 closed).
E13 remains OPEN until required other targets/media are covered;
this simulator guest uses a test-only INIT, so normal userland swap
activation is not thereby certified. 51/65 mandatory checks complete,
14 open (12 pre-enable plus F12/F13). Production OOM remains OFF;
no production kernel, RAM, ABI or permanent MRES changes.

## 2026-11-05 v1159: E12 protected processes under genuine BRK OOM PASS

Two freshly built full 256K PDP-6 guests PASS
`test-daimos-oom-protected-v1159` and its production-disabled control.
The existing v1150 real physical-OOM/foreign-provider regression is
retained, with test-only snapshots at the actual MM -1 BRK decision
point. A separate faulting slot 3 is the only selected fatal victim
when the requester-OOM switch is enabled; the disabled guest records
zero fatal selections and returns BRK -1. Both guests prove that
slot 1 INIT, slot 2 blocked pipe witness, slot 4 gateway waiter,
slot 5 independent spinner and slot 6 original in-flight provider
owner remain live at the decision point. The original lease is
later released by its owner, not stolen or force-freed.

Enabled: one genuine physical OOM, one slot-3 selection, seven
foreign fatal-close BUSY attempts, 160 spinner advances, one
provider-owner return and zero integrity errors. Disabled: one
genuine OOM, zero selections, ordinary requester FILE close/wait,
160 spinner advances, one provider-owner return and zero errors.
Both existing full-system WAIT and MM/FILE accounting checks PASS.
The experiment does not claim an INIT exemption if INIT itself
requests a failing BRK; it proves nonrequester protection.

E12 accepted for supported writable-process requester-only scope:
49/65 mandatory checks complete, 16 open (14 pre-enable plus
F12/F13). E13/S07/S08/A04/F02-F11 remain. No production KCORE,
MRES, ABI or permanent RAM changes. Production OOM remains OFF.

## 2026-11-05 v1158: E11 independent RUN parent and physical BRK OOM PASS

Two freshly built 256K PDP-6 full-system guests PASS
`test-daimos-oom-run-parent-v1158` and its disabled counterpart.
A separate live witness process fills genuine MM descriptor slots,
attempts an ordinary child RUN, observes real -3 VM/u-area allocation
failure, verifies no child slot or process words remain, and restores
the original descriptors. A parent/child pipe acknowledgment proves
this happened before INIT launches an independent physical BRK-OOM
requester. The failed-RUN parent remains waiting and alive across the
other process's OOM; it later exits normally with exact parent WAIT.
Enabled policy kills only the BRK requester, while production-disabled
policy returns -1. Both recover original process RAM/slot accounting.
Only the disposable copied kernel carries the fault-injection MM
descriptor probe and enabled OOM switch. Production remains unchanged.

## 2026-11-05 v1157: E10 held-provider APR/EXEC/RUN PASS

Fresh `make test-daimos-fatal-exec-provider-v1157` full 256K PDP-6
guest PASSes on DAIMOS `a7b721b4` and testkit `436552f`.
The original foreign filesystem gateway owner retains its lease,
an asynchronous APR fatal event occurs in post-commit EXEC cleanup,
and unpublished RUN rollback hits actual physical u-area MM_BUSY.
FD3 survives staging until real foreign-provider lock contention;
the original owner resumes and unlocks, and WAIT/FILE/MM accounting
is exact. Six VFS calls, five refusals, seven FILE retry passes,
six sleeps, one pin/busy/unpin and zero integrity errors are recorded.
The previous retained v1157r11 PASS is independently reproduced.
E10 accepted for writable-process OOM scope; 47/65 checks complete,
18 open. No production KCORE/MRES/RAM/ABI changes; production requester
OOM remains disabled.

## 2026-11-05 v1156: E09 whole-system MM/backing error matrix PASS

The frozen `test-daimos-oom-error-matrix-v1156` run PASSes all nine
native and full 256K PDP-6 error-class cases against DAIMOS
`9f51326e` and testkit `81f40eb`, with fixed P10FOLD/DLINK/DAS/PDP6
checksums and logs under
`$TMPDIR/daimos-oom-error-matrix-v1156.gzw27g`.
Authentic RAM shortage (-1), fragmentation (-2), MM descriptor
pressure (-3), invalid or wrong owner (-4), and pinned owner (-5)
remain distinct. The v1156 disk-full cases actually saturate the
production backing allocation bitmap, verify a second allocator
refusal is atomic, then restore original ownership and exercise
ordinary successful BRK. Both normal OOM-disabled and isolated
OOM-enabled guests PASS without wrongly terminating the requester.
The native full-bitmap contract also rejects unsafe mutants.

E09 is CLOSED for the writable-process activation scope: 46/65
checks complete, 19 open (17 pre-enable plus F12/F13). E10-E13,
S07/S08, A04, F02-F11 and resident/peak RAM checks remain open;
production requester OOM is still OFF.

## 2026-11-05 v1155: E08 concurrent sessions/group lifecycle PASS

The full 256K PDP-6 `test-daimos-oom-groups-sessions-v1155`
guest PASSes twice, with a fresh independent v1155 build and
retained completed preceding build; the unmodified v979 event
fixture also PASSes on a separate fresh guest. The expanded
v1155 fixture creates two independent live session leaders
using pipe-backed child-ready barriers, plus two different
two-member process groups. STOP/CONT group delivery and
exact per-child WAIT/CHLD are verified; both groups then
terminate independently with exact event statuses and
no second/stale WAIT or wrong-session death.

While both foreign sessions are still alive, 64 additional
numeric PID lifetimes each RUN a child, deliver ALRM,
WAIT for the expected exit and reject stale WAIT/TERM.
Each session is then terminated/reaped separately, followed
by exact final process-slot, process-word and FILE-slot
accounting. In-development v1155 r1 timed out before the
session markers, but completed r2 and independent r3 PASS.

This supplies E08 acceptance without changing production
KCORE/MRES/RAM/ABI or the disabled requester-OOM switch.
The remaining OOM gates are E09-E13, S07/S08, A04,
F02-F11 and later F12/F13 (45/65 complete).

## 2026-11-05 v1154: E07 actual PI6/bystander release matrix CLOSED

The full 256K PDP-6 `test-daimos-oom-disk-pi6-v1154` guest PASSes the
original v1122 PIPE physical MM_BUSY and distinct DISK bitmap-refusal
and exact backing restore, with an added unrelated separate-session
user. At the *first* real DISK allocation-bitmap verification failure
the qualified PI6 clock is 1015; at the successful verifier retry it
is 1032. The independent user executes eight genuine sleep/wakeup
syscalls between those exact failure/retry boundaries. Both bitmap
verifier calls, one corruption/restore, one physical PIPE MM release,
the original DISK record, and terminal WAIT/TTY accounting PASS with
zero error counters. Test-only instrumentation never substitutes a
clock event, MM return, or filesystem-provider result.

Together with the v1153 full guest (55 real PI6 ticks and three
independent user sleeps between PIPE MM_BUSY and final publication,
with physical DPY/VM/u-area and held foreign provider) and v1148
(32 real PI6 ticks and live unrelated session during pinned TTY,
VM/u-area and deferred HUP), this covers every E07 resource class.
E07 is accepted for the currently supported writable-process scope.
Mandatory OOM status: **44/65 complete, 21 open** (19 pre-enable
blockers plus F12/F13). E08-E13 and F02-F11 remain open. No
production KCORE, MRES, RAM, ABI, or OOM policy changed.

## 2026-11-05 v1153: E07 mixed physical PI6/bystander evidence (partial)

The new `test-daimos-oom-pi6-spinners-v1153` independently rebuilds
one 256K PDP-6 full guest using the unchanged production kernel and
the v1144 disposable physical PIPE/DPY/VM/u-area/foreign-provider
fault matrix. Additional test-only witnesses capture the qualified
PI6 clock and unrelated-user sleep count at the first genuine PIPE
MM_BUSY and the final slot-5 ZOMB publication. The first guest PASSes:
clock 1297 -> 1352 (55 actual ticks), unrelated user sleeps 25 -> 28
(3 after the initial MM_BUSY), exactly one pin/busy/unpin/free per
physical owner, one final publication and zero MM/FILE/DPY errors.
The provider lease remains held and no fake timer or allocator return
is introduced. The unchanged v1144/1117/1106/1103 checks also PASS.

This adds concrete post-fault progress evidence for E07 PIPE/DPY/VM
and held provider; the DISK backing interval and full E07 matrix are
NOT yet accepted. Production requester OOM remains OFF. The branch
is isolated from concurrent v1151 E05/E06 endurance acceptance.

## 2026-11-05 v1151r1: sustained physical OOM/recovery E05/E06 PASS

Post-acceptance compatibility rerun: the original
`make test-daimos-oom-pid-reuse-v1120` also PASSes on the current
testkit after the v1151 fixture extension, retaining its original
24-lifetime, alternating-WAIT-status and stale-event checks.
The retained run log is
`$TMPDIR/daimos-v1151-legacy-pid-v1120-r1.log`.

Two independently rebuilt 256K PDP-6 full disk-root guests PASS the
`test-daimos-oom-endurance-v1151` and
`test-daimos-oom-endurance-disabled-v1151` targets. Each performs the
original physical-OOM/witness test, 32 additional genuine BRK
physical-MM exhaustion cycles, and an intervening successful RUN
with real BRK growth/shrink. It then completes 256 numeric PID
reuse lifetimes with alternating WAIT statuses and 512 stale
WAIT/event refusals. Every wave verifies stable process slots,
process words, FILE slots, disk swap blocks, and MM descriptors;
the actual qualified PI6 clock advances at least 1024 ticks.
The test-only counter verifies a distinct physical-MM cause -1
for each OOM request, rather than synthetic allocation failures.

The first enabled run correctly exposed a test-accounting problem:
after one successful recovery RUN, the MM descriptor count was
7 -> 8. A preserved halted guest's physical MM table proves the
new `0201`-word extent is the existing clean BCACHE slab, owner 6,
base `0777577` octal. Production BCACHE deliberately retains this
one reclaimable extent. The corrected test-only read-only BCACHE
base probe subtracts exactly its current presence and still
requires strict equality for all non-cache MM extents; a subsequent
real physical OOM must reclaim the slab. This is not a relaxation
of the process or backing leak criteria, and production MM is
unchanged. The production-disabled guest additionally emits one
normal BRK-return `D` for each of the 32 waves. The v1151r1 wrapper
asserts precisely 32 such markers, instead of rejecting that
valid output. Both fully rebuilt guests now PASS.

Retained opt-in enabled guest/log:
`$TMPDIR/daimos-oom-requester-live-v1075.LlPPRq` and
`$TMPDIR/daimos-v1151-endurance-enabled-r3.log`.
Retained production-disabled guest/log:
`$TMPDIR/daimos-oom-requester-live-v1075.QJLF2A` and
`$TMPDIR/daimos-v1151-endurance-disabled-r2.log`.
E05/E06 are accepted for the 256K writable-process scope; the
mandatory checklist is 43/65 complete, with 20 pre-enable blockers
and F12/F13 still open. E07-E13, final RAM budgets, warning review
and release-candidate reruns remain mandatory. Production requester
OOM stays OFF. All probes are exclusively in disposable test images.

## 2026-11-05 v1150: B06 real physical OOM with provider lease PASS

The v1150 disposable full-system PDP-6 guests PASS in both opt-in
requester-OOM-enabled and production-default-off configurations,
each independently compiled with a fresh 256K disk-root image.
The original OOM requester opens `/SYSTEM/INIT` for real FILE close
work, then waits for the parent to release its pipe trigger. Another
child obtains the true serialized provider lease (slot 6, encoded
`7,,0`) and sleeps *inside* the acquired gateway on its private
executive continuation. A third child sleeps before provider dispatch
on the production gateway event, and a fourth user advances normally.

The real BRK fails with physical-MM cause -1 while the held lease is
still `7,,0` and the pre-dispatch waiter still has a SLEEP/event
continuation. In the enabled guest, the requester alone is killed;
seven actual foreign-provider FILE close attempts/retries preserve
the lease until slot 6 resumes through the existing provider-unlock
path. The disabled guest returns BRK -1 to the requester; its ordinary
EXIT waits on the provider event once before the holder returns.
Both guests record one held-owner entry/return, one physical OOM,
one pre-dispatch waiter, 160 independent user advances, zero error
witnesses, final WAIT statuses, the surviving witness, and stable
MM/slot accounting. The original v1075 flags are left unchanged.

B06 is accepted for the current writable-process scope. Mandatory
count: 41/65 complete; 22 pre-enable blockers remain plus F12/F13.
No production KCORE/MRES/data/ABI change; requester-OOM default stays
OFF. E05-E13 stress, final release configuration and RAM audit are
still open.

## 2026-11-05 v1149: B07 unbounded owner lifetime accepted

The new `test-daimos-oom-unbounded-owner-v1149` source contract
PASSes on current production PDP-6 assembly, rejecting eight unsafe
mutations: fatal owner stopped after a capped delay, changed delay
threshold, owner-forced MM free, remote owner finalization, stolen
provider lease, forced unlock, inverted slot-0 failure handling and
reset slot-0 backoff. It verifies a capped *interval*, not a capped
owner lifetime, preserves the original foreign lease and retains
failed slot-0 owners for later retry. The same target PASSes actual
native v885 (14 repeated FILE refusals, multiple 01000-tick delay
intervals, eventual single successful owner exit) and v1102 (shared
retry clock/backoff and four mutation rejections). B07 is accepted
as an ownership-safety contract; this does NOT certify liveness of
an indefinitely in-flight foreign provider. B06 genuine concurrent
physical OOM is still open. Production OOM remains disabled.

## 2026-11-05 v1147-v1148: integrated PI6/pending HUP C04 PASS

Fresh v1147 owner-side TTY/VM/u-area MM_BUSY and independent PI6
guest PASSes. Two fresh full-system v1148 builds also PASS with a
live same-session child, one HUP deferred to its own private kernel
stack and exactly one owner-return HUP delivery. INIT's original
session survives its first pinned-TTY EXIT refusal; a real WAIT
reaps the HUP recipient before the second owner EXIT. VM and u-area
then encounter separate real MM_BUSY faults before normal slot-0
retry completes one final release. Each v1148 build records one
HUP defer and one HUP owner delivery, all physical ownership counters
exactly one, zero errors, 32 qualified PI6 ticks after refusal and
48 unrelated-session user sleeps. Native v1098 clock/backoff and its
three unsafe mutations PASS. This supplies C04 closure for DAIMOS;
the OOM default stays OFF, B06/B07/E/F remain open.

The independent historical v885 native owner-backoff fixture has
been updated with current process-event constants, a no-session
HUP preflight, and an unexpected-runqueue guard. It PASSes 14
actual FILE close refusals with repeated capped delay and later
completion, but B07 is not declared closed by that fixture alone.

## 2026-11-05 v1146r3: frozen nine-stage D16 matrix PASS

`make test-daimos-oom-exact-once-matrix-v1146` completed all nine
stages successfully with no source/tool revision changes. The frozen
candidate is DAIMOS `2e12c1da`, testkit `253a813`, plus the installed
P10FOLD/DLINK/DAS/PDP-6 checksums recorded in `revisions.txt`.
Per-stage logs remain under
`$TMPDIR/daimos-oom-exact-once-v1146.mV2FJf`. The matrix includes
the v1087 source/native release graph and negative mutations, the
v1144 physical PIPE/DPY/VM/u-area/FILE/provider mixed case, v1124
pinned TTY/VM/u-area finalization, v1119 PIPE/DPY HUP, v1121 DPY
swap-out/swap-in, v1122 PIPE plus disk bitmap fault, v1142
APR/EXEC/unpublished RUN rollback, and v1120 physical exhaustion
and 24 PID reuse lifetimes in both disabled and test-only enabled
requester-OOM guests. All original ownership/refusal, exact-once
release, final WAIT, bystander and MM/slot accounting tests pass.

D16 is accepted for the current production writable-process scope.
This completes 38/65 mandatory checks, leaving 25 pre-enable blockers
and F12/F13 post-signoff. This does NOT imply OOM activation readiness;
production `PROC_OOM_BRK_ENABLED_V1000` remains zero. C04, sustained
E/F and physical memory/RAM budgets are still open.

## 2026-11-05 v1146r2: fresh physical PIPE plus swap-bitmap evidence

The unchanged-production 256K PDP-6 v1122 full guest PASSes on the
corrected host tools: first session member physical PIPE MM pin,
MM_BUSY, unpin and single release; second member real DISK swap
bitmap refusal, checked restoration and single detach. Terminal
WAIT/TTY ownership and all injected error counters remain correct.
This is a fresh component of D16, NOT a full v1146 matrix PASS.
Production requester OOM remains disabled.

## 2026-11-05 v1146: exact-once release matrix staged, not accepted

The versioned `test-daimos-oom-exact-once-matrix-v1146` target is a
sequential D16 gate. It retains per-case logs and stops on failure.
Its cases cover the transitive release graph, combined physical
PIPE/DPY/VM/u-area and provider lock, pinned TTY, PIPE/DPY HUP, DPY
swap replay, PIPE and bitmap swap refusal, unpublished RUN discard,
and OOM-related PID/slot recycling. Shell syntax and Make dispatch
validate. The v1146r1 guard records the DAIMOS/testkit Git revisions
and installed fold/link/assembler/simulator checksums, refuses an
uncommitted kernel or fixture, and checks revision stability before
and after each guest. Its dirty-source negative control PASSes.
The *full* multi-guest matrix has not yet been run or
accepted, so D16 remains open and the production OOM switch is OFF.

## 2026-11-05 v1145: native fatal-release fixture maintenance

The v1087 transitive-release suite PASSes with all its negative
mutations and native checks after updating two historical fixtures.
The v912 DPY replacement test previously expected generic -1 when
the actual owned rollback correctly preserves MM_BUSY (-5); its two
expectations now match the production return contract, with the
unrelated allocation-failure -1 assertion unchanged. The v995
fatal-owner FILE/HUP test now supplies the production WAIT/STATE
constants and filesystem-provider wait-event address, and rejects
an unexpected runnable-queue wake. Both targeted tests PASS.
These are test-only changes; no kernel code or OOM policy was altered.

## 2026-11-04 v1144: full physical PIPE/DPY/VM/u-area D14 PASS

New `test-daimos-oom-pipe-dpy-vm-provider-v1144` reuses the v1118
full 256K PDP-6 held-provider and mixed fatal-EXIT guest. Slot 5
installs a real Type-340 DPY raw list before its fatal FILE cleanup.
The final opt-in test variant pins the actual PIPE, DPY, VM and
u-area extents independently rather than fabricating either the
older PIPE or u-area MM_BUSY result. Each owner has exactly one
pin, one real -5, one unpin, one physical free, zero hook errors,
and all four physical bases differ. The producer/consumer provider
lease remains held while another independent user makes progress.

The test checks FILE/PIPE/DPY release before VM destruction, VM and
u-area release before slot-5 zombie publication, no premature
WAIT(NO-HANG) (its correct value is zero), exact final WAIT/CHLD,
one swap detach, 48 stale WAIT/PID/event refusals, and 37 bystander
advances. All assertions PASS. This closes mandatory D14, not D16,
C04, E/F or strict 32K runtime acceptance. Production OOM remains
disabled, and no production DAIMOS kernel code/data were changed.

## 2026-11-04 v1143: D13 independent rerun, D15 XIP scope closure

Independently rebuilt full 256K PDP-6 v1142 guest PASSes the combined
APR/EXEC/failed-RUN physical-u-area test: two actual `mm_free` calls,
one real pin, one MM_BUSY (-5), one successful unpin, zero errors,
parent continuation and exact terminal WAIT. Native v893 (actual
pinned u-area with two refusals and deferred release) and v894
(pre-VM and u-area retry/exact release) also PASS.

The current source-linked v1108 MEMFS XIP/MM and v1109 XIP VM retry
tests PASS and reject their unsafe mutants. v1123 scope audit PASSes
all six unsafe variants and confirms ordinary production RUN/EXEC use
writable startup, not XIP process admission. D15 is complete by
explicitly excluding scheduled XIP processes from the current BRK
requester OOM scope. The separate trusted XIP launch work X03-X08
remains open. Checklist after D15: 36/65 mandatory checked, 27
pre-activation blockers, production OOM disabled. D14/D16 remain.

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

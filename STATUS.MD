## 2026-10-22 GROUP 030 PUBLIC BOOT MULTITTY V177

- `test-daimos-make-boot-multitty` now selects versioned v177.
  It uses `DSH_IMAGE_LIMIT=037000` for functional boot testing,
  without changing the independent strict `036000` size gate.
- DCS0/GE0 TCP clients are started only after the simulator reports
  the Type-340 device, preventing the earlier race where clients
  expired while the public `make boot` target was still compiling.
- V177 **PASS** against immutable DAIMOS `40bc094`, covering public
  EXEC/WHICH, DPY-routed TTY0, interactive DCS0 and GE0 input,
  native ASMUTILS `make install`, and double-TAB completion.
  Guest evidence is retained under
  `$TMPDIR/daimos-make-boot-multitty-v177-*` and outer log under
  `$TMPDIR/daimos-make-boot-multitty-v177.log`.
- The surviving group 030 DTFS fixture still assumes a D6FS-root
  kernel can post-mount DTFS, but `dtfs_minit` is root-selected and
  does not install the provider for a D6FS root. Rewrite the fixture
  for a legitimate DECtape-root configuration; do not lift the
  residency guard or silently delete its persistence assertions.
- Full serialized KCC/GCC group 030 acceptance is not yet complete.

## 2026-10-22 GROUP 030 EXEC TIMING V174

- EXEC replacement v174 PASS on immutable DAIMOS `40bc094`:
  replacement preserves PID, credentials, cwd, session, pgrp, TTY
  and descriptors.
- EXEC child-session v174 PASS: child survives image replacement,
  parent reaps it. SIMH runs headless to avoid host WCNSLS
  graphical-device startup failures.
- Both tests now use `daimos-exec-sentinel-timing-v174.py` to
  separate a bounded boot-start interval (120 s) from the
  post-pre-EXEC-sentinel deadline (15 s). Child-session timing log
  reported 17.953 s boot and 0.029 s after sentinel. These are
  host-output arrival timings, **not** precise target CPU cycle
  counts or standalone EXEC microbenchmarks.
- Group 030 is still open for DTFS fixture support and complete
  KCC/GCC runtime/matrix integration.

## 2026-10-22 GROUP 030 REGISTRATION AUDIT V173

- The regression Makefile had still selected obsolete scripts despite
  later corrected standalone testing. The EXEC replacement target now
  invokes v137, child-session v140, Type-340 native refresh v150, and
  userspace multi-TTY v144; command coverage uses the same v150 DPY
  script. Shell syntax checks and Makefile diff lint PASS.
- This is a registration repair, not group-030 acceptance. The EXEC
  tests retain their 15-second default timeouts, previously exceeding
  host wall-clock timing while completing semantically at 18-19s.
  They still need a supported performance policy and retest.
- DTFS v143 still tests a D6FS-rooted system without the DTFS provider
  MRES, and its post-boot mount test is invalid in that configuration.
  Keep this separate from TSFS boot-root-only acceptance (group 027).
- Independently accepted group-027 source is in its own clean worktree;
  the concurrent main DAIMOS KCORE optimization must not be disturbed.

## 2026-10-22 GROUP 027 KCC/GCC INDEPENDENT ACCEPTANCE V172

- All eight **active boot-root-only group 027 targets PASS independently**
  with KCC and GCC, testing the immutable DAIMOS source at commit
  `40bc094`. Tests: `dtc-online` (userspace format, native FSCK,
  pristine-system-disk reboot and persisted-media native FSCK),
  `dtc-stream-online`, `tsfs-image-online`, `tsfs-scan`,
  `tsfs-boot-eight`, `tsfs-multiextent`, `tsfs-d6lz` and
  `dtc-reverse-online` (actual reverse direction confirmed in SIMH).
- The v171 online runner propagates `COMPILER` to both production
  image builds and allows explicit `SIMH_PDP6`. Its former v169
  secondary `MOUNT.DTFS` oracle was invalid for a D6FS-root kernel:
  `dtfs_minit()` only installs the tape FS MRES on DECtape-root
  configurations. The replacement preserves two-boot media
  persistence verification without introducing a resident module.
- Evidence: `$TMPDIR/daimos-group027-dtc-online-v170-isolated2.log`
  (KCC v170 PASS), `$TMPDIR/daimos-group027-dtc-gcc-v171.log`
  (GCC v171 PASS), and
  `$TMPDIR/daimos-group027-gcc-v172-*.log` (other GCC targets).
  Earlier KCC independent target logs are in
  `$TMPDIR/daimos-group027-v167-*.log` and `v168-*.log`.
- This accepts **independent functional group 027**; the complete
  serialized regression matrix and strict `036000` size gate have
  **not** been accepted. The concurrent KCORE optimization is in a
  different, dirty DAIMOS checkout and was not modified.

## 2026-10-22 GROUP 027 SUPPORT TESTS V169

- The TSFS boot-root-only contract remains enforced: no post-boot
  `MOUNT.TSFS` tests or userspace mount syscall.
- Supported DECtape/TSFS group 027 checks pass independently on the
  installed PDP-6 toolchain: `dtc-stream-online` (counted block
  write/read), `tsfs-image-online` (host-created tape through the
  production Type-551 driver), `tsfs-scan-v2` (eight members,
  ninth rejected), `tsfs-boot-eight` (KINIT member map),
  `tsfs-multiextent` (cross-member read), `tsfs-d6lz` (restart
  and transient free), and `dtc-reverse-online` (real reverse
  read/write validated against emulator trace).
- `daimos-tsfs-image-online-v1.sh` now uses the installed
  `$PDP10_PREFIX/bin/mktsfs` instead of an obsolete external
  checkout `make build` target.
- The versioned `daimos-dtc-online-v169.sh` retains the functional
  mount/DTFS online test, passing only `DSH_IMAGE_LIMIT=037000`
  to its production-image make invocations. The guest reached DSH
  and performed its initial format/mount cycle; **the persisted-media
  second-boot MOUNT.DTFS fails**. This remains a functional failure,
  distinct from the 036000 size gate. Group 027 remains open.
- Logs: `$TMPDIR/daimos-group027-v168-*.log`;
  `$TMPDIR/daimos-group027-dtc-online-v169.log`.

## 2026-10-22 TSFS BOOT-ROOT-ONLY TEST CONTRACT V165

- TSFS is usable only as the boot filesystem. The former
  `MOUNT.TSFS` post-boot mount operation is obsolete; TSFS media
  creation and writes are performed by userspace tooling and `dd`.
- Removed `daimos-tsfs-mount-v1.sh`, `daimos-tsfs-dir-v2.sh` and
  unregistered obsolete `daimos-tsfs-scan-v1.sh` with its mount-handoff
  fixture. Removed the two active targets and their names from both
  group-027 regression matrices, coverage inventory and Makefile.
- The remaining eight-member TSFS scan test now tests media discovery
  and ninth-member rejection, not the retired secondary-mount handoff.
  `daimos-tsfs-scan-v2` PASS; retained tape-root boot and image tests
  still require matrix acceptance under KCC/GCC.
- The DAIMOS userspace build no longer creates or publishes
  `MOUNT.TSFS`. The obsolete userspace syscall and the handoff
  builder have now also been removed. KINIT's direct boot-root
  provider operation remains intact. Group 027 remains active.

## 2026-10-22 P10FOLD INSTALLED TOOL FIX / GROUP 030 V164

- Root cause of missing GE0 LOGIN: `$PDP10_PREFIX/bin/p10fold` was an
  older binary that folded GE GTYO CONSO/JRST polling pairs with different
  skip successors. The *current* DAIMOS `tools/host/p10fold.c` source
  already rejects the unsafe fold. Compiling that source produced a
  header-only GE fold plan; the stale installed binary produced a
  two-word FOLD entry. The corrected source-built executable was
  installed at `$HOME/cross/bin/p10fold`, and the production image
  rebuilt with an empty GE fold plan.
- With the corrected optimizer, versioned multi-TTY v145 PASS verifies
  CTY/DCS0/GE0 LOGIN, routing, respawn, resource stability and STOP
  isolation: `$TMPDIR/daimos-ge-correct-p10fold-multitty-v161.log`.
- Type-340 native/shifted refresh v150 also PASS on a fresh KCC disk
  using the newly installed tool:
  `$TMPDIR/daimos-ge-correct-p10fold-dpy-v163.log`.
- The new `test-daimos-installed-p10fold-ge-v164` guard assembles
  the actual GE source and refuses any fold from the installed
  optimizer for its skip-controlled transmit loops. PASS.
- The source-level P10FOLD skip regression also PASS; source fix
  predated this run. Other group 030 tests and GCC whole-group
  acceptance remain open; group 027 is active.

## 2026-10-22 GROUP 027 REACTIVATION / DPY V150 RETEST

- Group 027 DECtape/TSFS is **active again by explicit request**;
  it is no longer deferred. The original root-selected MRES policy
  and positive/negative acceptance assertions remain in force.
- The versioned Type-340 native-refresh test
  `daimos-dpy-native-refresh-smoke-v150.sh` uses corrected SIMH,
  functional DSH ceiling 037000 and preserved assertion checks.
  Its fresh 256K KCC image boots and DCS0 receives LOGIN, but
  GE0 connects without LOGIN; test FAILS `remote LOGIN missing`
  before display refresh assertions. Evidence:
  `$TMPDIR/daimos-dpy-native-v150.log`.
- This corroborates the independent userspace multi-TTY GE0 startup
  blocker (v144); it does **not** establish a Type-340 driver defect.
  Prioritize root-causing INIT/GE0 session setup, then rerun DPY.

## 2026-10-22 GROUP 030 EXEC, DTFS, MULTI-TTY DIAGNOSTICS V148

- EXEC replacement and child-session guest semantics finish normally on
  corrected SIMH with fresh media. A fresh simulation-only EXEC run
  completed in 18 seconds with `<E` and HALT; child-session diagnostic
  completed in 19 seconds with `<xEP` and HALT. Both original 15-second
  wall-clock acceptance gates therefore remain FAIL, not silently relaxed.
  The versioned `daimos-exec-replace-v137.sh` and
  `daimos-exec-child-session-v140.sh` retain 15 seconds by default;
  explicit `DAIMOS_EXEC_DIAGNOSTIC_TIMEOUT` is for investigation only.
- Three repeat boots against reused writable media emitted `?RT`
  instead of a completion marker. They do not provide independent
  latency evidence; every accepted runtime retake needs pristine disks.
  The guest-only result is in
  `$TMPDIR/daimos-exec-simh-timed-v148.log` and the child-session
  diagnostic in `$TMPDIR/daimos-exec-child-diagnostic-v141.log`.
- DTFS v143 functional-size fixture reaches runtime, but phase A fails
  MOUNT.DTFS and UNMOUNT. The D6FS-rooted boot deliberately omits the
  DTFS/TSFS MRES: `dtfs_minits` installs it only for KINIT_ROOT_DTC.
  Subsequent successful file probes therefore ran on the underlying
  mountpoint, not DECtape. The previous CHARS-based STAT oracle is
  separately stale. DTFS must be adapted to a genuine supported
  DECtape-root configuration; no fake pass or provider policy change.
- Multi-TTY v144 with corrected SIMH shows DCS0 LOGIN but no GE0
  LOGIN prompt, failing the original remote carrier assertion. v145
  instruments CTY PS; its initial reused-media attempt halted in
  `?RT`, and a regenerated-root run timed out connecting DCS0,
  preventing a reliable process inventory. This remains open.
- Group 027 stays deferred by user request. Group 030 and the full
  serial matrix remain open, with strict 32K acceptance deferred.

## 2026-10-21 RUNTIME PROBES AND CTY ACCOUNTING V136

- The versioned `daimos-runtime-probes-v132.txt` suite passes all
  **66/66 probes under both KCC and GCC** (fresh 256K images). The
  previous STAT test expected a non-existent CHARS field; its revised
  oracle verifies TYPE, WORDS, MODE, UID, GID and MTIME. DF is checked
  against the current FILESYSTEM/MOUNT/TOTAL/USED/FREE tabulation and
  a populated MEMFS /TEMP row. Assertion coverage is preserved.
- `/MONITOR/DEVICES/CTY0/STATS` is a READCHAR character stream, not a
  S6REC word file: native CAT correctly prints no content. The v132
  suite now checks its metadata using STAT, while the independent
  `test-daimos-monitorfs-cty-stats-v132` target checks all three
  twelve-digit octal lines and EOF via READCHAR plus the incremented
  CTY output counter. It passes under KCC v133 and GCC v134.
- That target exposed a genuine missing-counter defect in DAIMOS
  `cty_io.s`. DAIMOS commit `08625cf` increments the existing
  MonitorFS CTY IN/OUT slots only on completed I/O. It adds no BSS.
- Runtime logs: `$TMPDIR/daimos-group030-runtime-kcc-v135.log` and
  `$TMPDIR/daimos-group030-runtime-gcc-v136.log`; counter logs:
  `$TMPDIR/daimos-monitorfs-cty-kcc-v133.log` and
  `$TMPDIR/daimos-monitorfs-cty-gcc-v134.log`.
- Only the runtime-build/MonitorFS portion of group 030 is accepted.
  Exec, DTFS, display, and multi-TTY cases still need fresh retakes;
  group 030 and the complete serial matrix remain OPEN. Group 027
  remains explicitly deferred, as do strict 32K/size gates.

## 2026-10-21 D6FS HDD / MULTIMEMBER / RECOVERY GROUP 029 V131

- Group 029 passes independent KCC and GCC non-size acceptance.
  `d6fs-hdd-runtime` passes all 16 guest probes and the four-member
  LOGSTORE badmap inspection (KCC fresh v128; GCC confirmed v119).
- The replacement `run-multimember-v126.sh` (commit `552428c`) fixes
  two test-fixture defects: old SIMH disk attachments overwrote fresh
  two-/four-member test media, and the synthetic D6FS root omitted
  MOUNTALL, FSTAB, system policy and the commands exercised by the
  probes. Both compilers now pass all 16 operations for each supported
  member count, both malformed/missing-member rejection cases and
  LOGSTORE checks. No DAIMOS kernel or D6FS implementation changed.
- Dual-superblock recovery, 16 guest probes, bootstream preservation,
  LOGSTORE verification and DIRTY reboot rejection pass under both
  compilers (KCC v130; GCC v129).
- Logs: `$TMPDIR/daimos-d6fs-multi-kcc-v126.log`,
  `$TMPDIR/daimos-d6fs-multi-gcc-v127.log`,
  `$TMPDIR/daimos-d6fs-hdd-runtime-kcc-v128.log`,
  `$TMPDIR/daimos-d6fs-recovery-gcc-v129.log` and
  `$TMPDIR/daimos-d6fs-recovery-kcc-v130.log`.
- Group 027 remains deferred; group 030 and the complete serial
  non-size regression matrix remain open. Strict 32K gates are deferred.

## 2026-10-21 KERNEL AND STANDALONE RUNTIME GROUP 028 V123

- Group 028 now passes independently under both KCC and GCC. The original
  `kernel-runtime` CTY watcher incorrectly expected `LOGIN:` on CTY with a
  three-second phase timeout; interactive ROOT LOGIN and DSH use DCS0.
- The v121 kernel smoke fixture builds the production PDP-6 disk image,
  checks CTY DAIMON version and BSET initialization, logs in as ROOT on DCS0,
  and requires external ECHO and PWD output through a fresh DSH prompt.
  This preserves and strengthens boot acceptance instead of raising the
  stale CTY timeout. KCC and GCC fresh 256K images each passed both probes.
- The independently rebuilt standalone boot suite passes 26/26: DSK,
  PTR, MTC, and DTC, with zero failures.
- Functional `DSH_IMAGE_LIMIT=037000` is explicit in this fixture; strict
  32K image/boot gates remain deferred, not accepted. Evidence:
  `$TMPDIR/daimos-kernel-group028-kcc-v121.log`,
  `$TMPDIR/daimos-kernel-group028-gcc-v122.log`,
  and `$TMPDIR/daimos-stand-group028-v122.txt`.
- Group 027 is deferred by request. Groups 029 and 030, and the full
  non-size regression matrix, remain open.

## 2026-10-21 SIMH CONSOLE PC AND TRAP FREQUENCY V120

- `test-daimos-simh-console-pc-v115` verifies that a startup-script PC
  survives entry into the interactive console, an actual PDP-6 instruction
  breakpoint, and single-step. It fails on the old simulator and passes
  after the global `PC` to `kx10_pc` namespace correction (`sims` 1a41f45).
- The existing `test-daimos-trap-frequency` passes the full runtime oracle
  on corrected SIMH under **KCC and GCC**. KCC measured startup/echo/
  memstat/ls/ps/cat128 as 111/16/19/33/23/18 traps; GCC measured
  90/16/19/33/25/18. All original ceilings (128/35/70/70/110/45) hold.
- The trap fixture explicitly uses functional `DSH_IMAGE_LIMIT=037000`
  (`0f6ad07`), separate from the deferred strict 32K boot/image-size gate.
- These independent checks resolve group 022 only. The last non-size
  KCC/GCC group results still require fresh acceptance for 027-030; no
  full matrix pass is claimed. Evidence: `$TMPDIR/daimos-trap-runtime-fixed-pc-v117.log`
  and `$TMPDIR/daimos-trap-gcc-fixed-pc-v118.log`.

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

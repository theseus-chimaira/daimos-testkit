## 2026-10-23 GROUP 030 RUN/WAIT CONTROL V196

Nested `DSH -C ECHO` + `$?=0` and a separate ECHO both pass on
TSFS root, with supported timeouts. Wrapper modified during its
run returned syntax error after the two probe successes; rerun
cleanly before acceptance. Focus investigation on the specific
FSCK/MOUNT child probe handoff rather than generic RUN/WAIT.

## 2026-10-23 GROUP 030 V195 INCONCLUSIVE NEGATIVE CONTROL

Unattached-DTC7 FSCK did not return during an interrupted diagnostic.
Because absent-media transport is a separate variable, do not infer
RUN/WAIT root cause from V195. Continue with attached-media and
simple-child controls; preserve full DTC3 persistence regression.

## 2026-10-23 DTFSPROBE V194

Native DTFS type code is octal 010 (decimal 8). Both shallow and
DEEP direct DTFSPROBE exit with this correct status in V193's
captured guest output; V194 fixes the test expectations. Investigate
why FSCK/MOUNT do not finish their nested RUN/WAIT-probe sequence
even though direct probes complete. Preserve 240-second regression
deadline and do not change kernel storage code without evidence.

## 2026-10-23 GROUP 030 FSCK V192

FSCK.DTFS with the established 240-second deadline times out on a
host-formatted DTC3 while running from TSFS root. ECHO/PWD pass
and MOUNT.DTFS independently times out in the prior V190/V191 runs.
The next focused test must isolate child exit status and wait
notifications from raw DTC3 access. Keep the failing deep filesystem
acceptance checks intact, and do not patch the kernel on speculation.

## 2026-10-22 DTFS V190/V191 CONTROLLED TIMING RECHECK

V190 external ECHO and PWD succeed with the established 240-second
tape-root command policy. V191 MOUNT.DTFS on host-formatted DTC3
still times out at 240 seconds. The V187-V189 short-deadline
RUN/WAIT probes are not conclusive. Separate valid DTFSPROBE
completion/exit-status checks from the mount syscall, then investigate
the implicated path. Do not modify the tape block driver on inference.

## 2026-10-22 V185/V186 RUN/WAIT ISOLATION

Direct DTFSPROBE (normal and DEEP) returned to DSH; FSCK's
RUN/WAIT-wrapped probe timed out, and HALT after direct DEEP also
timed out. Do not conclude successful probe exit from shell prompt
alone. Isolate nested child exit/wait and TSFS-root command lifecycle;
do not modify Type-551 I/O without confirming a controller defect.

## 2026-10-22 DTC3 REPRODUCTION V184

Fresh no-debug V180 retry reproduced DTC3 mount timeout on TSFS root
with stable DevSpace2 connectivity. The issue is a guest/simulator
runtime problem, not the plugin disconnection itself. Investigate
bounded provider and Type-136 I/O trace; preserve full persistence
assertions and root-only residency policy.

## 2026-10-22 GROUP 030 DTC3 BLOCKER V180

The valid tape-root + separate DTC3 topology reaches DSH and loads
DTFS, but guest MKFS.DTFS on an empty DTC3 and MOUNT.DTFS on a
host-initialized valid DTC3 each fail to complete in V179/V180
diagnostics. Isolate DTC3 block transport and provider mount before
reattempting the full two-boot mutation/persistence suite. Standalone
production Type-551 DTC3 counted I/O and DTC1-to-DTC3 switching now
PASS in V181/V182. Investigate the guest syscall/VFS/PI scheduling
path under TSFS root rather than changing basic DTC unit encoding.
Keep diagnostics unregistered until repaired; group 030 stays open.

## 2026-10-22 GROUP 030 TAPE-ROOT V178

Supported DECtape-root boot and shell execution PASS (DTFS provider
loaded). Registered the v178 check in the group-030 matrices without
removing the deeper `dtfs-runtime` fixture. Rework that fixture for a
supported tape-root provider and retain its actual file operations and
multi-boot persistence assertions. Full KCC/GCC group acceptance open.

## 2026-10-22 GROUP 030 MAKE BOOT V177

Public `make boot` multi-TTY V177 passes, including the native
ASMUTILS installation. Functional image limit and late TCP client
connections remove build-time false failures. DTFS runtime remains
the unsupported-root fixture blocker; redesign for true tape-root
coverage. Then rerun serialized KCC/GCC group 030 and the matrix.

## 2026-10-22 GROUP 030 EXEC V174

EXEC replacement and child-session semantics pass using the v174
headless SIMH fixtures and the 15-second post-sentinel host deadline.
Do not interpret that host-output interval as a cycle-count benchmark.
Remaining: DTFS runtime valid root configuration, group 030 GCC and
full serial matrix; strict DSH 036000 size gate remains separate.

## 2026-10-22 GROUP 027 INDEPENDENT ACCEPTANCE V172

Eight active targets now pass under both KCC and GCC against fixed
DAIMOS commit `40bc094`, using the v171 dual-boot persisted-media
test instead of the invalid post-boot mount oracle. No TSFS
secondary-mount testing is required. Group 027 independent functional
work is complete; continue with the serialized full matrix and
separately deferred strict memory-size acceptance. Keep the
concurrent KCORE checkout isolated from tests.

# DAIMOS TESTKIT TODO

## 2026-10-22 GROUP 027 VALIDATION V169

Seven supported tests pass independently: counted DTC stream,
TSFS image, eight-member scan and KINIT boot selection, cross-member
extent, D6LZ restart, and physical reverse DTC transfer.
Investigate `dtc-online` v169: the persisted DTFS medium fails to
mount on its second boot. Retain DTFS mount assertions, then repeat
the active group 027 under GCC before atomic acceptance. Boot-root TSFS only;
never revive `MOUNT.TSFS`.

## 2026-10-21 NON-SIZE FUNCTIONAL GROUPS

- 2026-10-22 v164: GE0 LOGIN and Type-340 native refresh fixed by
  installing the already-corrected source `p10fold` binary into
  `$PDP10_PREFIX/bin`; KCC standalone multi-TTY and DPY pass.
  The installed binary previously applied the invalid skip/JRST fold.
  Revalidate GCC and the full group 030 using the fixed host tools.

- 2026-10-22 update: EXEC replacement and child-session complete
  in 18-19 seconds on fresh media, but their existing 15-second
  wall-clock acceptance gates fail. Preserve the gates while
  evaluating deterministic performance/correctness measurement.
- DTFS v143 exposes D6FS-root versus DTFS-MRES install mismatch:
  a failed MOUNT.DTFS makes later mountpoint operations false
  positives. Reconcile with legitimate DECtape-root support; no
  blanket assertion removal or fake mount result.
- Multi-TTY v144 still fails remote GE0 LOGIN; v145 CTY process
  inventory is inconclusive due carrier/port startup. Isolate
  actual LOGIN spawn versus terminal transport with pristine media.

- Group 027 (DECtape/TSFS): ACTIVE TODO again (2026-10-22, by request).
  TSFS is **boot-root only**: no post-boot TSFS mounts are supported.
  V165 removed both obsolete mount tests and their registration, and
  removed mount-handoff assertions from the retained eight-member
  scanner. Retest tape-root boot, scanning, compression and DECtape I/O
  under KCC and GCC; build TSFS media in userspace and write it with dd.
  Do not restore secondary TSFS mounts to satisfy obsolete test cases.
  The retired userspace TSFS mount syscall and handoff builder are
  removed. KINIT still invokes the TSFS provider for the boot root.
- Next: group 030 (userspace runtime/multi-TTY). Group 029 D6FS runtime,
  multimember and recovery now pass independently under both compilers.
  Retake the full non-size serial matrix when the remaining active groups
  have been repaired; group 027 is no longer deferred.
- Group 030's 66/66 runtime probe suite and CTY READCHAR accounting
  now pass under both compilers (v132). Remaining: DTFS runtime,
  EXEC replacement and child-session, native Type-340 refresh,
  userspace multi-TTY and make-boot multi-TTY. Keep these tests
  independent and do not accept group 030 until all are green.
- Strict 32K boot and resident-size gates remain deferred.

DATE: 2026-09-30

THIS FILE CONTAINS OPEN TESTKIT WORK ONLY.  SUBSTANTIAL DSH WORK DOES NOT START
UNTIL THE REQUIRED PRE-DSH MATRIX IS GREEN AND THE TOP-LEVEL `MAKE REGRESSION`
ENTRY POINT COMPLETES SUCCESSFULLY.

## 1. COVER THE FINAL INIT `/CONFIG` POLICY

DAIMOS NOW OWNS SWAP/LOGSTORE ACTIVATION POLICY IN INIT.  ADD ACCEPTANCE FOR:

- ADDITIONAL/NONESSENTIAL FILESYSTEM MOUNTS THROUGH `/CONFIG/FSTAB`;
- SWAP RESERVATION SELECTION AND ACTIVATION;
- LOGSTORE RESERVATION/SERVICE SELECTION AND ACTIVATION;
- FAILURE CASES THAT LEAVE THE SYSTEM BOOTABLE AND DIAGNOSABLE.

HARDWARE/ROOT DISCOVERY REMAINS A STAGE1/KINIT RESPONSIBILITY; THE TESTKIT MUST
NOT ENCODE ADMINISTRATIVE SERVICE POLICY BACK INTO KINIT.

## 2. CLOSE THE PRE-DSH GATE ONLY ON A CLEAN FULL REGRESSION

THE SIXBIT/ABI REBASE IS COMPLETE.  THE 2026-09-30 PRE-TSFS SERIAL RUN PASSES
THROUGH THE COMPRESSED BOOT-SOURCE MATRIX AND ALL EXPLICIT ROOT CLASSES, THEN
TIMES OUT IN THE AUTO-ROOT ALL-MEDIA CASE BEFORE DSH.  A FOCUSED RERUN
REPRODUCES THAT FAILURE.  RESUME THE COMPLETE SERIAL RUN ONLY AFTER THE DAIMOS
ROOT/TSFS STARTUP-LOCALITY ITEM IS RESOLVED; DO NOT RAISE THE TIMEOUT TO HIDE
THE FAILURE.

THE GATE CLOSES ONLY WHEN THE COMPLETE RUN PASSES FORMAT/COVERAGE, HOST MM,
DIRECT PDP-6 TARGET TESTS, RESIDENT/PERMANENT SIZE GATES, PROCESS/TTY/IPC,
SCHEDULER/RT, STORAGE/FILESYSTEMS, ALL BOOT/ROOT/LOGIN PATHS, D6LZ BOOT/EXEC,
LOGSTORE, DTFS/TSFS, D6FS RUNTIME/RECOVERY, AND PDP10-TOOLS INTEGRATION.

DO NOT HIDE REQUIRED FAILURES WITH XFAILS, SKIPS, TIMEOUT CHANGES, OR KERNEL
WORKAROUNDS FOR STALE TEST ASSUMPTIONS.

## 3. CTY HARNESS FOLLOW-UP

IMPROVE CTY INPUT INJECTION IF THE SIMH CONSOLE HARNESS CAN RELIABLY DELIVER
THE REQUIRED LINE TERMINATOR.  THIS IS USEFUL COVERAGE BUT DOES NOT BLOCK V0.9
WHILE THE DCS0/GE0 LOGIN CONTRACT IS GREEN.

## 4. DOCUMENTATION MAINTENANCE

KEEP README.MD FOR STABLE PROJECT/USAGE INFORMATION, STATUS.MD FOR CURRENT
VERIFIED STATE ONLY, AND THIS FILE FOR OPEN WORK ONLY.  REMOVE SUPERSEDED
CHECKPOINT SECTIONS INSTEAD OF ACCUMULATING DATED SNAPSHOTS.

DAIMOS-SPECIFIC TESTS STAY HERE.  GENERIC DAS, KCC, ABI, OR PDP-10 TOOLCHAIN
TESTS STAY IN PDP10-TESTKIT.

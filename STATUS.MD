# LOGIN single-block allocation saving (2026-10-13 v1)

An uncompressed LOGIN DXR2 executable now carries ST2 01000 rather than
the normal 02000 stack reservation. Image 006133, BSS 000255, origin
000020 and stack 001000 sum to 007430 octal words, rounding to 010000
instead of 012000. The new versioned size/metadata verifier passes.
Fresh PDP-6 disk image, ROOT LOGIN -> DSH, and all 115 DSH conformance
probes PASS. Host physical AUXSTORE inspection verifies persisted
INIT_READY and LOGIN records. Larger password/path/login stack-depth
stress, repeated LOGIN respawn under pressure, and 32K boot acceptance
remain open.

# SUPERVISOR one-block PID 1 optimization (2026-10-12 v11)

The resident SUPERVISOR is **001177 text, 000051 BSS**, with **0400
stack words** declared by DXR2 `ST2`, giving **002000 octal words**
after PDP-6 APR rounding. The ordinary 02000 stack default survives
for all other executables. Four-word compact LOGSTORE events eliminate
the supervisor's former 0200-word logging stack frame; LOGSTORE uses
transient MM scratch with the unchanged general APPEND and disk format.

The AUXSTORE LOGSTORE regression is fixed: `logstore_minit` now patches
the KCORE unit/block/buffer bridge instead of the incompatible relocated
raw hardware-address/buffer MRES service. Before this repair, successful
APPEND/EVENT calls silently overwrote physical drum block 0 rather than
the LOGSTORE records. The disk descriptor and physical on-disk records
are now independently verified by the new v11 forensic test.

Full image and **115/115** DSH conformance PASS; two independent fresh
LOGD/LOGDUMP direct persistence runs PASS; the strict eight-entry
INITTAB/102-character-path startup logs all seven distinct RUN_FAILED
records and a LOGIN record, verified on raw drum media. DXR ST2
limits/flag rejection (6/6) and one-block size tests PASS. Remaining
separate acceptance: user-stack high-water instrumentation, repeated
LOGIN respawn exhaustion, and the full 32K shell boot.

# Two-stage PID 1 startup and resident SUPERVISOR (2026-10-12 v2)

Production PDP-6 boot now launches startup INIT, which EXEC-replaces
itself with resident SUPERVISOR while retaining PID 1. The latter is
001530 octal image words / 000461 BSS, and consumes only a 006000-word
rounded user VM extent. The full PDP-6 boot and DSH 115/115 conformance
suite pass. `tests/validation/daimos-init-supervisor-size-20261012-v2.sh`
guards INIT/SUPERVISOR/DSH image and the resident VM size.

The dedicated 32K boot remains open: INIT and LOGIN start, but ROOT
cannot EXEC DSH. The PID 1 reduction alone does not provide sufficient
physical core for the shell. See the versioned INIT/SUPERVISOR validation
note; overlay support was investigated but not implemented.

# DSH variable-width AST and lazy-function payload v9 (2026-10-12)

Complete PDP-6 KCC/DAS DXR image **035671 octal**, BSS **005013
octal**, image+BSS+startup **044724**, rounded VM **046000**.
The existing fixed eight-slot (1,440-word) function payload pool is
allocated once on first DEF instead of occupying permanent BSS.
Temporary AST argument storage uses nine words per possible token
slot rather than reserving 180 words for every argument-bearing node.
All existing DSH limits and language features are preserved.

Fresh full-image build and standard 036000 image gate PASS.
**115/115** ordinary DSH CTY conformance probes PASS.
**16/16** focused AST/function/SOURCE and full-word-slot probes PASS.
The versioned v9 size guard passes. The 32K LOWMEM INIT -> DSH
acceptance is still OPEN; smaller initial VM is not a boot proof.

# DSH compact AST payload storage (2026-10-12, v3)

The verified DSH image is 035552 octal words and BSS 007651 octal
words. The rounded initial user-VM extent is 050000 octal (previously
056000), with the normal 036000 image gate satisfied. The exact DXR
passed all 115 existing PDP-6 DSH conformance probes; the versioned
AST-focused probes pass 10/10, including stored function copying,
replacement, compaction and SOURCE lifetime checks. A new v3 guard
rejects image/BSS/VM regressions and unwanted libc linkage.

The dedicated 32K low-memory boot still reaches LOGIN but returns
`LOGIN: EXEC FAILED`. The BSS reduction is verified, but **32K
boot acceptance remains open**. A cached additional primary payload
was investigated and rejected because it enlarged permanent BSS
without reducing the rounded initial VM extent.

# DSH compact AST RAM reduction (2026-10-12)

DAIMOS DSH prototype v7 changes the AST payload representation without
reducing shell language/capacity limits. The final source measures 035552
image words and 007651 BSS words (octal); the initial user VM extent
drops from 056000 to 050000. The complete ordinary PDP-6 DSH
conformance run passed 115/115; the compact-AST focused suite passes
10/10; and
`tests/validation/daimos-dsh-size-guard-20261012-v3.sh` passes.
The final 32K lowmem boot still reaches LOGIN but fails the ROOT DSH
EXEC transition. Successful INIT -> LOGIN -> DSH acceptance is open.

# DSH source shrink v2 and 32K boot constraint (2026-10-12)

Source cleanup and shared SIXBIT classifiers reduce DSH image 036054 ->
035545 octal words (0307 saved), with BSS unchanged at 015241.
Normal 036000 image limit passes; full PDP-6 image build and 115/115
DSH SIMH conformance pass. The versioned v2 image/VM size guard passes.

However, `daimos-low-memory-boot-v2.sh` still fails after ROOT login
with `LOGIN: EXEC FAILED`. DSH needs 055026 words before 02000-word
VM alignment and therefore 056000 allocated words. KCORE ends at 023610;
their sum already exceeds 32K. The fix is a future compact AST storage
refactor, not removal of command-language features.

# DSH measured first shrink stage (2026-10-12)

Fresh DAIMOS PDP-6 KCC/DAS source/object refactors reduce DSH from 036722
to **036054 octal image words**, saving 0646 octal with BSS unchanged at
015241. Complete boot-image build and **115/115 DSH conformance probes**
passed. `tests/validation/daimos-dsh-size-guard-20261012-v1.sh` verifies
the intermediate cap and absence of three unused libc symbols in the DSH
link map. This is not yet the final 036000 image acceptance: 0054 octal
words remain to remove.

# DSH bounded HISTFILE repair on PDP-6 (2026-10-12)

Live two-boot DSH HISTFILE repair passes 5/5 target probes via
`tests/validation/daimos-dsh-histfile-repair-20261012-v2.sh`.
A truncated S6REC is repaired under the existing file lock; the
preceding valid record is recalled, subsequent history is verified
to the exact 11-word EOF, and D6FSCK reports clean media. No new
kernel transaction or journal is required. Writer conflict and
failure injection remain separate acceptance work.
The same updated DSH image also passed all 115/115 existing SIMH conformance
probes. Fresh image 036722 octal words exceeds the standard 036000 gate;
shrinking DSH remains open.

# D6FS bounded record undo experiment (2026-10-12)

`make test-daimos-d6fs-undo-cuts` passes 5,805 host-only simulated
interruption/recovery cases and three explicit corruption/conflict checks.
The model covers full-block undo snapshots for data tail, allocation map,
summary and FCB, with alternating PREPARE/COMMIT markers and repeatable
interrupted recovery. **No D6FS kernel or disk format was changed, and no
real power-cut or durability-barrier guarantee has been established.**
An explicit COMMIT-before-FCB counterexample fails the journal invariant
if persistence ordering cannot be enforced.
See `tests/host/daimos-d6fs-undo-cuts-20261012-v1.md`.

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

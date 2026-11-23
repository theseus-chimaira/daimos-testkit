# DAIMOS testkit - current verified status

## 2026-11-23 v1820: native manual inventory from live manifests

The recovered v1073 manual audit used an obsolete host MKSWAP
formatter path and expected a native KCC manual in a retired source
location. The new v1820 check compares public+standalone DXR build
targets to the current `PUBLIC_MANUAL_NAMES`, validates actual SIXMD
pages and installed optional assembler utility pages, and checks that
native MKSWAP is still planned rather than advertised as installed.
It does not claim coverage for external compiler packaging or for the
retired host MKSWAP utility. Run `make test-native-manual-coverage-v1820`.

## 2026-11-23 v1819: BCACHE LOW allocator assertion restored

The pre-existing native BCACHE allocation test still asserted
`MM_ALLOC_HIGH`, while production since v1636 requests LOW. Its
pre-correction source-linked baseline failed. The fixture now verifies
the actual production LOW preference and retains its 0201-word slab,
owner-6, fetch and reclaim checks. A new native PDP-6 negative control
reverts only the current LOW argument to the old HIGH argument: the
original production test passes and the unsafe mutant is rejected by
the guest exit oracle. Run `make test-bcache-low-placement-v1819`.
This focused kernel-cache test does not provide fresh six-process
physical PURE evidence or full guest memory-layout acceptance.

## 2026-11-23 v1818: historical DTFS write ABI test consolidated

The recovered v206 raw DTC write-register probe used an obsolete
`bcache_reclaim`-in-write ABI. Its assertion is now source-linked to
the current production `dtfs_dtc_write` and `bcache_invalidate_all`.
The real PDP-6 simulator baseline passed the exact UNIT/BLOCK/BUFFER
contract after a deliberately clobbering intent gate. Two mutations
(reintroducing write-time reclaim; corrupting AC2 in invalidation)
reached the native oracle and were rejected. This is a focused
source-linked unit test, not whole-guest DTFS/media acceptance. Run
`make test-dtfs-write-abi-v1818`. The two original v206 files are
preserved in a verified backup before their detached worktree cleanup.

## 2026-11-22 v1815: physical STOP/foreign-TERM evidence replay PASS

The recovered v1682 STOP/foreign-TERM verifier requires the real APR
growth event in addition to the existing preserved physical owner,
scheduler, saved user-PC and MM source checks. Replaying the accepted
48K GENERAL and STRICT v1682 original console evidence passed both
original oracles, while ten mutations of original physical B words
and event witnesses were rejected (five per profile). This is a
bounded replay of preserved physical evidence, not a fresh guest run
or release acceptance. See
`tests/validation/pure-stop-foreign-v1682/README-NEGATIVES-V1815.md`.

## 2026-11-22 v1814: CAT/MAKE source consolidation host PASS

The source-linked CAT regression passed exact native S6REC forwarding
for zero, 7, 258, 259 and 1000 characters, mock short word reads/
writes, long terminal output, EOF and malformed records. The CAT-only
archive object avoids 91 words of shared `libc/text.c` code growth.
The native KCC/DAS MAKE frame comparator passed: octal `01113`
(587 words) before -> `0172` (122 words) after, saving 465 stack
words; TEXT 7876 -> 7748, BSS stays 839. Both native CAT and MAKE
DXRs linked. A fresh source-matched native MAKE guest boot attempt
stopped at DSH 036133 > 036000 before simulator runtime. This remains
an open guest acceptance gate, not a PASS. Test and evidence details:
`tests/host/cat-make-consolidation-v1814/README-v1814.md`.

## 2026-11-22 v1812: source-linked host toolchain correctness PASS

`make test-toolchain-extern-expiry-v1812` passed with the current
DAIMOS host sources and the standalone pdp10-tools dirty candidates.
Actual DAS DOBJ1 fixtures exercise unused EXTERN declarations, missing
referenced definitions, selective DARC archive extraction, and both
right- and left-half symbol relocations. Direct P10RUN source evaluation
rejects SIMH step/time expiry with an initialized zero status, while
accepting the completed-zero control. The old DLINK and P10RUN sources
failed their respective negative controls. This is host acceptance,
not native guest execution or full DAIMOS regression acceptance. See
`tests/host/toolchain-extern-expiry-v1812/README-v1812.md`.
The opt-in native PDP-6 simulator test also PASSED: the unchanged v014
guest completed successfully in GO mode, while a one-step limit
produced `Step expired` and was rejected. This runs a bare-machine
guest, not a native DLINK program under DAIMOS.
Running the same actual forced-one-step guest against the original
P10RUN source reproduced the false PASS as a negative control.

Updated: 2026-11-19. This file records **verified** testkit ownership
and focused checks only; it does **not** certify a full DAIMOS release
or regression sweep.

## Ownership and migration

The compiler/assembler and OS repositories have separate active owners
under the 2026-11-19 v4 native return:

- `pdp10-testkit`: standalone GCC, KCC, DAS, DLINK, compiler ABI,
  codegen, optimizer and PDP-6/PDP-10 ISA tests.
- `daimos-testkit`: DAIMOS boot, KCORE/MRES/KINIT, DSH, devices,
  storage/filesystems, processes, syscalls and runtime acceptance,
  including all 25 boot-backed native toolchain integration suites.

The 2026-11-17 v3 transfer reconciles 150 original source identities:
127 compiler/assembler identities moved or deduplicated into PDP10
(99 relocated, 28 already owned) and 23 OS tests/helpers moved here.
The later v4 return restores 71 guest-native script/fixture files
from PDP10 to DAIMOS, removes their 25 manual PDP10 registrations, and
registers them as explicitly selected native integration suites here.
Cross-repository ownership and static dispatch checks pass. **No guest
compiler or full DAIMOS regression suite was executed during v4.**

## Focused verification (2026-11-19)

- All 25 native test roots are registered in DAIMOS with 71 restored files.
- Shell and Python static checks and the source/fixture hash audit pass.
- The PDP10 cross-boundary audit and both dispatch tests pass without
  launching SIMH, KCC, DAS or a guest operating system.
- The 25 native runtime oracles remain unverified pending staged builds.

## Earlier focused verification (2026-11-17)

- The shared cross-repository source/fixture/ownership guard passed.
- Eight relocated bounded DAIMOS host validations passed.
- The isolated DAIMOS recursive `RM -R` and retired assembler RM checks
  passed after separating them from KCC MAKE suffix assertions.
- `pdp10-testkit` registered host verification passed 20/20, including
  ownership, source-integrity and historical-document path checks.
  No compiler/assembler source,
  kernel or simulator implementation was changed as part of the move.
- Both testkits' v3 transfer manifests match byte-for-byte.

**Not executed:** a fresh full `make regression` DAIMOS sweep, the
operator-selected boot/media/native DAS guest suite, and the deferred
indirect/dynamic OS script-call audit. See `TODO.MD` for open items;
passing the static guard does not imply runtime tests passed.

## Historical results

The former 208 KB running status chronology, including the last
2026-11-09 KCC/KIR1 observations and earlier runtime tests, is retained
at `tests/validation/history/DAIMOS-TESTKIT-STATUS-THROUGH-20261109-v1.md`.
The text there is a historical source snapshot; its compiler paths
and test ownership are not current. See the versioned v3 migration
report in `tests/validation/` for the active paths.

## Production source documentation audit (2026-11-17)

Five dated D6FS/DTFS reports had relative `tools/host/` references
which could be mistaken for testkit-owned source files. They now use
`$DAIMOS_REPO/tools/host/d6fsck.c` or
`$DAIMOS_REPO/tools/host/mkdtfs.c`. Both production files were located
in the separate DAIMOS source repository. These are documentation
corrections only; no D6FS/DTFS native runtime result was rerun.
PDP10's independent historical-source crosswalk and Markdown path
audit are described in
`../pdp10-testkit/docs/PDP10-HISTORICAL-DOC-PATH-AUDIT-20261117-v1.md`.

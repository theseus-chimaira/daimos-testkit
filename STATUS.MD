# DAIMOS testkit - current verified status

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

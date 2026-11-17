# DAIMOS testkit - current verified status

Updated: 2026-11-17. This file records **verified** testkit ownership
and focused checks only; it does **not** certify a full DAIMOS release
or regression sweep.

## Ownership and migration

The compiler/assembler and OS repositories have separate active owners:

- `pdp10-testkit`: GCC, KCC, DAS, DLINK, compiler ABI, codegen, optimizer
  and standalone PDP-6/PDP-10 ISA tests.
- `daimos-testkit`: DAIMOS boot, KCORE/MRES/KINIT, DSH, devices,
  storage/filesystems, processes, syscalls and runtime acceptance.

The 2026-11-17 v3 transfer reconciles 150 original source identities:
127 compiler/assembler identities moved or deduplicated into PDP10
(99 relocated, 28 already owned) and 23 OS tests/helpers moved here.
Native compiler tests using a DAIMOS guest remain **manual compiler
assertions** in PDP10; they are not OS regressions merely because they
need a booted system as their environment.

## Latest focused verification (2026-11-17)

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

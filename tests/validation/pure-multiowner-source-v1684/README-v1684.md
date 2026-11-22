# v1684: PDP-6 RAW PURE two-owner executable-source lifetime (native C89)

Date: 2026-11-19. Status: **scoped source-linked native PASS**, not a
booted nine-process physical source-loss/PI6 release acceptance.

## Tested original source

The entire new oracle and additional process fixture are in
`test-native-v1684.c`, written in ANSI C89. The `run-v1684.sh` script
compiles and links the original KCC transaction source:

- Original `proc_pure_ram_v1381.c` zero-copy RAW DROP for two distinct
  resident processes (slots 1 and 2) and original PDP-6 MM rebase ASM.
- Original `proc_pure_ram_restore_v1391.c` bounded FULL restoration,
  with its source and destination MM pins simultaneously held.
- Original `proc_storage_runtime_v30.s` for PACKED/RESIDENT transitions.
- Original `proc_pure_backing_pdp6.s` executable-source vnode and mount
  guard instructions, extracted by the existing versioned v1649 script.

Both processes are first genuinely rebased by the original MM assembly
into separate `PACKED_PROCESS` suffixes, each with a distinct mount
identity and file index. During the first process's bounded FULL
callback, original physical owner table contains exactly three live
extents: PINNED PACKED original source, PINNED full PROCESS target,
and unpinned PACKED second source. Source-linked mount and vnode guards
must report both sources as busy and an unrelated file/mount free.
The callback checks each descriptor and verifies no change from the
source scans before letting the original FULL transaction publish.

After restoration of the first process, its executable backing still
must be protected. A **resident** process still owns its executable
source because it may be reclaimed again. This is intentional; one
early test expectation of an unprotected resident source was incorrect
and corrected without changing production code. The second process's
original RAW suffix descriptor and every mutable source word remain
identical. Removing its mounted provider causes the original FULL
preflight to return `MM_ERR_INVAL` without allocating a target, losing
pins, modifying the retained source, or clearing TRANSITION. Restoring
that provider leaves its source eligible again.

The test retains the complete original v1649 single-owner native FULL
transaction and its earlier v1648/v1395 rollback prerequisites.
Separately compiled/linked unsafe mutations of the **actual original
PDP-6 backing and mount guard code** run with the *v1684-only C oracle*
(no earlier baseline to falsely catch the mutation):

| Test-only original ASM mutation | Expected guest exit (octal) |
| --- | --- |
| Incorrect mount busy scan | `000000004004` |
| Incorrect executable-vnode identity scan | `000000004200` |

Both mutations must reach the PDP-6 `__test_exit` oracle and fail at
these exact codes. Compiler/link errors or timeouts are not accepted.
The original source-linked positive result returns zero.

## Scope and limits

This test is native C89 logic executing compiled on a PDP-6 simulator,
not a new assembly-authored test. The existing original assembler MM,
mode and backing routines are nevertheless exercised because they are
the production implementation. The native fixture supplies process
slots, mount roots, MM allocation and the FULL payload callback. It
does not prove a genuine physical VFS unmount attempt while nine RAW
owners are under pressure, secondary DTFS media removal, PI6 timing,
source replacement, or successful second-owner FULL restoration after
provider return. Those are still P1-E release gates.

No original DAIMOS kernel object, fixed-KCORE RAM, ABI, installer or
source file was modified. There is no new persistent allocation.

Reproduce:

    DAIMOS_REPO=<PURE-source-checkout> \
        sh tests/validation/pure-multiowner-source-v1684/run-v1684.sh

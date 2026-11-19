> Historical checkpoint. Current ownership: `tests/validation/NATIVE-TOOLCHAIN-MIGRATION-20261119-v2.md`.

# DAIMOS operating-system test ownership (2026-11-17 v3)

`daimos-testkit` owns DAIMOS boot, KINIT/KCORE/MRES, DSH, D6FS/TSFS,
devices, processes, syscalls, scheduler and runtime/guest service tests.
`pdp10-testkit` owns GCC, KCC, DAS, DLINK, compiler ABIs, optimizer
output, assembler formats and standalone processor ISA assertions.
Choose by the **primary asserted behavior**, not by which compiler or
assembler was used to prepare a guest test.

The source-hash-pinned
`tests/validation/TESTKIT-SCOPE-MIGRATION-20261117-v3.tsv`
matches the identically named manifest under `pdp10-testkit/docs/`.
It tracks **127 compiler/assembler source and helper files relocated or
deduplicated into PDP10** (including 71 guest-native compiler toolchain
suite files and 28 already-owned equivalent/stronger cases), and **23
boot, root-media, linked-kernel and native DAS guest/OS files moved
here**. No original source C or assembly fixture assertions were
changed. The intermediate v1/v2 manifests remain available in Git
history rather than as duplicate active snapshots. Canonical v3
includes the 59 native KCC/DAS/DLINK files and 12 additional native KCC
preprocessor/parser/optimizer/Makefile and progress assertions.

All eight relocated bounded OS host checks are callable through
`make test-daimos-migrated-os-host-v1`; the guest/boot cases are
**explicitly opt-in** via the following Makefile targets:

* `test-daimos-aap-stage1-v1`
* `test-daimos-aap-stage1-trace-v1`
* `test-daimos-aap-alt-stage1-media-v1`
* `test-daimos-aap-ptr-handoff-v1`
* `test-daimos-simh-ptr-tsfs-boot-v1`
* `test-daimos-native-das-guest-v1`

Those opt-in tests need their original simulator, media, build and/or
native DAS prerequisites and must not be counted as run merely because
their new paths are owned. Their source and helper modules are under
`tests/validation/` and `tools/`. Host-only validators that need
generic ISA metrics use the sibling `pdp10-testkit` through
`PDP10_TESTKIT_REPO`, without keeping copies of ISA engine sources.

The former mixed host RM/KCC test was split. The DAIMOS host test
retains recursive `RM -R` and obsolete assembler RM removal checks;
KCC native `.S.DOBJ` suffix and `CLEAN` makefile checks now live in
`pdp10-testkit/misc/kcc-host/`.

`make test-testkit-scope-v1` invokes the authoritative versioned
cross-repository static checker using `--require-cross`. Neither it
nor the host-only checks invoke the full DAIMOS or compiler sweep.
Dynamic OS script call-graph coverage remains a separate TODO.

Compiler guest suites in PDP10 use `DAIMOS_TESTKIT_REPO` to invoke the
OS testkit boot infrastructure; they are explicitly manual, not default
compiler sweeps. The cross-repository source-hash checker recognizes all
150 original test identities. Runtime dispatch coverage for unrelated
DAIMOS OS scripts remains independent.

## Documentation ownership (2026-11-17)

Only the v3 ownership report and hash manifest remain active; older
v1/v2 files were superseded and can be retrieved from Git history.
The historical, **DAIMOS-specific** AAP kernel mnemonic inventory is
now `tests/validation/DAIMOS-AAP-KERNEL-COVERAGE-MATRIX-20261117-v2.md`.
Generic AAP processor instruction/timing oracles remain in PDP10.
The detailed pre-split STATUS chronology (with now-obsolete compiler
test paths) is retained at
`tests/validation/history/DAIMOS-TESTKIT-STATUS-THROUGH-20261109-v1.md`;
the active `STATUS.MD` contains only the latest verified testkit state.

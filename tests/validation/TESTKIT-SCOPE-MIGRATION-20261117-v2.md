# DAIMOS operating-system test ownership (2026-11-17 v2)

`daimos-testkit` owns DAIMOS boot, KINIT/KCORE/MRES, DSH, D6FS/TSFS,
devices, processes, syscalls, scheduler and runtime/guest service tests.
`pdp10-testkit` owns GCC, KCC, DAS, DLINK, compiler ABIs, optimizer
output, assembler formats and standalone processor ISA assertions.
Choose by the **primary asserted behavior**, not by which compiler or
assembler was used to prepare a guest test.

The source-hash-pinned
`tests/validation/TESTKIT-SCOPE-MIGRATION-20261117-v2.tsv`
matches the identically named manifest under `pdp10-testkit/docs/`.
It tracks **115 compiler/assembler source and helper files relocated or
deduplicated into PDP10** (including 59 guest-native compiler toolchain
suite files and 28 already-owned equivalent/stronger cases), and **23
boot, root-media, linked-kernel and native DAS guest/OS files moved
here**. No original source C or assembly fixture assertions were
changed. The `v1.tsv` remains for the first transfer stage; `v2.tsv`
adds the 59 native compiler suites.

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

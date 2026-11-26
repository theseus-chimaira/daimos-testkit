# K10 v1976: executable eligibility

Run with installed PDP10_PREFIX utilities and DAIMOS_REPO pointing at
DAIMOS. The host runner can also select freshly built tool directories
via DAIMOS_HOST_BIN and DAS_HOST_BIN. It checks the exact TX2 bit,
unchanged header length/payload/relocation, compression, raw conversion,
INITFS output, real D6FS formatting and rejected malformed/RT headers.

    python3 tests/validation/pure-mutable-admission-v1976/run-host-v1976.py
    sh tests/validation/pure-mutable-admission-v1976/run-v1976.sh

The native source-linked 26-case matrix uses real loader, shared
inspector and attach/detach implementation; VFS, VM allocation and
terminal storage I/O are controlled leaves. Its privilege-check mutant
must execute and fail. Independent RUN (64 cases) and staged EXEC
(nine cases) tests extend the earlier mount/provider identity fixtures.

    sh tests/validation/pure-provider-identity-v1924/run-run-v1924.sh
    sh tests/validation/pure-exec-handover-v1934/run-v1934.sh

Marked full-kernel lifecycle tests, 64K disk profile, repeat on both
PDP6 and KA10, using distinct directories and ports:

    DAIMOS_MUTABLE_MARK_V1976=1 sh tests/validation/k17-proc-v1974/run-v1974.sh pdp6 lifecycle WORK PORT

Full actual EXEC under UID6/GID7 after 28 malformed EXEC/RUN checks:

    ROOT=disk BOOT=dsk BOOT_PROFILE=lowmem BOOT_CORE_WORDS=0200000 SIMH_CPU_KWORDS=64 DAIMOS_EXEC_OBSERVE_SECONDS=90 DAIMOS_EXEC_MUTABLE_MARK_V1976=next DAIMOS_KEEP_EVIDENCE_V1976=1 sh tests/validation/daimos-exec-replace-v1.sh

Native DLINK option, real archive, file-header check and execution:

    DAIMOS_MUTABLE_MARK_V1976=1 KEEP_WORK=1 sh tests/validation/daimos-native-tools-v1.sh

No test enables mode3. Future FORK must inherit only eligibility;
there is no current FORK entry to test. Exact MM ownership, compression
payback and mode3 lifecycle remain separate gates.

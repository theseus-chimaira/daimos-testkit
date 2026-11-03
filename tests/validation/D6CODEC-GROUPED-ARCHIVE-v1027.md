# D6CODEC grouped-stream test history (2026-11-03 v1027)

This archive branch preserves the experimental grouped-format validation
history from the six D6CODEC test branches (v075, v078, v079, v085,
v089 and v091). The merges used the `ours` strategy intentionally:
they retain the original commits without attempting to combine their
mutually incompatible historical test files into one runnable suite.

The supported DAIMOS `main` still builds D6LZ36 for boot and runtime.
The new grouped codec is **staged, not integrated**. Historical tests
refer to the experimental `d6codec_decode_group_v061.s`,
`d6codec_vfs_v062.s`, and `d6codec-group-v071/v072.c`, none of which
is part of present DAIMOS `main`. Do not use the historical test results
as current native boot, PURE swap, or end-to-end acceptance evidence.

The active staged-codec check remains
`tests/validation/d6codec-kcore-abi-v055/run-v055.sh` on testkit main.
It was rerun against DAIMOS main in this consolidation and passed on
PDP-6. No 32K-specific tests were run.

To revive this work, first reconcile the format and caller ABI against
the active DAIMOS tree and the cutover checklist in
`system/kernel/core/D6CODEC-INTEGRATION-TODO-v054.md`. Never mix old
D6LZ and experimental grouped streams in one boot image. Until the
full cutover is tested, keep grouped-stream examples on this archived
branch, not on the default testkit acceptance path.

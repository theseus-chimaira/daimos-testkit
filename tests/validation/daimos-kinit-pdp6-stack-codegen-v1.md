# DAIMOS KINIT PDP-6 stack code generation v1

Owner: daimos-testkit. This is a DAIMOS kernel integration check, not
an independent compiler regression: it compiles the production DAIMOS
`system/kernel/boot/kinit.c` via the production KINIT Makefile, then
asserts that the resulting PDP-6 assembly does not use unsupported
`ADJSP` and does contain the paired-halfword simulated stack change.

```
make test-daimos-kcc-pdp6-codegen \
  DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
```

Migrated from `pdp10-testkit/misc/validation/daimos-kcc-pdp6-codegen-v1.sh`
on 2026-11-19 without weakening either assertion. The production
kernel stamp rule is repaired in DAIMOS commit `01e58f2` by defining
`KINIT_STACK_WATERMARK` before expanding its prerequisite target. The
relocated test passed using the installed host KCC and actual DAIMOS
kernel source. It does not boot DAIMOS or imply a full KINIT regression
sweep. Standalone compiler stack-ABI regressions remain PDP10-testkit
property.

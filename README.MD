# DAIMOS operating-system testkit

This repository tests the **DAIMOS operating system** on PDP-6/PDP-10:
boot and root selection, KINIT/KCORE/MRES, filesystems, device drivers,
DSH, processes, memory management, scheduling, syscalls and user runtime.
Generic GCC/KCC, DAS/DLINK, optimizer, ABI, assembler-output and CPU ISA
tests belong in the separate `../pdp10-testkit` repository.

## Boundary between the testkits

Ownership is determined by the **primary assertion**, not the tool or
execution environment. A D6FS test may invoke DAS or KCC and remains
an OS test. Conversely, **native KCC/DAS/DLINK toolchain assertions run
inside a booted DAIMOS guest still belong to `pdp10-testkit`** as manual
compiler/assembler tests. They call this testkit's OS harness through
`DAIMOS_TESTKIT_REPO`, but are not duplicated here.

The current cross-repository migration is documented in
`tests/validation/TESTKIT-SCOPE-MIGRATION-20261117-v3.md`; its canonical
150-original-source transfer manifest is the matching v3 TSV here and
in `pdp10-testkit/docs/`. Intermediate v1/v2 manifests are available
from Git history, not maintained as active alternative inventories.

## Requirements

- POSIX shell and GNU Make, ordinary host utilities and a host C compiler.
- PDP-6 SIMH for PDP-6 runtime/guest work.
- `PDP10_PREFIX`: installed PDP-10 toolchain root.
- `DAIMOS_REPO`: current DAIMOS source checkout.
- `TMPDIR`: writable scratch directory (prefer `$HOME/tmp` by default).
- For OS tests using generic CPU/ISA evidence helpers,
  `PDP10_TESTKIT_REPO` optionally overrides the sibling checkout.

Example setup:

```sh
export PDP10_PREFIX="$HOME/cross"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_TESTKIT_REPO="$HOME/git/pdp10-testkit"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
make test-testkit-scope-v1
make test-daimos-migrated-os-host-v1
```

The two commands above are **static/host-only**, not a guest-boot or
compiler matrix sweep. The second runs eight bounded OS helper tests.
The original recursive `RM -R` OS assertions have the explicit target
`test-daimos-rm-recursive-os-20261117-v1`; native KCC Makefile suffix
and CLEAN assertions moved to `pdp10-testkit/misc/kcc-host/`.

## Test areas and entry points

- `tests/host/`: DAIMOS host-side assertions and fixture preparation.
- `tests/target/`: small programs exercising DAIMOS on the PDP-6.
- `tests/system/`: kernel, MM, filesystem, devices and boot integration.
- `tests/validation/`: targeted OS invariants, boot/media probes,
  root-state verification, versioned supporting evidence and the
  authoritative regression matrix.
- `tools/`: DAIMOS-specific PTY/SIMH, disk-media and root-state helpers.

`make check` performs the ordinary host and target checks. `make target`
selects the direct OS target group. `make regression` performs the **full,
serial, resumable DAIMOS acceptance sweep**; it may be long-running and
is run only on explicit request. `make regression-status` inspects saved
checkpoints, while `make regression-restart` begins a new sweep.

The authoritative matrix is
`tests/validation/daimos-regression-matrix-v1.tsv` with the summary in
`REGRESSION-MATRIX.MD`. Regression checkpoints are source-fingerprinted;
a retained historical pass must not be mistaken for a fresh result.
`COMPILER=kcc` (default) or `COMPILER=gcc` selects the toolchain when
building the DAIMOS programs under test. It does not move generic
compiler correctness tests into this repository.

The DSH guest harness, `tools/daimos-simh-harness-v4.sh` (and the
v6 native phase variant), drives PDP-6 SIMH through `tools/pty-run-v1.c`
using a persistent FIFO. The declarative probes assert guest output and
exit/terminal conditions. No Python `pexpect`/Tcl `expect` is needed.

## Explicit boot and guest-native OS tests

The relocated DAIMOS boot/media and guest acceptance checks are **opt-in**:

```sh
make test-daimos-aap-stage1-v1
make test-daimos-aap-stage1-trace-v1
make test-daimos-aap-alt-stage1-media-v1
make test-daimos-aap-ptr-handoff-v1
make test-daimos-simh-ptr-tsfs-boot-v1
make test-daimos-native-das-guest-v1
```

These targets need their original SIMH, media, staged build and/or
native DAS prerequisites. Listing a target or passing its static
ownership check does **not** mean it has completed execution.

## Documentation

- `TODO.MD`: open OS testkit tasks and acceptance blockers.
- `STATUS.MD`: dated verification observations, not present-day
  compiler/assembler ownership or a fresh sweep result.
- `REGRESSION-MATRIX.MD`: condensed DAIMOS acceptance stages.
- `tests/validation/TESTKIT-SCOPE-MIGRATION-20261117-v3.md`: canonical
  scope, migration and static enforcement explanation.
- `tests/validation/DAIMOS-AAP-KERNEL-COVERAGE-MATRIX-20261117-v2.md`:
  **historical** DAIMOS kernel static mnemonic coverage; generic AAP
  timing/ISA fixtures remain in `pdp10-testkit`.

Only the explicitly recorded, focused host and ownership checks were
executed for the repository split. Full DAIMOS runtime validation is
still a separate acceptance task.

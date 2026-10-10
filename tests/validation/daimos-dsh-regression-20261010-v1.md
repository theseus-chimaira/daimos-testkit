# DSH regression run, 2026-10-10 (v1)

This is a test execution record, not a claim that the DSH conformance gate
has passed. Keep active implementation TODOs in DAIMOS/userland/dsh/TODO.MD.

## Environment

- Source: current DAIMOS and daimos-testkit checkouts on 2026-10-10.
- PDP-6 SIMH from /usr/local/bin/pdp6.
- Installed /usr/local toolchain, with an isolated prefix pointing to its
  compiler, assembler, linker, includes and KCC bootstrap libraries.
- Isolated prefix d6fsck rebuilt from current DAIMOS/tools/host/d6fsck.c.
- Isolated image build under $HOME/tmp/dsh-regression-20261010-v4.

## Results

- Conformance file syntax: 115/115 definitions accepted.
- DSH fixed-resource source contract: 11 limits checked, PASS.
- FCB owner width 254+ checker regression: PASS with current d6fsck source.
- DSH foreground acceptance: PASS (Ctrl-C line cancellation, single-job and
  pipeline FG/TTY restoration, and multijob default FG recency).
- Broad DSH SIMH run: 67 PASS, 8 FAIL among the first 75 probes; the run
  stopped when function recursion caused a shell restart and prompt timeout.
- Missing MAN page diagnostic fixed separately in DAIMOS commit bf963a4.
  After rebuilding the userland image, its targeted SIMH probe passed.

## Failures in the initial broad run

- manual-not-available: MAN printed `MAN: NO ENTRY: NOSUCHHELP` rather than
  `MANUAL NOT AVAILABLE`; fixed and separately retested.
- dsh-pipeline-data, dsh-pipeline-last-success, dsh-pipeline-three-stage,
  dsh-pipeline-eight-stage: second RUN stage returned 126. The current shell
  emitted PIPEDBG output (first stage launched; JOIN stage failed). This
  requires root-cause investigation in the RUN/group-join and FD-map paths.
- dsh-positional-three-eight: dependent on the failed pipeline launch.
- dsh-source-positional-restore: missing `SOURCE:I` output; inspect SOURCE
  frame restoration on the current compiler-generated code.
- dsh-function-recursion-limit: shell restarted to LOGIN instead of returning
  status 2, stopping the shared-session run at probe 75.

The earlier use of an outdated installed d6fsck falsely reported five leaked
blocks during image construction. The current source checker passes its FCB
owner-width test and a fresh image checks cleanly. Shared stale KINIT build
output also caused an earlier undefined symbol; a clean build passed that step.

A subsequent ad-hoc pipeline isolation run using the previously exercised
image failed at boot with `?RT`, HALT PC 071501. Its result is inconclusive;
repeat on a fresh immutable disk image before drawing conclusions.

## Remaining acceptance

Rerun the complete 115-probe suite using a clean isolated image, fix all
failures at their source, and add direct lexer/parser and working-set runtime
measurements. Do not update the verified DSH baseline in pdp10-doc until the
full relevant tests pass.

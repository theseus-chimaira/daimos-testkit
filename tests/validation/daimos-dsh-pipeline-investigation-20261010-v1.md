# DSH pipeline regression investigation (2026-10-10, v1)

## Reproduction

Run `make test-daimos-dsh-pipeline` in daimos-testkit with a working PDP-6
compiler/tool prefix and a clean image. The three cases in
`probes/daimos-dsh-pipeline-regression-20261010-v1.txt` reproduce failures
in two- and three-stage concurrent pipelines and final-stage status.

On a clean isolated DAIMOS checkout based on bf963a4, all three cases failed
in SIMH. The probe file passes the host probe-format validation. A failing
probe is a regression report, not a successful acceptance result.

## Observations from temporary instrumentation

The initial pipeline stage launched successfully. The second RUN failed, and
the shell returned status 126. A diagnostic RUN/loader build identified a
failure in `exec_load_process()` while resolving the next executable pathname:
the pathname walker encountered a failed access/stat operation on its root
directory. No DXR header or payload had been read at that point.

Changing the second stage's process-group mode, delaying TTY handoff, or
waiting for the first child did not resolve the failure. Launches passed when
the first stage's standard output was not mapped to the pipe, suggesting the
failure involves the live inherited pipe descriptor and filesystem lookup.

Experiments using descriptor resets (`next_read = next_write = -1`) did not
actually transmit pipe FDs to children. These runs cannot support claims
about pipe correctness, `AOS`, P10FOLD, or provider serialization. Subsequent
corrected experiments failed with both `AOS` and an equivalent explicit
load/increment/store; excluding `pipe.dobj` from the fold plan also failed.
No assembler, CPU emulator, or P10FOLD defect has been established.

## Follow-up

Investigate file descriptor mapping and pipe state during `SYS_RUN`, focusing
on what changes before the second child executes `file_lookup_path()` and
`vfs_stat()` through the filesystem provider. Use a clean image and preserve
the provider's existing serialization semantics. Fix the root cause rather
than removing pipe references or sequentializing pipelines.

After the correction, run the isolated pipeline probes, the full 115-case DSH
conformance suite, and the real-DCS foreground/TTY restoration acceptance.
The earlier SOURCE and function-recursion failures also remain open.

All diagnostic source changes were discarded from the isolated DAIMOS
worktree. This report and the new probes belong to daimos-testkit; there is
no corresponding production DAIMOS code change in this investigation.

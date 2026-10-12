# Resident SUPERVISOR source-size audit (2026-10-12 v3)

The resident PID 1 supervisor writes its two-word SIXBIT TTY record
directly, decodes the four-character INIT handoff directly, and avoids
clearing RUN V2 records that are fully overwritten before the syscall.
Its supervision semantics and eight-entry INITTAB capacity are unchanged.

PDP-6 KCC/DAS measurements (octal):

| | PID 1 v2 | Text shrink v3 |
| --- | ---: | ---: |
| SUPERVISOR image | 001530 | **001447** |
| SUPERVISOR BSS | 000461 | **000461** |
| Rounded initial VM | 006000 | **006000** |

The image shrinks by 0061 octal (49 decimal) words. The standard 02000
stack allowance is unchanged. The versioned v3 size guard checks the
stricter 001447 image limit on fresh DXR builds.

Full PDP-6 boot and DSH conformance must be checked separately; image
size alone does not prove that the PID 1 handoff or ONCE/RESPAWN behavior
works. The 32K EXEC issue remains a separate open acceptance test.

# Ambiguous FCB completion — narrowed experiment, 2026-10-12

Test-only post-write error injection was narrowed from all FCB blocks
442..486 to logical block **479** on the cloned image. The C99 append
fixture still reported a failed syscall while reading back the two-word
committed file, and the HALT probe passed. The test **fails** end-to-end:
`d6fsck` again reports unreachable FCBs 451 and 452 (reference count zero).
Narrowing the injected range alone therefore does not eliminate the error.

A control run with a post-write selector for unreachable block 16777215
made the fixture's negative-write assertion fail (as expected). The test
harness ends on this negative probe, so it did not execute an orderly HALT
or provide a comparable control `d6fsck` result. **The control experiment
is inconclusive**, not evidence that the unmodified kernel is clean or bad.

The selected FCB block 479 is an investigative candidate, not yet proven
to be the target file's FCB block. Add exact file-FCB identification and
a write-hit trace before making causal claims. Keep this regression open;
never describe it as a power-cut or transaction-atomicity acceptance test.

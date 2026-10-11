# MEMFS O_APPEND write-time EOF regression (2026-10-11 v1)

The native PDP-6 binary `/CONFIG/MAPP2.TEST` creates a writable MEMFS file
at `/TEMP/APP2DATA`, then opens two O_APPEND descriptors **before either
writes**. It seeks the second descriptor to zero, appends a word through each,
then duplicates and appends through the first. The test checks each cursor,
all four raw words and clean close. This detects stale open-time EOF semantics
without relying on DSH background jobs or scheduler timing.

The native test runner builds an isolated boot image, executes it via SIMH,
then HALTs and checks the root filesystem. Results:

- Modified kernel: 2/2 simulator probes PASS; D6FS root remains CLEAN.
- Original kernel: negative control FAIL at SECOND-CURSOR (1 rather than 3).
- Modified kernel: preexisting native D6FS append regression PASS again,
  including clean shutdown.

The implementation uses the already packed regular-file append descriptor
flag and resolves offset -1 from the current MEMFS slot word count inside
`memfs_write_words`. The MEMFS provider executes as a resident service;
it does not add another permanent lock table or descriptor word.

This proves two descriptors opened before both writes, not simultaneous writes
from independently scheduled processes. Power-loss injection and partial
S6REC record writes remain out of scope for this regression.

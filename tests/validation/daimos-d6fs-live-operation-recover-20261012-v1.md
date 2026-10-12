# Real PDP-6 interrupted append, offline recovery, and clean reboot (2026-10-12 v1)

## Scope

An **isolated test-only** variant of `fs_backing_write` calls the real disk
backing callback, checks successful completion, then executes `HALT .` if
the written block begins with the fixture's unique 36-bit seed word
`0123456701234`. Source DAIMOS code is never modified by the injector;
only the generated assembler for this test image is replaced. No production
kernel data or on-disk format change is involved.

The PDP-6 C99 fixture `/CONFIG/FAULT.TEST` opens the pre-seeded one-word
`/CONFIG/FCBSEED` with `O_APPEND` and requests a one-word append. The seed
selects the actual data-block write. HALT occurs **after successful return
from the backing callback** and before the append publishes a new EOF.
The fixture prints `OPERATION-CUT-START` before the write and would print
`OPERATION-CUT-NOT-TRIGGERED` if the write ever returned. The test requires
the simulator's `(HALT ...)` instruction display, and excludes the latter
message. It does not merely inject an error return.

`d6fsck -n 4` then checks the four-member disk image and **must fail** with
a DIRTY selected superblock. The test clones all four DSK members, runs
production host `d6fsck -r` on the clone, and confirms CLEAN. A fresh PDP-6
SIMH boot uses a rewritten boot file referencing **only the repaired clone**.
The separate C99 `/CONFIG/VERIFY.TEST` reads two words and must receive
exactly one: the original seed. `STAT /CONFIG/FCBSEED` must likewise print
`WORDS 1 MODE`. The second boot ends in a regular DSH `HALT` command. Source
media checksums before and after clone repair/reboot must be unchanged.

## Observed live acceptance

- SIMH test-only post-write HALT at address `032342` (octal), probe PASS.
- Post-cut `d6fsck`: selected superblock `0671`, sequence 2, DIRTY.
- Offline clone repair: superblock `0670`, sequence 3, CLEAN; 179196 blocks,
  368 FCBs; verification CLEAN.
- Fresh PDP-6 boot: direct seed/EOF verifier PASS; STAT reports one word;
  normal final HALT PASS; faulted source disk unchanged.

Runner:
`DAIMOS_REPO=... PDP10_PREFIX=... TMPDIR=$HOME/tmp tests/validation/daimos-d6fs-live-operation-recover-20261012-v1.sh`

`PTY_RUN` may select the existing versioned PTY relay; without it the
runtime harness expects `$TMPDIR/dsh-history-runtime-20261011-v2/pty-run`.
`DAIMOS_HOST_TOOLS`, `DAS_REPO`, and `KCC_REPO` can override host build
paths. The runner retains versioned per-trial artifacts under `$TMPDIR`.

## Limits

This **is an emulator instruction HALT**, not a physical power cut; simulator
and host operating-system buffering do not establish the actual durable
ordering of a real disk controller. This test covers one data-block append
boundary while the original file's one-word allocation already exists. It
does not cover newly allocated extents, partially durable directory/FCB
blocks, every cut in a multi-block append, concurrent writers, or crash-atomic
HISTFILE records. In particular, it is not evidence that an arbitrary write
which reports success was physically flushed before the processor stops.

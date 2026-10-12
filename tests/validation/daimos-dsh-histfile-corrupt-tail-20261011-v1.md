# DSH damaged HISTFILE tail acceptance — 2026-10-11 v1

The native C99 fixture executable installs `/.DSH_HISTORY` with a valid
S6REC containing `ECHO SAFE`, followed by an S6REC TEXT header of length
18 whose three payload words are intentionally absent. The fixture is
created during an interactive ROOT session and persisted with orderly HALT.

The test runner reboots the **same D6FS image**, logs in interactively and
asserts that the startup transcript contains
`DSH: HISTFILE TAIL REPAIRED`. Ctrl-P must recall the valid
`ECHO SAFE` command. It then executes another orderly HALT and requires
`d6fsck` CLEAN. The two boots passed 4/4 probes in total. The final checker
reported superblock 706, sequence 5, CLEAN (179196 blocks, 344 FCBs).

The revised test adds a third boot: repair must not repeat on an already
repaired file, and the most recent valid entry must remain recallable.
DSH now uses the kernel's advisory exclusive FLOCK for both history startup
validation/truncation and participating DSH appends. Other writers that do
not honor FLOCK are outside that coordination contract.

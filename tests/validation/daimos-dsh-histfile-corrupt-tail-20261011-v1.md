# DSH damaged HISTFILE tail acceptance — 2026-10-11 v1

The native C99 fixture executable installs `/.DSH_HISTORY` with a valid
S6REC containing `ECHO SAFE`, followed by an S6REC TEXT header of length
18 whose three payload words are intentionally absent. The fixture is
created during an interactive ROOT session and persisted with orderly HALT.

The test runner reboots the **same D6FS image**, logs in interactively and
asserts that the startup transcript contains
`DSH: HISTFILE DAMAGED; VALID PREFIX LOADED`. Ctrl-P must recall the valid
`ECHO SAFE` command. It then executes another orderly HALT and requires
`d6fsck` CLEAN. The two boots passed 4/4 probes in total. The final checker
reported superblock 706, sequence 5, CLEAN (179196 blocks, 344 FCBs).

No automatic truncation or repair occurs, because a concurrent HISTFILE
writer could be active and the current file-lock mechanism cannot guarantee
cross-process serialization. The test establishes *warning plus valid prefix
preservation*, not recovery of later records behind a damaged S6REC tail.
A filesystem-supported atomic record commit or cross-process-safe repair
protocol remains necessary for stronger persistence guarantees.

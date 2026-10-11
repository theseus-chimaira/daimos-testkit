# DSH HISTFILE runtime acceptance, 2026-10-11 v1

On an isolated fresh PDP-6 SIMH D6FS image, login as ROOT and run
`probes/daimos-dsh-histfile-runtime-20261011-v1.txt` using the testkit v6
harness. The initial run passed all three probes: write a command, read its
S6REC entry using `CAT /.DSH_HISTORY`, and recall a command with Ctrl-P.

A separate restart attempt did **not** reach LOGIN. It terminated at
`?RT` (HALT PC 071511); `d6fsck` reported superblock 706 sequence 2 DIRTY.
Even issuing the privileged `HALT` command in a later fresh run terminated
SIMH at PC 021166 with the D6FS superblock still DIRTY. The syscall HALT
path calls `fs_memfs_shutdown` but does not perform a D6FS root transition
to CLEAN. D6FS supplies that transition in its unmount provider.

This is a kernel shutdown/root lifecycle blocker, **not** evidence that
DSH history entries cannot survive reboot. Do not accept restart persistence
until a clean-shutdown boot/reload test passes. Concurrent session appends
also remain unverified. Do not fix this by blindly marking the root clean
or bypassing root-state verification.

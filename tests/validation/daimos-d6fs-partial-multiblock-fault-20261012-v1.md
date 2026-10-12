# D6FS staged growth: second-block backing-write failure (2026-10-12 v1)

Native C99 test `/CONFIG/FAULT.TEST` attempts to write 256 words to a new
D6FS file. The first 128-word block has ordinary values, while the second
block starts with octal `0765432107654`. A test-only backing dispatcher
rejects any block whose first word has that marker. The write syscall must
fail, and reopening the file must return EOF immediately. An orderly HALT
and clean `d6fsck` are mandatory.

Live PDP-6 SIMH test: injected-write/old-EOF probe PASS, HALT probe PASS,
`d6fsck` CLEAN (179196 blocks, 360 FCBs, superblock 670 seq 3).
No production kernel code or on-disk format was modified.

The kernel writes data blocks in order, so this specifically exercises the
second-block failure path after the first-block write operation returned.
It does **not** independently inspect the first block's physical durability,
or test allocation-map failure, FCB-publication failure, sudden power loss,
or crash-atomic HISTFILE commit. Those acceptance cases remain open.

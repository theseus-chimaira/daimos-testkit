# D6FS test-only backing fault link acceptance (2026-10-12 v1)

`tests/validation/daimos-d6fs-fault-link-20261012-v1.sh` builds an
isolated KCORE assembler tree, generates a faulted `fs_backing.s` using
`tools/fault/d6fs-fault-write-v1.py`, replaces ONLY that generated copy,
then completes the normal PDP-6 boot image build. Normal DAIMOS sources
and production build defaults are not modified.

Test execution used `FAULT_LOGICAL=0xFFFFFF` (an unreachable backing block)
to validate integration without injecting a live filesystem failure.
The PDP-6 SIMH interactive boot passed `ECHO INJECTORBOOT` and HALT (2/2),
and `d6fsck` found superblock 706, sequence 3, CLEAN, 179196 blocks,
360 FCBs. The build contained the generated fault branch. This proves
assembly/link compatibility and a successful baseline boot, **not** that
write rejection, rollback, or crash recovery works.

Next: identify the exact logical block(s) of a disposable D6FS test file,
rebuild with that target, perform and inspect a failing write, verify old
EOF and file contents, and run d6fsck. A persistent block filter cannot
model an isolated final-FCB-commit error; add a precisely scoped one-shot
fault mechanism before testing that outcome. Never inject against an
uncloned production disk image.

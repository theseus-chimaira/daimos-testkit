#!/usr/bin/env python3
"""One-time BACKSTORE write refusal in the real PDP-6 MEMFS snapshot code.

The second write in the first shutdown (the first file payload) returns -1.
The commit-header invalidation has already reached the real backing device.
The public HALT syscall must refuse to halt and permit a later retry.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: ... original/memfs_snapshot_pdp6.s copied-file")
original = Path(sys.argv[1]).read_text()
dest = Path(sys.argv[2])
head, sep, tail = original.partition("memfs_snapshot_shutdown:\n")
if not sep:
    raise SystemExit("v1478: snapshot shutdown entry missing")
call = "        pushj   17,backstore_write"
if tail.count(call) != 4:
    raise SystemExit("v1478: production snapshot write sequence changed")
tail = tail.replace(call, "        pushj   17,daimos_test_snapshot_write_v1478")
tail += """
; v1478 TEST SOURCE COPY: the first commit-header write succeeds, then
; reject the first actual file payload write without issuing device IO.
; Repeated calls, including an orderly HALT retry, reach real BACKSTORE.
        .text
        .globl daimos_test_snapshot_writes_v1478
daimos_test_snapshot_write_v1478:
        aos     daimos_test_snapshot_writes_v1478
        move    0,daimos_test_snapshot_writes_v1478
        caie    0,2
        jrst    backstore_write
        seto    1,
        popj    17,
        .bss
daimos_test_snapshot_writes_v1478: .block 1
"""
dest.write_text(head + sep + tail)
print("v1478: one-time second BACKSTORE write refusal inserted")

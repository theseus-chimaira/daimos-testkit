#!/usr/bin/env python3
"""Extract real staged Stage-1 handoffs for native PDP-6 acceptance."""
import pathlib
import sys

if len(sys.argv) != 5:
    raise SystemExit("usage: generate-handoff-v1363.py STAGE1_SRC KIND good|bad OUT")
source, kind, mode, destination = sys.argv[1:]
assert kind in ("dsk", "drm", "dtc", "mtc", "ptr")
assert mode in ("good", "bad")
data = pathlib.Path(source).read_text()
start = data.index("stage1_handoff:\n")
stop = ("daimon_magic:" if kind in ("dsk", "drm") else
        "stage1_raw_handoff:" if kind == "dtc" else "bad_tape:")
end = data.index(stop, start)
handoff = data[start:end]
assert "d6codec_v053_decode" in handoff
assert "d6lz_fixed_base" not in handoff

setup = """.text
.globl main
.globl d6codec_v053_decode
main:
        movei 017,020000
        move 0,[012345670123]
        movem 0,030000
"""
if mode == "good":
    setup += """        move 0,[010000000000]
        movem 0,030001
        movei 0,052
        movem 0,030002
        movei 0,2
"""
else:
    setup += """        setzm 030001
        movei 0,1
"""
if kind in ("dsk", "drm"):
    setup += """        movem 0,compressed_words
        move 0,[030001]
        movem 0,kinit_stack_base
        movei 0,2
        movem 0,member_count
        movei 0,entry_ok
        movem 0,entry_addr
"""
elif kind in ("dtc", "mtc"):
    setup += """        move 04,0
        movei 013,1
        movei 05,entry_ok
"""
else:
    setup += """        movem 0,compressed_words
        movei 0,1
        movem 0,image_words
        movei 016,entry_ok
"""
setup += "        jrst stage1_handoff\n"

if mode == "good":
    check = """entry_ok:
        move 0,030000
        caie 0,052
        jrst fail_case
        move 0,017
        came 0,[030001]
        jrst fail_case
"""
    if kind in ("dsk", "drm"):
        check += """        jumpn 01,fail_case
        caie 02,2
        jrst fail_case
"""
    check += """        setzm __test_exit
        jrst 04,0
"""
    check += "fail_decompress:\n" if kind in ("dsk", "drm") else "bad_tape:\n"
    check += "        jrst fail_case\n"
else:
    check = """entry_ok:
        jrst fail_case
"""
    check += "fail_decompress:\n" if kind in ("dsk", "drm") else "bad_tape:\n"
    check += """        move 0,030000
        came 0,[012345670123]
        jrst fail_case
        setzm __test_exit
        jrst 04,0
"""

check += """fail_case:
        setom __test_exit
        jrst 04,0
.bss
"""
if kind in ("dsk", "drm"):
    check += """kinit_stack_base: .block 1
compressed_words: .block 1
member_count: .block 1
entry_addr: .block 1
"""
elif kind == "ptr":
    check += "image_words: .block 1\ncompressed_words: .block 1\n"
check += ".globl __test_exit\n__test_exit: .block 1\n"
pathlib.Path(destination).write_text(setup + handoff + check)

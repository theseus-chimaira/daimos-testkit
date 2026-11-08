#!/usr/bin/env python3
"""Convert v1359 current host golden prefix to a native resumable test."""
import pathlib
import sys


def values(data):
    return [int(row.split()[-1], 8) for row in data.splitlines()
            if row.strip().startswith(".word")]


if len(sys.argv) != 3:
    raise SystemExit("usage: generate_dxr_v1361.py v1359_fixture output_file")
original = pathlib.Path(sys.argv[1]).read_text()
source = values(original.split("source:\n", 1)[1].split("golden:\n", 1)[0])
golden = values(original.split("golden:\n", 1)[1].split(".bss", 1)[0])
assert len(source) == 128 and len(golden) > 1
code = """/* Current-build KCORE host-golden compressed stream; native word refill. */
.text
.globl main
.globl d6codec_stream_v1361
main:
 movei 1,state
 setzm 0(1)
 movei 0,decoded
 movem 0,1(1)
 movem 0,3(1)
 addi 0,0200
 movem 0,2(1)
 movei 0,0%o
 movem 0,4(1)
 movei 2,compressed
refill:
 movei 3,1
 pushj 17,d6codec_stream_v1361
 skipn 4(1)
 jrst complete
 caie 0,1
 jrst fail
 jrst refill
complete:
 jumpn 0,fail
 movei 5,0
compare:
 move 6,source(5)
 came 6,decoded(5)
 jrst fail
 aoj 5,
 caige 5,0200
 jrst compare
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
source:
""" % len(golden)
code += "".join(" .word 0%o\n" % word for word in source)
code += "compressed:\n"
code += "".join(" .word 0%o\n" % word for word in golden)
code += ".bss\nstate: .block 032\ndecoded: .block 0200\n"
code += ".globl __test_exit\n__test_exit: .block 1\n"
pathlib.Path(sys.argv[2]).write_text(code)

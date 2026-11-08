#!/usr/bin/env python3
"""Extract actual generated Stage-1 pre-write guards for PDP-6 tests."""
import pathlib
import sys

if len(sys.argv) != 6:
    raise SystemExit("usage: generate-guard-v1364.py STAGED_SOURCE KIND CORE_OCTAL STACK_OCTAL OUT")
source, kind, core_text, reserve_text, target = sys.argv[1:]
core = int(core_text, 8)
reserve = int(reserve_text, 8)
assert kind in ("dsk", "drm", "dtc", "mtc", "ptr")
assert 0o30000 + reserve + 1 <= core <= 0o1000000
data = pathlib.Path(source).read_text()

if kind in ("dsk", "drm"):
    start, end = "        move 01,03\n", "        jumpn 011,stage1_compressed_stream\n"
elif kind == "dtc":
    start, end = "        move 010,04\n", "        ; Zero compressed length selects"
elif kind == "mtc":
    start, end = "        move 010,04\n", "        movei 01,030000\n"
else:
    start, end = "        move 010,02\n", "        movei 01,030000\n"
assert data.count(start) == 1, (kind, start, data.count(start))
left = data.index(start)
right = data.index(end, left)
guard = data[left:right]
assert guard.count("pushj 017,d6stage_geometry_v1364") == 1
assert guard.index("pushj 017,d6stage_geometry_v1364") < len(guard)
if kind == "ptr":
    assert "camle 02,compressed_words" in guard

code = """/* v1364 extracted production-shaped pre-write header checks. */
.text
.globl main
.globl d6stage_geometry_v1364
main:
"""
cases = [(1, 2, 4, 0),
         (core - 0o30000 - reserve, 0, 4, 0),
         (core - 0o30000 - reserve + 1, 2, 4, 1),
         (1, core - 0o30000, 4, 1)]
if kind == "ptr":
    cases[1] = (1, 2, 4, 0)
    cases.append((1, 2, 6, 1))

for n, (decoded, packed, first_tape, error) in enumerate(cases, start=1):
    code += "case_%d:\n" % n
    if kind in ("dsk", "drm"):
        code += "        move 03,[0%o]\n        move 011,[0%o]\n" % (decoded, packed)
    elif kind in ("dtc", "mtc"):
        code += "        move 013,[0%o]\n        move 04,[0%o]\n" % (decoded, packed)
    else:
        code += ("        move 0,[0%o]\n        movem 0,image_words\n"
                 "        move 07,[0%o]\n        movem 07,compressed_words\n"
                 "        move 02,[0%o]\n") % (decoded, packed, first_tape)
    code += "        pushj 17,guard_check\n"
    if error:
        code += "        camn 0,[-1]\n        jrst case_%d_ok\n" % n
    else:
        code += "        jumpe 0,case_%d_ok\n" % n
    code += "        jrst fail_%d\ncase_%d_ok:\n" % (n, n)
code += "        setz 1,\n        popj 17,\n"
for n in range(1, len(cases) + 1):
    code += "fail_%d:\n        movei 1,0%o\n        popj 17,\n" % (n, n)

code += "guard_check:\n" + guard
code += "        setz 0,\n        popj 17,\n"
code += "fail_khead:\n" if kind in ("dsk", "drm") else "bad_tape:\n"
code += "        seto 0,\n        popj 17,\n"
if kind == "ptr":
    code += ".bss\nimage_words: .block 1\ncompressed_words: .block 1\n"
code += ".bss\n.globl __test_exit\n__test_exit: .block 1\n"
pathlib.Path(target).write_text(code)

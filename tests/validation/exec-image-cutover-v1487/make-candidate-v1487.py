#!/usr/bin/env python3
"""Generate a disposable shared-DXR EXEC candidate retaining current XIP.

v1388 predates the privileged MEMFS-only raw-XIP entry. Its header
replacement discards that path, so the old candidate cannot be linked
into current KCORE. Keep the original root-only XIP path byte-for-byte
and route only DXR1/DXR2 through the common inspector/reader.
"""
from pathlib import Path
import sys

if len(sys.argv) != 4:
    raise SystemExit(
        "usage: make-candidate-v1487.py exec_load.s old-candidate.s output.s")
original = Path(sys.argv[1]).read_text()
candidate = Path(sys.argv[2]).read_text()

start_label = "exec_load_xip_header_v1469:\n"
end_label = "exec_load_create_vm:\n"
if original.count(start_label) != 1 or original.count(end_label) != 1:
    raise SystemExit("v1487: current production XIP path moved")
xip = original.split(start_label, 1)[1].split(end_label, 1)[0]
if (xip.count("fs_provider_reg_call") != 1 or
        xip.count("proc_swap_attach") != 1 or
        "movei   6,030" not in xip or
        "file_check_root" not in xip or
        "movem   1,1(10)" not in xip or
        "exec_load_vm_fail" not in xip):
    raise SystemExit("v1487: XIP provider, ownership or rollback changed")

header = "exec_load_read_header:\n"
if candidate.count(header) != 1:
    raise SystemExit("v1487: candidate header moved")
# Do not insert a second read on the ordinary DXR fast path. A rejected
# DXR header may instead be an XIP header; only that error branch
# performs the extra two-word probe before strict provider admission.
inspected = (
    "        pushj   17,exec_image_inspect_v1386\n"
    "        jumpn   1,exec_load_fail\n"
)
if candidate.count(inspected) != 1:
    raise SystemExit("v1487: DXR inspection error branch changed")
candidate = candidate.replace(
    inspected,
    inspected.replace("exec_load_fail", "exec_load_check_xip_v1487"), 1)
guard = (
    "exec_load_check_xip_v1487:\n"
    "        move    1,12\n"
    "        setz    2,\n"
    "        movei   3,-002(17)             ; original two-word header scratch\n"
    "        movei   4,2\n"
    "        pushj   17,vfs_read_words\n"
    "        caie    1,2\n"
    "        jrst    exec_load_fail\n"
    "        hlrz    0,-002(17)\n"
    "        jrst    exec_load_xip_header_v1469\n"
)

before = candidate.index(end_label)
rt_tail = (
    "exec_load_rt_claim:\n"
    "        movem   11,proc_rt_owner\n"
    "        setom   -012(17)\n"
)
if candidate.count(rt_tail) != 1:
    raise SystemExit("v1487: RT reservation control flow changed")
candidate = candidate.replace(
    rt_tail, rt_tail + "        jrst    exec_load_create_vm\n", 1)
before = candidate.index(end_label)
candidate = (
    candidate[:before] + guard + start_label + xip + candidate[before:])
marker = "        .globl  proc_rt_owner\n"
if candidate.count(marker) != 1:
    raise SystemExit("v1487: external symbol table changed")
candidate = candidate.replace(
    marker,
    marker +
    "        .globl  exec_image_inspect_v1386\n"
    "        .globl  exec_image_apply_v1386\n", 1)
assert candidate.count(start_label) == 1
assert candidate.count("exec_image_inspect_v1386") == 2
assert candidate.count("exec_image_apply_v1386") == 2

out = Path(sys.argv[3])
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(candidate)
print("v1487: DXR shared-loader candidate retains original strict XIP path")

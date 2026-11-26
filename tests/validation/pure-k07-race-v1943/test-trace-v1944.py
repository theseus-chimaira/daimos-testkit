#!/usr/bin/env python3
"""Negative controls derived from an actual accepted physical race trace."""
import argparse
from pathlib import Path
import re
import runpy
import shutil
import tempfile

here = Path(__file__).resolve().parent
v = runpy.run_path(str(here / "verify-v1943.py"))
p = argparse.ArgumentParser()
for name in ("build", "work"):
    p.add_argument(name, type=Path)
a = p.parse_args()
s = v["symbols"](a.build / "kcore.map")
trace = (a.work / "physical.clean").read_text(encoding="ascii")
v["verify"](a.build, a.work)


def sample(label):
    first = "V1943_STAGE_" + label + "\n"
    last = "V1943_END_" + label + "\n"
    assert trace.count(first) == trace.count(last) == 1
    head, rest = trace.split(first, 1)
    body, foot = rest.split(last, 1)
    return head + first, body, last + foot, v["words"](body)


def change(label, addr, replacement):
    head, body, foot, original = sample(label)
    old = original[addr]
    assert old != replacement
    matches = 0

    def replace(m):
        nonlocal matches
        if int(m[1], 8) == addr and int(m[2], 8) == old:
            matches += 1
            return "%o:\t%012o" % (addr, replacement)
        return m[0]

    altered = re.sub(r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})$",
                     replace, body)
    assert matches == 1
    return head + altered + foot


D = sample("D")[3]
Q = sample("Q")[3]
R = sample("R")[3]
E = sample("E")[3]
V = sample("V")[3]
Z = sample("Z")[3]
head = D[s["proc_exec_resv_head_v1933"]]
media_q = Q[s["dtfs_media_base"]] + 1
media_r = R[s["dtfs_media_base"]] + 1
root_r = R[s["vfs_mount_root_base"]] + 1
cases = {
    "missing-reservation": change("D", s["proc_exec_resv_head_v1933"], 0),
    "foreign-reservation-vnode": change("D", head+1, D[head+1] ^ (1<<24)),
    "held-provider-lease": change("D", s["fs_provider_ready"], 2<<18),
    "missing-quiescence": change("Q", media_q, Q[media_q] & ~0o20000),
    "early-quiescence-release": change("R", media_r, R[media_r] & ~0o20000),
    "early-retirement": change("R", root_r, 0),
    "missing-pi6-progress": change("D", s["clk_tick_count"], E[s["clk_tick_count"]]),
    "retirement-barrier-leak": change("V", V[s["dtfs_media_base"]]+1,
                                      V[V[s["dtfs_media_base"]]+1]|0o20000),
    "leaked-reservation": change("Z", s["proc_exec_resv_head_v1933"], head),
    "wrong-halt": trace.replace("HALT instruction, PC: 000000",
                                "HALT instruction, PC: 000001", 1),
}
for name, modified in cases.items():
    assert modified != trace
    with tempfile.TemporaryDirectory(prefix="race-oracle-v1944-", dir=a.work) as td:
        w = Path(td)
        shutil.copyfile(a.work / "images.sha256", w / "images.sha256")
        (w / "physical.clean").write_text(modified, encoding="ascii")
        try:
            v["verify"](a.build, w)
        except (AssertionError, KeyError, ValueError):
            print("PASS rejected " + name)
        else:
            raise SystemExit("FAIL accepted " + name)
print("PASS v1944: ten altered physical race transcripts rejected")

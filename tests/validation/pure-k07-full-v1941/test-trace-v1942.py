#!/usr/bin/env python3
"""Negative controls derived from the actual accepted physical trace."""
import argparse
from pathlib import Path
import runpy
import shutil
import tempfile

v = runpy.run_path(str(Path(__file__).with_name("verify-v1941.py")))
p = argparse.ArgumentParser()
for name in ("build", "work", "prefix"):
    p.add_argument(name, type=Path)
a = p.parse_args()
s = v["symbols"](a.build / "kcore.map")
trace = (a.work / "physical.clean").read_text(encoding="ascii")
v["verify"](a.build, a.work, a.prefix, 5)


def change_word(label, addr, old, new):
    block = v["section"](trace, label)
    import re
    pattern = r"(?m)^([0-7]+):\s*([0-7]{12})$"
    count = 0
    def replace(m):
        nonlocal count
        if int(m[1], 8) == addr and int(m[2], 8) == old:
            count += 1
            return "%o:\t%012o" % (addr, new)
        return m[0]
    changed = re.sub(pattern, replace, block)
    assert count == 1
    return trace.replace(block, changed, 1)


def owner_word(label, kind, owner):
    d = v["words"](v["section"](trace, label))
    found = []
    for i in range(d[s["mm_extent_count"]]):
        addr = s["mm_extents"] + 2*i + 1
        meta = d[addr]
        if (meta >> 18) & 7 == kind and meta & 0o777777 == owner:
            found.append((addr, meta))
    assert len(found) == 1
    return found[0]

src, sm = owner_word("FULL", 4, 3)
dst, dm = owner_word("FULL", 1, 3)
ua, um = owner_word("FULL", 3, 0o1003)
z, zm = owner_word("Z", 1, 1)
case = {
    "source-unpinned": change_word("FULL", src, sm, sm & ~(255 << 21)),
    "target-unpinned": change_word("FULL", dst, dm, dm & ~(255 << 21)),
    "foreign-target": change_word("FULL", dst, dm, (dm & ~0o777777) | 4),
    "foreign-uarea": change_word("FULL", ua, um, (um & ~0o777777) | 0o1004),
    "reservation-leak": change_word("Z", s["proc_exec_resv_head_v1933"], 0, 1),
    "child-owner-leak": change_word("Z", z, zm, (zm & ~0o777777) | 3),
    "wrong-entry": trace.replace("Breakpoint, PC: 040756", "Breakpoint, PC: 040757", 1),
    "missing-wait-marker": trace.replace("wwwwZV1941_STAGE_Z", "wwwZV1941_STAGE_Z", 1),
    "wrong-halt": trace.replace("HALT instruction, PC: 000000", "HALT instruction, PC: 000001", 1),
}
for name, altered in case.items():
    assert altered != trace, name
    with tempfile.TemporaryDirectory(prefix="pure-full-negative-v1942-", dir=a.work) as tmp:
        path = Path(tmp)
        shutil.copyfile(a.work / "images.sha256", path / "images.sha256")
        (path / "physical.clean").write_text(altered, encoding="ascii")
        try:
            v["verify"](a.build, path, a.prefix, 5)
        except (AssertionError, KeyError, ValueError):
            print("PASS rejected " + name)
        else:
            raise SystemExit("FAIL accepted " + name)
print("PASS v1942: nine altered physical transcripts rejected")

#!/usr/bin/env python3
"""Same-revision isolated TEXT accounting for a staged shared DXR loader."""
from pathlib import Path
import re
import subprocess
import sys

if len(sys.argv) != 6:
    raise SystemExit("usage: ... objdump old.dobj candidate.dobj shared.dobj report")
objdump, old, candidate, shared, report = sys.argv[1:]


def text_words(path: str) -> int:
    sections = subprocess.check_output(
        [objdump, "-h", path], text=True)
    match = re.search(r"^sections: text=(\d+) data=(\d+) bss=(\d+)",
                      sections, re.M)
    if not match:
        raise SystemExit("v1487: missing object section accounting")
    words, data, bss = map(int, match.groups())
    if data or bss or not words:
        raise SystemExit("v1487: unexpected static RAM in isolated loader")
    return words


o = text_words(old)
c = text_words(candidate)
s = text_words(shared)
delta = c + s - o
lines = [
    "v1487 same-revision native PDP-6 TEXT comparison",
    f"Original production EXEC: {o} words",
    f"XIP-preserving shared EXEC caller: {c} words",
    f"Shared DXR parser/loader/adapter: {s} words",
    f"Candidate combined isolated difference: {delta:+d} words",
    "Status: staging only; no production KCORE linkage or RAM gain claimed",
]
Path(report).write_text("\n".join(lines) + "\n")

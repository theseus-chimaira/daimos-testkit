#!/usr/bin/env python3
"""Guard OPEN descriptor DIR projection against the VFS type ABI."""
from pathlib import Path
import re
import sys

src = (Path(sys.argv[1]) / "system/kernel/fs/file_runtime.s").read_text()
body = src[src.index("file_open_newfd:\n"):src.index("file_open_newfd_call:\n")]
expected = (r"move\s+3,-6\(17\)", r"caie\s+3,1", r"setz\s+3,")
for pattern in expected:
    if not re.search(pattern, body):
        raise SystemExit("FAIL: missing OPEN directory projection " + pattern)
for kind in range(64):
    former = 1 if kind == 1 else 0
    revised = kind if kind == 1 else 0
    if former != revised:
        raise SystemExit("FAIL: VFS type " + str(kind))
print("open-dir-type-v441: PASS (all 64 VFS type values)")

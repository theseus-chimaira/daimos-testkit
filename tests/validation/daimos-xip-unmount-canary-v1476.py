#!/usr/bin/env python3
"""Verify the test-only MRES canary immediately follows MEMFS's 3 words."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: daimos-xip-unmount-canary-v1476.py memfs-mres.map")
names = ("memfs_mres_fs", "daimos_test_unmount_preflight_v1475")
symbols = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    fields = line.split()
    if len(fields) >= 2 and fields[0] in names:
        if fields[0] in symbols:
            raise SystemExit("v1476: duplicate MRES symbol")
        symbols[fields[0]] = int(fields[1], 8)
if len(symbols) != 2 or symbols[names[1]] != symbols[names[0]] + 3:
    raise SystemExit("v1476: MRES canary must follow three-word memfs_mres_fs")
print("v1476: MEMFS MRES BSS canary follows exactly three state words")

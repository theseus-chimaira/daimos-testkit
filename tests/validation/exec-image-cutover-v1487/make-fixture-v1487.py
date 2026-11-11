#!/usr/bin/env python3
"""Adapt the historical DXR mock to count fallback header probes.

An invalid DXR header receives a second read only to distinguish a
MEMFS-only raw XIP header; valid DXR loads still read the header once.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: ... historical-test.c current-test.c")
data = Path(sys.argv[1]).read_text()
old = "header_v1388 != 1U)"
new = "header_v1388 != (fault == 1 ? 2U : 1U))"
if data.count(old) != 1:
    raise SystemExit("v1487: fixture header-counter check changed")
Path(sys.argv[2]).write_text(data.replace(old, new, 1))

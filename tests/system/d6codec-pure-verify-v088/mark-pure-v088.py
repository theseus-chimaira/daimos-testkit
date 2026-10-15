#!/usr/bin/env python3
"""Set PURE on a test DXR copy; never modify the production build artifact."""
from pathlib import Path
import sys
src, dst = map(Path, sys.argv[1:])
data = bytearray(src.read_bytes())
if len(data) < 24 or len(data) % 8:
    raise SystemExit("not a 36-bit DXR container")
word0 = int.from_bytes(data[0:8], "little")
word1 = int.from_bytes(data[8:16], "little")
word2 = int.from_bytes(data[16:24], "little")
if word0 >> 18 != 0o447062 or not word1 & 0o100000 or word2 & 0o777777 != 0o647022:
    raise SystemExit("not compressed DXR2")
word1 |= 0o200000
# The BSS bits and all image/relocation bytes remain unchanged.
data[8:16] = word1.to_bytes(8, "little")
dst.write_bytes(data)

#!/usr/bin/env python3
"""Reject uncompressed/misframed DXRs in the compressed EXEC integration suite."""
import pathlib
import sys

data = pathlib.Path(sys.argv[1]).read_bytes()
assert len(data) % 8 == 0 and len(data) >= 4 * 8
words = [int.from_bytes(data[i:i+8], 'little') for i in range(0, len(data), 8)]
assert words[0] >> 18 == 0o447062, 'bad DXR magic'
assert words[1] & 0o100000, 'executable is not compressed'
assert words[2] & 0o777777 == 0o647022, 'DXR2 TX2 header required'
image = words[1] >> 18
assert image > 0 and (words[2] >> 18) <= image
reloc = (image + 35) // 36
assert len(words) > 3 + reloc, 'no payload'

if pathlib.Path(sys.argv[1]).name == "ls-pure-v088.dxr":
    assert words[1] & 0o200000, "test executable missing PURE"

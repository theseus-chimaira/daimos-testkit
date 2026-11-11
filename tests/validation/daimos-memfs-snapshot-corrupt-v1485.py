#!/usr/bin/env python3
"""Corrupt only one MEMFS metadata word in a committed AUXSTORE snapshot.

The host test starts from a *separate*, successfully published snapshot,
preserves the six-word commit header, and flips an otherwise unused
metadata-area bit. The guest must detect the checksum mismatch. The
bitmap/backing map and AUXSTORE partition descriptor are not modified.
"""
from pathlib import Path
import re
import struct
import sys

BLOCK_BYTES = 128 * 8
SNAP_MAGIC = 0o55464663
SNAP_VERSION = 2
METADATA_WORD = 50

if len(sys.argv) != 3:
    raise SystemExit("usage: ... AUXSTORE-INSPECT-OUTPUT DR0-IMAGE")
inspect = Path(sys.argv[1]).read_text()
match = re.search(r"^BACKSTORE ([0-7]+)\+([0-7]+)$", inspect, re.M)
if match is None:
    raise SystemExit("v1485: missing AUXSTORE backing partition")
region_first, region_blocks = (int(v, 8) for v in match.groups())
if region_blocks < 8:
    raise SystemExit("v1485: BACKSTORE too small")
image = Path(sys.argv[2])
with image.open("r+b") as f:
    header_offset = (region_first + region_blocks - 1) * BLOCK_BYTES
    f.seek(header_offset)
    raw = f.read(6 * 8)
    if len(raw) != 6 * 8:
        raise SystemExit("v1485: missing committed snapshot header")
    header = struct.unpack("<6Q", raw)
    if header[0] != SNAP_MAGIC or header[1] != SNAP_VERSION:
        raise SystemExit("v1485: source image was not committed")
    first, blocks = header[2:4]
    if (first >= region_blocks or blocks < 6 or
            blocks > region_blocks - first or
            first + blocks != region_blocks):
        raise SystemExit("v1485: invalid snapshot reservation")
    offset = (region_first + first) * BLOCK_BYTES + METADATA_WORD * 8
    f.seek(offset)
    word = f.read(8)
    if len(word) != 8:
        raise SystemExit("v1485: missing snapshot metadata")
    current = struct.unpack("<Q", word)[0]
    if current >> 36:
        raise SystemExit("v1485: invalid 36-bit metadata")
    f.seek(offset)
    f.write(struct.pack("<Q", current ^ 1))
    f.flush()
    f.seek(header_offset)
    if f.read(len(raw)) != raw:
        raise SystemExit("v1485: committed header modified unexpectedly")
print("v1485: changed one metadata bit; original commit header retained")

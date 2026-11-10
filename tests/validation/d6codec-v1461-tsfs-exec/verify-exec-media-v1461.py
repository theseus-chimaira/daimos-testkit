#!/usr/bin/env python3
"""Reconstruct LOGIN, DSH and ECHO directly from real TSFS extents."""
import argparse
import importlib.util
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py"
SPEC = importlib.util.spec_from_file_location("block_v1421", SOURCE)
BLOCK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BLOCK)
MASK = (1 << 18) - 1


def media_words(path):
    data = path.read_bytes()
    half = struct.unpack("<%dI" % (len(data) // 4), data)
    return [(hi << 18) | lo for hi, lo in zip(half[::2], half[1::2])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--media", required=True, type=Path)
    ap.add_argument("--manifest", required=True, type=Path)
    args = ap.parse_args()
    words = media_words(args.media)
    desc = words[128:256]
    table_block = desc[8] & MASK
    directory = words[table_block * 128:(table_block + 1) * 128]
    file_block = directory[8] & MASK
    extent_block = directory[13] & MASK
    file_records = words[file_block * 128:]
    extent_records = words[extent_block * 128:]
    manifest = {}
    for line in args.manifest.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[0] == "F":
            manifest[fields[1].split("/")[-1]] = Path(fields[2])
    found = set()
    for index in range(directory[3]):
        record = file_records[index * 8:index * 8 + 8]
        if (record[0] & 3) != 2:
            continue
        chars = "".join(chr(((word >> shift) & 63) + 32)
                        for word in record[1:5]
                        for shift in (30, 24, 18, 12, 6, 0))
        name = chars.rstrip()
        if name not in ("LOGIN", "DSH", "ECHO"):
            continue
        size = record[5]
        first, count = record[6] >> 18, record[6] & MASK
        decoded = []
        for i in range(count):
            extent = extent_records[(first + i) * 4:(first + i) * 4 + 4]
            block = extent[1] & MASK
            shape = extent[2]
            physical = words[block * 128:(block + (shape & MASK)) * 128]
            logical = min(256, size - len(decoded))
            if (shape >> 18) == 1:
                if physical[0] != logical:
                    raise ValueError("restart length mismatch: " + name)
                decoded.extend(BLOCK.decode(physical[2:2 + physical[1]],
                                            logical))
            elif (shape >> 18) == 0:
                decoded.extend(physical[:logical])
            else:
                raise ValueError("unknown extent type")
        expected_data = manifest[name].read_bytes()
        expected = struct.unpack("<%dQ" % (len(expected_data) // 8),
                                 expected_data)
        if tuple(decoded) != expected:
            raise ValueError("TSFS content mismatch: " + name)
        print("V1461_TSFS_EXEC_MEDIA_PASS", name, size, "words",
              count, "extents", flush=True)
        found.add(name)
    if found != {"LOGIN", "DSH", "ECHO"}:
        raise ValueError("missing executable records: " + repr(found))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Check exact identity of linked KCORE low core and all Stage-1 images.

The fixed image is one 53-word physical 36-bit sequence in each read-in.
This catches drift in in-image byte pointers or relocation semantics.
"""
import argparse
from pathlib import Path
import struct


def words(path):
    data = path.read_bytes()
    if len(data) % 8:
        raise ValueError("invalid 36-bit word storage")
    return struct.unpack("<%dQ" % (len(data) // 8), data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--kcore", required=True, type=Path)
    parser.add_argument("--stage1-dir", required=True, type=Path)
    args = parser.parse_args()
    kcore = words(args.kcore)
    if kcore[0] >> 18 != 0o447062:
        raise ValueError("KCORE DXR magic mismatch")
    image = kcore[3:3 + 53]
    if len(image) != 53:
        raise ValueError("truncated fixed KCORE decoder")
    for device in ("dsk", "drm", "dtc", "mtc", "ptr"):
        path = (args.stage1_dir / device /
                (device + "-stage1-v1458.raw"))
        stage = words(path)
        matches = [i for i in range(len(stage) - len(image) + 1)
                   if stage[i:i + len(image)] == image]
        if len(matches) != 1:
            raise ValueError("Stage-1 decoder image mismatch: " +
                             device + " " + str(matches))
        print("V1459_SHARED_CORE_PASS", device, "offset", matches[0],
              "words", len(image), flush=True)
    print("PASS byte-exact 53-word KCORE/Stage-1 decoder identity")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Read TSFS V1.1 FILE/EXTENT metadata from an on-disk DECtape image.

For diagnosis only; tsfscheck remains the authoritative full verifier.
This prints each regular file's first extent/count and compressed/stored
extent flags, including transitions between 32-record extent-table blocks.
"""
import argparse
from pathlib import Path
import struct

MASK = (1 << 18) - 1
WORDS_PER_BLOCK = 128


def media_words(path):
    raw = path.read_bytes()
    if len(raw) % 8:
        raise ValueError("unaligned media")
    halfs = struct.unpack("<%dI" % (len(raw) // 4), raw)
    return [(a << 18) | b for a, b in zip(halfs[::2], halfs[1::2])]


def name_from_record(rec):
    chars = []
    for word in rec[1:5]:
        for shift in (30, 24, 18, 12, 6, 0):
            chars.append(chr(((word >> shift) & 63) + 32))
    return "".join(chars).rstrip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    args = parser.parse_args()
    words = media_words(args.image)
    desc = words[WORDS_PER_BLOCK:2 * WORDS_PER_BLOCK]
    tdir_member = desc[8] >> 18
    tdir_block = desc[8] & MASK
    if tdir_member != 0:
        raise ValueError("one-member diagnostic only")
    tdir = words[tdir_block * WORDS_PER_BLOCK:
                 (tdir_block + 1) * WORDS_PER_BLOCK]
    file_start = tdir[8] & MASK
    file_blocks = tdir[9] >> 18
    extent_start = tdir[13] & MASK
    extent_blocks = tdir[14] >> 18
    count = tdir[3]
    extcount = tdir[4]
    files = words[file_start * WORDS_PER_BLOCK:
                  (file_start + file_blocks) * WORDS_PER_BLOCK]
    extents = words[extent_start * WORDS_PER_BLOCK:
                    (extent_start + extent_blocks) * WORDS_PER_BLOCK]
    print("TSFS_LAYOUT", "files", count, "extents", extcount,
          "extent_block", extent_start, "extent_table_blocks", extent_blocks)
    for index in range(count):
        rec = files[8 * index:8 * (index + 1)]
        if len(rec) != 8 or rec[0] & 3 != 2:
            continue
        start = rec[6] >> 18
        n = rec[6] & MASK
        flags = []
        for i in range(start, start + n):
            if i >= extcount:
                raise ValueError("invalid extent count")
            flags.append(str(extents[i * 4 + 2] >> 18))
        crossings = [i for i in range(start + 1, start + n) if i % 32 == 0]
        print("FILE", index, name_from_record(rec), "words", rec[5],
              "first", start, "count", n, "flags", ",".join(flags),
              "table_block_crossings", crossings)


if __name__ == "__main__":
    main()

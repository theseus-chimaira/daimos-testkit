#!/usr/bin/env python3
"""Construct a packed ASCII7 fixture exercising stable DOBJ globals."""

from pathlib import Path
import struct
import sys


SOURCE = (
    ".text\n"
    ".globl main,ext_symbol\n"
    ".globl main\n"
    ".extern ext_symbol\n"
    ".entry main\n"
    ".comm common_symbol,2\n"
    "main:\n"
    " movei 1,7\n"
    " popj 17,\n"
)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: make_fixture_v1405.py OUTPUT.A7")
    data = SOURCE.encode("ascii")
    words = []
    for pos in range(0, len(data), 5):
        word = 0
        for index, ch in enumerate(data[pos:pos + 5]):
            word |= ch << (29 - 7 * index)
        words.append(word)
    Path(sys.argv[1]).write_bytes(
        struct.pack("<" + "Q" * len(words), *words))
    print("V1405_METADATA_FIXTURE_PASS bytes=%d words=%d" %
          (len(data), len(words)))


if __name__ == "__main__":
    main()

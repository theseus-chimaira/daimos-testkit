#!/usr/bin/env python3
"""Prove actual PDP-6 DECtape RBN0145 was only partly overwritten.

Input 36-bit words are stored as two little-endian 18-bit words.
The seed and attempted replacement are independent of on-media
metadata, so an old DTVOL1 stamp cannot accidentally satisfy the test.
"""

import struct
import sys
from pathlib import Path

BLOCK = 0o145
WORDS = 128
OLD = 0o10000000
NEW = 0o20000000
MASK18 = 0o777777


def block(path):
    with Path(path).open("rb") as stream:
        stream.seek(BLOCK * WORDS * 8)
        data = stream.read(WORDS * 8)
    assert len(data) == WORDS * 8, "incomplete native DTC image"
    result = []
    for pos in range(0, len(data), 8):
        high, low = struct.unpack_from("<II", data, pos)
        assert (high | low) & ~MASK18 == 0, "invalid 18-bit lane"
        result.append((high << 18) | low)
    return result


def main():
    assert len(sys.argv) == 4, "usage: mode before after"
    mode, before_path, after_path = sys.argv[1:]
    before = block(before_path)
    for i in range(1, 3):
        assert before[i] == OLD + i - 1, (
            "seed data mismatch in physical block", i, oct(before[i]))
    if mode == "seed":
        print("PASS v1529: two seeded words on real DTC3 RBN0145")
        return
    assert mode == "partial"
    after = block(after_path)
    assert before[0] == after[0], "native data header overwritten"
    changed = []
    for i in range(1, WORDS):
        if before[i] != after[i]:
            assert i in (1, 2), (
                "unrelated physical data word changed", i)
            assert after[i] == NEW + i - 1, (
                "unexpected/corrupt data word", i, oct(after[i]))
            changed.append(i)
    assert len(changed) == 1, (
        "not exactly one changed data word", len(changed))
    assert changed[0] in (1, 2)
    assert after != before, "no physical partial write occurred"
    assert after[3 - changed[0]] == before[3 - changed[0]], (
        "second data word was not left old")
    print(
        "PASS v1529: physical RBN0145 changed only data slot %d; "
        "the other requested new word remains old" % changed[0]
    )


if __name__ == "__main__":
    main()

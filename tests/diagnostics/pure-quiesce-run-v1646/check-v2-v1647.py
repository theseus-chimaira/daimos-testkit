#!/usr/bin/env python3
"""Check a real DECtape image's native DTVOL2/CLEAN RBN0.

The default mkdtfs image is DTVOL1. It does not acquire the v1562
quiescence barrier; using it makes the v1646 race test invalid.
Read the actual on-media 18-bit halves, not a filename or mount label.
"""

from pathlib import Path
import sys

WORD_MASK = 0o777777777777
V2_MAGIC = 0o446466575422
V2_SALT = 0o246134572610


def check(path):
    block = Path(path).read_bytes()[:128 * 8]
    assert len(block) == 128 * 8, "short native RBN0"
    words = []
    for pos in range(0, len(block), 8):
        left = int.from_bytes(block[pos:pos + 4], "little") & 0o777777
        right = int.from_bytes(block[pos + 4:pos + 8], "little") & 0o777777
        words.append((left << 18) | right)
    assert words[0] == V2_MAGIC, "DTC3 is not native DTVOL2"
    assert words[1] != 0 and words[2] != 0, "missing physical volume ID"
    assert words[3] == (~(words[0] ^ words[1] ^ words[2])) & WORD_MASK, \
        "volume identity checksum mismatch"
    assert words[4] == 0, "DTVOL2 is not CLEAN"
    assert words[5] == (~(words[0] ^ words[1] ^ words[2] ^ V2_SALT)) & \
        WORD_MASK, "DTVOL2 seal checksum mismatch"
    assert all(word == 0 for word in words[6:]), \
        "unexpected physical RBN0 payload"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: check-v2-v1647.py dtc3-image")
    try:
        check(sys.argv[1])
    except AssertionError as exc:
        raise SystemExit("FAIL v1647 DTVOL2 media: " + str(exc))
    print("PASS v1647: physical DTC3 RBN0 is sealed DTVOL2/CLEAN")

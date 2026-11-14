#!/usr/bin/env python3
"""Versioned DTVOL2 physical crash-image generator (host-side only).

The guest reads the resulting bytes through its real Type-551 controller.
This script models a torn physical write by modifying the *host image*;
it does not claim to have interrupted a real Type-136 transfer in flight.
Only the disposable secondary DTC3 image is ever changed.
"""

import hashlib
from pathlib import Path
import struct
import sys

MASK = 0o777777777777
HALF = 0o777777
MAGIC = 0o446466575422
DIRTY = 0o552255225522
SALT = 0o246134572610
BLOCK = 128 * 8


def get_word(data, index):
    high, low = struct.unpack_from("<II", data, index * 8)
    assert high <= HALF and low <= HALF
    return (high << 18) | low


def put_word(data, index, value):
    assert 0 <= value <= MASK
    struct.pack_into("<II", data, index * 8,
                     (value >> 18) & HALF, value & HALF)


def seal(words):
    return (~(words[0] ^ words[1] ^ words[2] ^ words[4] ^ SALT)) & MASK


def prepare(image, mode):
    before = bytearray(Path(image).read_bytes())
    assert len(before) == 0o1102 * BLOCK
    assert len(before) % BLOCK == 0
    data = bytearray(before)
    words = [get_word(data, i) for i in range(128)]
    assert words[0] == MAGIC
    assert words[1] and words[2]
    assert words[3] == (~(words[0] ^ words[1] ^ words[2])) & MASK
    assert words[4] == 0 and words[5] == seal(words)
    assert not any(words[6:])

    if mode in ("dirty-data-prefix", "dirty-dir-prefix",
                "torn-clean-state", "torn-clean-seal",
                "torn-clean-half"):
        words[4] = DIRTY
        words[5] = seal(words)
        put_word(data, 4, words[4])
        put_word(data, 5, words[5])

    if mode == "torn-dirty-state":
        put_word(data, 4, DIRTY)  # physical state changed, seal not yet
    elif mode == "torn-dirty-seal":
        future = words[:]
        future[4] = DIRTY
        put_word(data, 5, seal(future))  # seal changed, state not yet
    elif mode == "torn-clean-state":
        put_word(data, 4, 0)  # physical CLEAN state, old DIRTY seal
    elif mode == "torn-clean-seal":
        future = words[:]
        future[4] = 0
        put_word(data, 5, seal(future))  # CLEAN seal, still DIRTY state
    elif mode == "torn-clean-half":
        # Only half of the 36-bit CLEAN state word reached the tape.
        put_word(data, 4, words[4] & HALF)
    elif mode == "torn-identity":
        put_word(data, 2, words[2] ^ 0o1)
    elif mode == "torn-magic":
        put_word(data, 0, words[0] ^ 0o100)
    elif mode == "torn-padding":
        put_word(data, 0o177, 0o1)
    elif mode == "dirty-data-prefix":
        # Non-reserved physical DATA block is corrupted after DIRTY arm.
        idx = 0o200 * 128 + 3
        put_word(data, idx, get_word(data, idx) ^ 0o12345)
    elif mode == "dirty-dir-prefix":
        # A partial directory transaction after a verified DIRTY arm.
        idx = 0o144 * 128 + 15
        put_word(data, idx, get_word(data, idx) ^ 0o777)
    elif mode == "clean-data-corrupt-control":
        # Safety NEGATIVE CONTROL: syntactically CLEAN RBN0 offers no
        # independent DATA checksum. A physically corrupted data block
        # is not detectable by the RBN0-only admission protocol.
        idx = 0o200 * 128 + 3
        put_word(data, idx, get_word(data, idx) ^ 0o12345)
    else:
        raise ValueError("unknown physical fault mode: " + mode)

    changed = [i for i, (left, right) in enumerate(zip(before, data))
               if left != right]
    assert changed, mode
    assert len(before) == len(data)
    assert get_word(data, 1) == words[1], "high identity must not change"
    if mode != "torn-identity":
        assert get_word(data, 2) == words[2], "low identity changed"
    if mode not in ("dirty-dir-prefix", "dirty-data-prefix",
                    "clean-data-corrupt-control"):
        assert all(i < BLOCK for i in changed)
    elif mode == "dirty-dir-prefix":
        assert all(i < BLOCK or (0o144 * BLOCK <= i < 0o145 * BLOCK)
                   for i in changed)
    else:
        assert all(i < BLOCK or (0o200 * BLOCK <= i < 0o201 * BLOCK)
                   for i in changed)
    Path(image).write_bytes(data)
    actual = Path(image).read_bytes()
    assert actual == data, "the physical crash image was not written"
    print("v1567 %s: %d bytes modified, full tape SHA256 %s" %
          (mode, len(changed), hashlib.sha256(actual).hexdigest()))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: fault-media-v1567.py TAPE MODE")
    prepare(sys.argv[1], sys.argv[2])

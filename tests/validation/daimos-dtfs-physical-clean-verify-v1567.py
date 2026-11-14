#!/usr/bin/env python3
"""Independent full-tape proof of real Type-551 DIRTY and partial CLEAN.

This is not an offline mutation generator. Both input images originate
from the SIMH Type-551 DTC3 transport after a real controller write and
explicit simulator DETACH (which flushes its live physical buffer).
"""

from pathlib import Path
import hashlib
import struct
import sys

BLOCK = 128 * 8
DIRTY = 0o552255225522
MAGIC = 0o446466575422
SALT = 0o246134572610
MASK = 0o777777777777


def word(data, index):
    hi, lo = struct.unpack_from('<II', data, index * 8)
    assert hi <= 0o777777 and lo <= 0o777777
    return (hi << 18) | lo


def check_media(data):
    assert len(data) == 0o1102 * BLOCK, 'unexpected physical geometry'
    header = [word(data, i) for i in range(128)]
    assert header[0] == MAGIC and header[1] and header[2]
    assert header[3] == (~(header[0] ^ header[1] ^ header[2])) & MASK
    assert not any(header[6:]), 'physical RBN0 padding changed'
    return header


def check(stage, path_before, path_after):
    before = Path(path_before).read_bytes()
    after = Path(path_after).read_bytes()
    a = check_media(before)
    b = check_media(after)
    assert a[:4] == b[:4], 'physical 72-bit volume identity changed'
    diffs = [i for i, (x, y) in enumerate(zip(before, after)) if x != y]
    assert diffs and all(4 * 8 <= i < 6 * 8 for i in diffs), (
        'unexpected changed words outside RBN0 state and checksum', diffs)
    if stage == 'dirty':
        assert a[4] == 0
        assert a[5] == (~(a[0] ^ a[1] ^ a[2] ^ SALT)) & MASK
        assert b[4] == DIRTY
        assert b[5] == (~(b[0] ^ b[1] ^ b[2] ^ DIRTY ^ SALT)) & MASK
        assert all(i in range(4 * 8, 6 * 8) for i in diffs)
    elif stage == 'torn':
        assert a[4] == DIRTY
        assert a[5] == (~(a[0] ^ a[1] ^ a[2] ^ DIRTY ^ SALT)) & MASK
        assert b[4] == 0, 'first changed word did not reach physical tape'
        assert b[5] == a[5], 'partial CLEAN overwrote old DIRTY seal'
        assert all(4 * 8 <= i < 5 * 8 for i in diffs), (
            'more than first CLEAN word physically written', diffs)
        assert b[5] != (~(b[0] ^ b[1] ^ b[2] ^ SALT)) & MASK
    else:
        raise ValueError(stage)
    print('PASS v1567: %s: %d changed persistent image bytes, '
          'old_sha256=%s new_sha256=%s' %
          (stage, len(diffs), hashlib.sha256(before).hexdigest(),
           hashlib.sha256(after).hexdigest()))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: verifier.py dirty|torn BEFORE AFTER')
    check(sys.argv[1], sys.argv[2], sys.argv[3])

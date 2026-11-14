#!/usr/bin/env python3
"""Verify an actual production Type-551 RW then CLEAN DTFS guest run.

Only independent full-image comparisons: no tape modification or
reconstruction of a previously interrupted transfer.
"""
from pathlib import Path
import hashlib
import struct
import sys

BLOCK = 1024
WORDS = 128
MAGIC = 0o446466575422
SALT = 0o246134572610
MASK = 0o777777777777


def word(data, index):
    high, low = struct.unpack_from('<II', data, index * 8)
    assert high <= 0o777777 and low <= 0o777777
    return (high << 18) | low


def header(data):
    assert len(data) == 0o1102 * BLOCK
    values = [word(data, i) for i in range(WORDS)]
    assert values[0] == MAGIC and values[1] and values[2]
    assert values[3] == (~(values[0] ^ values[1] ^ values[2])) & MASK
    assert values[4] == 0, 'volume not physically CLEAN after unmount'
    assert values[5] == (~(values[0] ^ values[1] ^ values[2] ^
                          SALT)) & MASK
    assert not any(values[6:]), 'nonzero physical RBN0 padding'
    return values


def check(before_path, after_path):
    before = Path(before_path).read_bytes()
    after = Path(after_path).read_bytes()
    assert header(before) == header(after), (
        'the original 72-bit ID or full CLEAN seal changed')
    changes = [i for i, pair in enumerate(zip(before, after))
               if pair[0] != pair[1]]
    assert changes, 'the guest did not write physical tape'
    assert any(0o144 * BLOCK <= i < 0o145 * BLOCK for i in changes), (
        'no physical native directory update')
    assert any(0o145 * BLOCK <= i < 0o146 * BLOCK for i in changes), (
        'no physical DATA update')
    assert all(0o144 * BLOCK <= i < 0o146 * BLOCK for i in changes), (
        'metadata or DATA wrote outside exact native file blocks')
    assert word(after, 0o145 * WORDS + 1) == 0o20000000
    assert word(after, 0o145 * WORDS + 2) == 0o20000001
    print('PASS v1572: real production V2 WRITE_INTENT, second write, '
          'CLEAN/unmount, %d changed bytes' % len(changes))
    print('PASS v1572: unchanged full 72-bit physical CLEAN ID, SHA256',
          hashlib.sha256(after).hexdigest())


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: verifier BEFORE_AFTER-CLEAN AFTER')
    check(sys.argv[1], sys.argv[2])

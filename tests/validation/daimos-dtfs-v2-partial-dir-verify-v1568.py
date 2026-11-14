#!/usr/bin/env python3
"""Whole-tape proof of real Type-551 interrupted V2 directory writes."""

import hashlib
import struct
import sys
from pathlib import Path

BLOCK = 128 * 8
DIR_RBN = 0o144
DIRTY = 0o552255225522
MAGIC = 0o446466575422
SALT = 0o246134572610
MASK = 0o777777777777


def word(data, index):
    hi, lo = struct.unpack_from('<II', data, index * 8)
    assert hi <= 0o777777 and lo <= 0o777777
    return (hi << 18) | lo


def rbn0(data):
    assert len(data) == 0o1102 * BLOCK
    header = [word(data, i) for i in range(128)]
    assert header[0] == MAGIC and header[1] and header[2]
    assert header[3] == (~(header[0] ^ header[1] ^ header[2])) & MASK
    assert header[4] in (0, DIRTY)
    assert header[5] == (~(header[0] ^ header[1] ^ header[2] ^
                          header[4] ^ SALT)) & MASK
    assert not any(header[6:])
    return header


def check(stage, source, destination):
    before, after = [Path(p).read_bytes() for p in (source, destination)]
    a, b = rbn0(before), rbn0(after)
    assert a[:4] == b[:4], 'physical volume identifier changed'
    changed = [n for n, (x, y) in enumerate(zip(before, after)) if x != y]
    assert changed, 'no real Type-551 physical media change observed'
    if stage == 'seed':
        assert a[4] == 0 and b[4] == DIRTY, (
            'production first DIR write did not durably arm V2')
        assert any(i < BLOCK for i in changed), 'no on-media DIRTY record'
        assert any(DIR_RBN * BLOCK <= i < (DIR_RBN + 1) * BLOCK
                   for i in changed), 'first directory entry not written'
        assert all(i < BLOCK or DIR_RBN * BLOCK <= i <
                   (DIR_RBN + 1) * BLOCK for i in changed), (
            'unexpected physical DATA or unrelated block changed')
    elif stage == 'partial':
        assert a[4] == DIRTY and b[4] == DIRTY
        assert before[:BLOCK] == after[:BLOCK], 'persistent DIRTY lost'
        assert all(DIR_RBN * BLOCK <= i < (DIR_RBN + 1) * BLOCK
                   for i in changed), 'torn DIR wrote outside directory'
        changed_words = [i for i in range(128) if word(before,
                         DIR_RBN * 128 + i) != word(after,
                         DIR_RBN * 128 + i)]
        assert len(changed_words) == 1, (
            'physical Type-551 did not interrupt after one changed word',
            changed_words)
    else:
        raise ValueError(stage)
    print('PASS v1568: %s real DIRTY/partial RBN0144, %d changed '
          'bytes; before=%s after=%s' %
          (stage, len(changed), hashlib.sha256(before).hexdigest(),
           hashlib.sha256(after).hexdigest()))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: verify.py seed|partial BEFORE AFTER')
    check(sys.argv[1], sys.argv[2], sys.argv[3])

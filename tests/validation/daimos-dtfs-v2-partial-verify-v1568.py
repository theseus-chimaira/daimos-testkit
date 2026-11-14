#!/usr/bin/env python3
"""Independent whole-tape oracle for physically interrupted V2 DATA.

Both snapshots originate from a *booted* PDP-6 Type-551 DTC3 after
DETACH flushed the simulator's real physical media. This code does
not create or modify a tape and never substitutes for physical I/O.
"""

import hashlib
import struct
import sys
from pathlib import Path

BLOCK = 128 * 8
MAGIC = 0o446466575422
DIRTY = 0o552255225522
SALT = 0o246134572610
MASK = 0o777777777777


def word(data, index):
    hi, lo = struct.unpack_from('<II', data, index * 8)
    assert hi <= 0o777777 and lo <= 0o777777
    return (hi << 18) | lo


def header(data):
    assert len(data) == 0o1102 * BLOCK
    words = [word(data, i) for i in range(128)]
    assert words[0] == MAGIC and words[1] != 0 and words[2] != 0
    assert words[3] == (~(words[0] ^ words[1] ^ words[2])) & MASK
    assert all(w == 0 for w in words[6:])
    assert words[4] in (0, DIRTY)
    assert words[5] == (~(words[0] ^ words[1] ^ words[2] ^
                         words[4] ^ SALT)) & MASK
    return words


def verify(stage, before_path, after_path):
    before, after = [Path(p).read_bytes() for p in
                     (before_path, after_path)]
    a, b = header(before), header(after)
    assert a[:4] == b[:4], 'volume identity changed during user write'
    changes = [i for i, (x, y) in enumerate(zip(before, after)) if x != y]
    assert changes, 'no physical changes observed'
    if stage == 'seed':
        assert a[4] == 0, 'first-write V2 tape was not CLEAN initially'
        assert b[4] == DIRTY, 'first write did not physically arm DIRTY'
        assert any(i < BLOCK for i in changes), 'no RBN0 transition'
        assert any(0o144 * BLOCK <= i < 0o145 * BLOCK for i in changes), (
            'real directory metadata was not written')
        assert any(0o145 * BLOCK <= i < 0o146 * BLOCK for i in changes), (
            'real DATA was not physically seeded')
        assert all(i < BLOCK or 0o144 * BLOCK <= i < 0o146 * BLOCK
                   for i in changes), 'physical seed touched unrelated tape'
        assert word(after, 0o145 * 128 + 1) == 0o10000000
        assert word(after, 0o145 * 128 + 2) == 0o10000001
    elif stage == 'partial':
        assert a[4] == DIRTY and b[4] == DIRTY
        assert before[:BLOCK] == after[:BLOCK], (
            'on-media DIRTY was lost during the partial DATA failure')
        assert all(0o145 * BLOCK <= i < 0o146 * BLOCK for i in changes), (
            'failed DATA write corrupted unrelated block/metadata')
        updated = [i for i in (1, 2) if word(before, 0o145 * 128 + i) !=
                   word(after, 0o145 * 128 + i)]
        assert len(updated) == 1, 'not exactly one changed data word'
        i = updated[0]
        assert word(after, 0o145 * 128 + i) == 0o20000000 + i - 1
        assert word(after, 0o145 * 128 + 3 - i) == word(
            before, 0o145 * 128 + 3 - i)
    else:
        raise ValueError(stage)

    print('PASS v1568: %s actual physical V2 DATA, %u changed bytes; '
          'before=%s after=%s' %
          (stage, len(changes), hashlib.sha256(before).hexdigest(),
           hashlib.sha256(after).hexdigest()))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: verify.py seed|partial BEFORE AFTER')
    verify(sys.argv[1], sys.argv[2], sys.argv[3])

#!/usr/bin/env python3
"""Negative physical-media mutations against the independent v1578 oracle.

Use a successfully recovered full-guest drum as input. Each mutation
recomputes LOGSTORE commit trailers when appropriate, so detection is
not merely an invalid-record checksum test. Never mutate source media.
"""
from pathlib import Path
import re
import struct
import subprocess
import sys

if len(sys.argv) != 5:
    raise SystemExit('usage: ... DRUM ORPHAN_REPORT VERIFIER WORKDIR')
source, orphan, verifier, work = (Path(s) for s in sys.argv[1:])
work.mkdir(parents=True, exist_ok=True)
data = source.read_bytes()
m = re.search(r'physical drum block ([0-7]+) sequence ([0-7]+)',
              orphan.read_text())
assert m
block = int(m.group(1), 8)
sequence = int(m.group(2), 8)
mask = (1 << 36) - 1
magic = int('546362454321', 8)

def get(words, idx):
    return struct.unpack_from('<Q', words, idx)[0]

def commit(words, base):
    meta = get(words, base + 3 * 8)
    seq = get(words, base + 8)
    trailer = ((~(magic + seq + ((meta & 0o777777) << 18))) & mask) | 1
    struct.pack_into('<Q', words, base + 127 * 8, trailer)

for name in ('false-orphan-commit', 'skip-first-sequence',
             'skip-marker-sequence', 'missing-marker-commit'):
    modified = bytearray(data)
    first = block * 1024
    marker = (block + 2) * 1024
    if name == 'false-orphan-commit':
        struct.pack_into('<Q', modified, first + 4 * 8,
                         int('157601', 8))
    elif name == 'skip-first-sequence':
        struct.pack_into('<Q', modified, first + 8, sequence + 1)
        commit(modified, first)
    elif name == 'skip-marker-sequence':
        struct.pack_into('<Q', modified, marker + 8, sequence + 3)
        commit(modified, marker)
    else:
        struct.pack_into('<Q', modified, marker + 127 * 8, 0)
    candidate = work / (name + '.dsk')
    candidate.write_bytes(modified)
    result = subprocess.run(
        [sys.executable, str(verifier), str(candidate), str(orphan),
         str(work / (name + '.report'))],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert result.returncode != 0, 'accepted unsafe physical mutation ' + name
    print('PASS v1578: rejected physical media mutation ' + name)

print('PASS v1578: four independently executed physical oracle mutations rejected')

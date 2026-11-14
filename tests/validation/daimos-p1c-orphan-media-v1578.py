#!/usr/bin/env python3
"""Inspect an abandoned real 36-bit LSREC1 in PDP-6 Type-236 media.

Do not infer status from guest stdout: decode complete 128-word physical
sectors and independently reject an allegedly successful commit trailer.
"""
from pathlib import Path
import struct
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: ... DRUM_IMAGE AUXSTORE_INSPECT REPORT')

image, layout, report = (Path(s) for s in sys.argv[1:])
raw = image.read_bytes()
assert len(raw) % 1024 == 0, 'physical 128-word sector size mismatch'
parts = [line.split() for line in layout.read_text().splitlines()]
parts = [s for s in parts if s and s[0] == 'LOGSTORE']
assert len(parts) == 1 and len(parts[0]) == 2, 'no unique LOGSTORE region'
start, count = (int(s, 8) for s in parts[0][1].split('+'))
assert count >= 3 and start + count <= len(raw) // 1024

magic = int('546362454321', 8)
code = int('157601', 8)
value = int('45671234567', 8)
mask = (1 << 36) - 1

def record(blockno):
    words = struct.unpack_from('<128Q', raw, blockno * 1024)
    assert all((v & ~mask) == 0 for v in words), 'invalid 36-bit drum encoding'
    return words

found = []
for physical in range(start + 2, start + count):
    r = record(physical)
    if r[0] != magic or r[4] != code:
        continue
    assert r[5] == value and r[1] != 0, 'orphan payload/sequence mismatch'
    assert (r[3] & 0o777777) == 2
    assert r[127] == 0, 'abandoned record unexpectedly committed'
    committed = ((~(magic + r[1] + ((r[3] & 0o777777) << 18))) & mask) | 1
    assert r[127] != committed
    found.append((physical, r[1]))

assert len(found) == 1, 'expected exactly one physical uncommitted LSREC1'
out = ('PASS v1578: exact uncommitted LSREC1 on physical drum block %o'
       ' sequence %o, trailer zero, distinct LOGSTORE partition\n' % found[0])
report.write_text(out)
print(out, end='')

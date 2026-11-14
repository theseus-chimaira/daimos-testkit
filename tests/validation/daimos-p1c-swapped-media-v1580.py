#!/usr/bin/env python3
"""Independently verify the physical Type-236 persistent snapshot geometry.

The test-only MRES verifies a live process swap owner at actual HALT entry.
This host check additionally reads the true drum blocks, not guest messages.
It does NOT infer a simultaneous PI-driven swap-in during the snapshot.
"""
from pathlib import Path
import struct
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: DRUM_IMAGE AUXSTORE_LAYOUT REPORT')

media, layout, report = (Path(s) for s in sys.argv[1:])
raw = media.read_bytes()
assert raw and len(raw) % 1024 == 0, 'not a physical 128-word Type-236 image'
lines = [p.split() for p in layout.read_text().splitlines()]
backing = [p[1] for p in lines if len(p) == 2 and p[0] == 'BACKSTORE']
logging = [p[1] for p in lines if len(p) == 2 and p[0] == 'LOGSTORE']
assert len(backing) == len(logging) == 1, 'missing unique AUXSTORE ranges'

def span(raw_span):
    return tuple(int(s, 8) for s in raw_span.split('+'))

start, count = span(backing[0])
log_start, log_count = span(logging[0])
assert count > 40 and log_count > 3, 'invalid backing/log geometry'
assert start + count <= len(raw) // 1024, 'backing exceeds device'
assert log_start + log_count <= len(raw) // 1024, 'log exceeds device'
assert start + count <= log_start or log_start + log_count <= start, \
    'LOGSTORE and BACKSTORE physically overlap'

wordmask = (1 << 36) - 1

def sector(blockno):
    values = struct.unpack_from('<128Q', raw, blockno * 1024)
    assert all(v & ~wordmask == 0 for v in values), \
        'physical device word exceeds 36 bits'
    return values

header = sector(start + count - 1)
magic = int('55464663', 8)
assert header[0] == magic, 'final snapshot commit header missing'
assert header[1] == 2, 'snapshot v2 format absent'
first, reserved = header[2:4]
pool_words = header[4]
assert 0 < pool_words <= 4096, 'unexpected effective MEMFS pool'
expected_span = (pool_words + 127) // 128 + 5 + 1
assert reserved == expected_span, 'snapshot reservation does not fit pool'
assert first + reserved == count, 'snapshot not at final backing boundary'

# A real 24K-word swapped process should have nonzero executable/user
# metadata blocks below the reserved snapshot, not just a final header.
# Zero-filled BSS is normal, so count nonzero *sectors*, not all words.
occupied_payload = 0
for b in range(start, start + first):
    if any(sector(b)):
        occupied_payload += 1
assert occupied_payload >= 2, 'no physical process swap payload witnessed'

msg = ('PASS v1580: physical BACKSTORE snapshot blocks %o..%o, '
       'pool %d words, valid v2 final commit and %d nonzero '
       'non-snapshot sectors\n' %
       (first, first + reserved - 1, pool_words, occupied_payload))
report.write_text(msg)
print(msg, end='')

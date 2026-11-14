#!/usr/bin/env python3
"""Verify physical LOGSTORE cursor recovered past an orphan, not from it.

Fixed 128K v1578 guest boots INIT and LOGIN, each of which emits one
LOGSTORE event before the test program. The writer must reuse the
invalid first-boot slot at its original sequence, then advance twice.
If KINIT wrongly accepts the orphan's missing commit marker, it
resumes at a later slot/sequence and this physical check fails.
"""
from pathlib import Path
import re
import struct
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: ... DRUM_IMAGE BEFORE_BOOT2_ORPHAN_REPORT OUT')

image, previous, report = (Path(s) for s in sys.argv[1:])
media = image.read_bytes()
assert len(media) % 1024 == 0
m = re.fullmatch(
    r'PASS v1578: exact uncommitted LSREC1 on physical drum block '
    r'([0-7]+) sequence ([0-7]+), trailer zero, distinct LOGSTORE partition\n',
    previous.read_text())
assert m, 'missing verified first-boot orphan position'
block, sequence = (int(s, 8) for s in m.groups())
mask = (1 << 36) - 1
magic = int('546362454321', 8)
first_code = int('157601', 8)
second_code = int('157602', 8)
value = int('45671234567', 8)

def read(n):
    r = struct.unpack_from('<128Q', media, n * 1024)
    assert all((x & ~mask) == 0 for x in r), 'not 36-bit drum words'
    assert r[0] == magic, 'invalid LOGSTORE record magic'
    assert (r[3] & 0o777777) <= 123
    expected = ((~(magic + r[1] + ((r[3] & 0o777777) << 18))) & mask) | 1
    assert r[127] == expected, 'invalid record accepted into producer ring'
    return r

first = read(block)
second = read(block + 1)
marker = read(block + 2)
assert first[1] == sequence, 'did not reuse orphan sequence after reboot'
assert first[4] != first_code, 'orphan was falsely committed'
assert second[1] == sequence + 1, 'second boot login sequence mismatch'
assert marker[1] == sequence + 2, 'LOGSTORE skipped orphan or advanced wrongly'
assert marker[4] == second_code and marker[5] == value

out = ('PASS v1578: KINIT physically reused orphan slot %o, sequences %o %o %o'
       ' with valid commit trailers; orphan was not accepted\n'
       % (block, sequence, sequence + 1, sequence + 2))
report.write_text(out)
print(out, end='')

#!/usr/bin/env python3
"""Check C99 grouped host encoder against v051 native PDP-6 golden words."""
import pathlib
import subprocess
import sys

fixture = pathlib.Path(sys.argv[1])
writer = pathlib.Path(sys.argv[2])
work = pathlib.Path(sys.argv[3])
work.mkdir(parents=True, exist_ok=True)
source = []
expected = []
current = None
for raw in fixture.read_text().splitlines():
    if raw == 'source:':
        current = source
    elif raw == 'expected:':
        current = expected
    elif raw.endswith(':') or raw.startswith('.bss'):
        current = None
    elif current is not None:
        line = raw.strip()
        if line.startswith('.word '):
            current.append(int(line.split()[1], 8))
assert len(source) == int('05312', 8), len(source)
assert len(expected) == int('04307', 8), len(expected)
srcfile = work / 'native-v051-source-v059.words'
outfile = work / 'host-v059-encoded.words'
srcfile.write_text(''.join('%012o\n' % x for x in source))
subprocess.run([str(writer), '-t', str(srcfile), str(outfile)], check=True)
produced = [int(line, 8) for line in outfile.read_text().splitlines()]
if produced != expected:
    for index, (got, want) in enumerate(zip(produced, expected)):
        if got != want:
            raise RuntimeError('golden mismatch word %d: %012o != %012o' % (index, got, want))
    raise RuntimeError('golden size mismatch: %d != %d' % (len(produced), len(expected)))
print('PASS native v051 golden parity: %d source / %d compressed words' %
      (len(source), len(produced)))

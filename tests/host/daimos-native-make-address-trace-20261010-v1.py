#!/usr/bin/env python3
"""Summarize MAKE arena realloc locations using opaque PDP-6 byte pointers."""
import re
import sys
from pathlib import Path
if len(sys.argv) != 2:
    raise SystemExit('usage: daimos-native-make-address-trace-20261010-v1.py OUTPUT_FILE')
pattern = re.compile(r'MAKE ALLOC INITIAL=(\d+) OLD=(\d+) NEW=(\d+) OLDADDR=(\d+) NEWADDR=(\d+)')
events = [tuple(map(int, x)) for x in pattern.findall(Path(sys.argv[1]).read_text())]
if not events:
    raise SystemExit('missing allocation events')
for initial, old, new, before, after in events:
    assert new > old
    kind = 'initial' if old == 0 else ('relocated' if before != after else 'in-place')
    print(f'initial={initial} old={old} new={new} location={kind}')
print('relocations:', sum(old != 0 and before != after for _, old, _, before, after in events))

#!/usr/bin/env python3
"""Analyze temporary native MAKE arena realloc movement traces."""
from pathlib import Path
import re
import sys
if len(sys.argv) != 2:
    raise SystemExit('usage: daimos-native-make-arena-movement-20261010-v1.py OUTPUT_FILE')
pat = re.compile(r'MAKE ARENA GROW OLD=(\d+) NEW=(\d+) MOVED=(\d+)')
entries = [tuple(map(int, x)) for x in pat.findall(Path(sys.argv[1]).read_text())]
if not entries:
    raise SystemExit('no arena growth traces')
assert entries[0][0] == 0
for (old, new, moved), next_entry in zip(entries, entries[1:]):
    assert new > old and moved in (0, 1)
    assert next_entry[0] == new
print(f'allocations={len(entries)} relocations={sum(m for old,new,m in entries)}')
for old,new,moved in entries:
    print(f'{old}->{new} chars; {"relocated" if moved else "initial/in-place"}')

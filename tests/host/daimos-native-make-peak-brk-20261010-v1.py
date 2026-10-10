#!/usr/bin/env python3
"""Compare BRK peak and arena relocation from instrumented PDP-6 MAKE logs."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: daimos-native-make-peak-brk-20261010-v1.py BASE_LOG NEW_LOG')
profile = re.compile(r'PEAK_BRK_CURRENT=(\d+) HIGH=(\d+) CALLS=(\d+) GROWS=(\d+) FREE=(\d+) LARGEST=(\d+)')
move = re.compile(r'ARENA_GROW=(\d+):(\d+):([01])')
values = []
for path in map(Path, sys.argv[1:]):
    src = path.read_text()
    rows = profile.findall(src)
    if len(rows) != 1:
        raise SystemExit(f'expected one peak snapshot in {path}')
    entries = [tuple(map(int, v)) for v in move.findall(src)]
    if not entries:
        raise SystemExit(f'no arena growth records in {path}')
    values.append((tuple(map(int, rows[0])), entries))
for title, (stats, entries) in zip(('before', 'after'), values):
    print(title, 'current', stats[0], 'high', stats[1], 'calls', stats[2],
          'break_writes', stats[3], 'free', stats[4], 'largest', stats[5],
          'arena_relocations', [(a,b) for a,b,m in entries if m])
print('high_break_delta_words:', values[1][0][1]-values[0][0][1])

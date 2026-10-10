#!/usr/bin/env python3
"""Compare native MAKE post-parse heap snapshots from two SIMH probes."""
from pathlib import Path
import re
import sys
if len(sys.argv) != 3:
    raise SystemExit('usage: daimos-native-make-scratch-heap-ab-20261010-v1.py BEFORE_OUTPUT AFTER_OUTPUT')
pattern = re.compile(r'MAKEPROFILE BRK=(\d+) FREE=(\d+) LARGEST=(\d+) HIGH=(\d+) ARENA=(\d+) USED=(\d+)')
records = []
for filename in sys.argv[1:]:
    matches = pattern.findall(Path(filename).read_text())
    if len(matches) != 1: raise SystemExit(f'expected one heap snapshot in {filename}')
    records.append(list(map(int, matches[0])))
before, after = records
for label, old, new in zip(('break', 'free', 'largest', 'high', 'arena_chars', 'used_chars'), before, after):
    print(f'{label}: before={old} after={new} delta={new-old:+d}')
assert before[5] == after[5], 'different stored strings in comparison'

#!/usr/bin/env python3
"""Extract native MAKE heap/free-list snapshots from SIMH probe outputs."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit('usage: daimos-native-make-heap-accounting-20261010-v1.py RUN_DIR')
root = Path(sys.argv[1]); found = 0
pattern = re.compile(r'MAKE HEAP (BEFORE|AFTER) BRK=(\d+) FREE=(\d+) LARGEST=(\d+)')
for file in sorted(root.glob('output.*')):
    stages = {}
    for stage, brk, free, largest in pattern.findall(file.read_text()):
        stages[stage] = tuple(map(int, (brk, free, largest)))
    if len(stages) != 2:
        continue
    before, after = stages['BEFORE'], stages['AFTER']
    assert before[0] == after[0]
    assert after[1] >= before[1]
    print(f'{file.name}: break={after[0]} free_before={before[1]} '
          f'free_after={after[1]} recovered={after[1]-before[1]} '
          f'largest_before={before[2]} largest_after={after[2]}')
    found += 1
if found != 5:
    raise SystemExit(f'expected five profiles, found {found}')

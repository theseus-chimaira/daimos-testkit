#!/usr/bin/env python3
"""Parse word-address native MAKE arena-neighbor snapshots."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit('usage: daimos-native-make-neighbor-profile-20261010-v1.py OUTPUT')
pat = re.compile(r'MAKE NEIGHBOR OLD=(\d+) END=(\d+) ADJFREE=(\d+) FREEWORDS=(\d+) BRK=(\d+)')
rows = [tuple(map(int, r)) for r in pat.findall(Path(sys.argv[1]).read_text())]
if not rows:
    raise SystemExit('no neighbor snapshots')
for old, end, adjacent, free, brk in rows:
    assert end <= brk and (adjacent or free == 0)
    why = 'at-break' if end == brk else ('adjacent-free' if adjacent else 'allocated-neighbor')
    print(f'arena_chars={old} end_word={end} break_word={brk} next={why} free_words={free}')

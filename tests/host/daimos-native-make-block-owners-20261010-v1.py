#!/usr/bin/env python3
"""Identify tracked allocated blocks directly following a MAKE arena."""
from pathlib import Path
import re
import sys
if len(sys.argv) != 2:
    raise SystemExit('usage: daimos-native-make-block-owners-20261010-v1.py OUTPUT_FILE')
pattern = re.compile(r'ALLOCBLOCK INIT=(\d+) WIDTH=(\d+) COUNT=(\d+) START=(\d+) END=(\d+)')
rows = [tuple(map(int, m)) for m in pattern.findall(Path(sys.argv[1]).read_text())]
if not rows:
    raise SystemExit('no allocation records')
for i, (initial, width, capacity, start, end) in enumerate(rows):
    if initial != 8192 or capacity not in (8192, 31250):
        continue
    followers = [r for r in rows[i+1:] if r[3] == end]
    if not followers:
        raise SystemExit(f'no tracked follower for arena at {end}')
    owner = followers[0]
    print(f'arena_chars={capacity} end_word={end} next_initial={owner[0]} '
          f'next_width_chars={owner[1]} next_count={owner[2]} '
          f'next_block_words={owner[4]-owner[3]}')

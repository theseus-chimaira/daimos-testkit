#!/usr/bin/env python3
"""Decode native SIMH PDP-6 MM extent snapshots; host-side only (v553)."""
import argparse
import re
from pathlib import Path


def inspect(text):
    frames = text.split('Breakpoint, PC: 016614')
    if len(frames) < 2:
        raise ValueError('no vm_space_brk_current breakpoint')
    frame = frames[1].split('Breakpoint, PC:')[0]
    entries = {
        int(addr, 8): int(value, 8)
        for addr, value in re.findall(r'^([0-7]+):\s*([0-7]{12})', frame, re.M)
    }
    count = entries[0o20217]
    if not 0 < count <= 136:
        raise ValueError(f'invalid descriptor count {count}')
    arena = entries[0o20213]
    base, size = arena & 0o777777, arena >> 18
    end = base + size
    cursor = base
    gaps = []
    for index in range(count):
        word = entries[0o20625 + index * 2]
        loc, length = word & 0o777777, word >> 18
        if not base <= loc < end or loc < cursor or loc + length > end:
            raise ValueError(f'invalid extent {index}: {loc:o}, {length:o}')
        if loc > cursor:
            gaps.append((cursor, loc, loc - cursor))
        cursor = loc + length
    if cursor < end:
        gaps.append((cursor, end, end - cursor))
    return count, base, end, gaps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('transcript', type=Path)
    args = parser.parse_args()
    count, base, end, gaps = inspect(args.transcript.read_text())
    print(f'v553: {count} extents, arena {base:06o}-{end:07o}')
    print(f'v553: free words {sum(g[2] for g in gaps)} (decimal)')
    print(f'v553: largest gap {max(g[2] for g in gaps):o} (octal words)')
    for start, stop, size in gaps:
        print(f'  {start:06o}-{stop:07o}: {size:06o}')


if __name__ == '__main__':
    main()

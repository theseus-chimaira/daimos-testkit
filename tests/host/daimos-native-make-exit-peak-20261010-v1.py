#!/usr/bin/env python3
"""Validate matched full-run native MAKE libc break high-water results."""
import re
import sys
from pathlib import Path
if len(sys.argv) != 3:
    raise SystemExit('usage: daimos-native-make-exit-peak-20261010-v1.py BASE_LOG OPTIMIZED_LOG')
profiles = []
for name in sys.argv[1:]:
    data = Path(name).read_text()
    parsing = re.findall(r'(?m)^PEAK_BRK_CURRENT=(\d+) HIGH=(\d+)' , data)
    final = re.findall(r'EXIT_PEAK_BRK_CURRENT=(\d+) HIGH=(\d+) FREE=(\d+) LARGEST=(\d+)', data)
    if len(parsing) != 1 or len(final) != 1:
        raise SystemExit(f'missing or duplicate profiling records: {name}')
    p, f = tuple(map(int, parsing[0])), tuple(map(int, final[0]))
    assert f[1] >= p[1] and f[1] >= f[0]
    profiles.append((p, f))
    print(f'{name}: parse_high={p[1]} exit_high={f[1]} exit_free={f[2]} largest={f[3]}')
print('max_break_delta_words=', profiles[1][1][1] - profiles[0][1][1])

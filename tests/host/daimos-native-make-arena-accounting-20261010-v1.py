#!/usr/bin/env python3
"""Extract arena-capacity accounting from instrumented MAKE probe output."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit('usage: daimos-native-make-arena-accounting-20261010-v1.py RUN_DIRECTORY')
root = Path(sys.argv[1]); found = 0
for path in sorted(root.glob('output.*')):
    for used, cap, need in re.findall(r'MAKE RAM ARENA USED=(\d+) CAP=(\d+) NEED=(\d+)', path.read_text()):
        used, cap, need = int(used), int(cap), int(need)
        assert used <= need <= cap and need % 4 == 0
        print(f'{path.name}: used_chars={used} old_chars={cap} target_chars={need} saved_words={(cap-need)//4}')
        found += 1
if not found:
    raise SystemExit('no MAKE RAM ARENA records found')

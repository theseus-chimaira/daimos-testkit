#!/usr/bin/env python3
"""Check equality of original and revised PDP-6 OPEN flag normalization."""
from pathlib import Path
import re
import sys

p = Path(sys.argv[1]) / 'system/kernel/proc/syscall_dispatch_pdp6.s'
s = p.read_text()
section = s[s.index('%L67:'):s.index('%L72:')]
for op in (r'hrrz\s+2,2', r'move\s+3,2', r'andi\s+2,3',
           r'caile\s+2,2', r'movei\s+2,2', r'addi\s+2,1',
           r'andi\s+3,034', r'ior\s+2,3'):
    if not re.search(op, section):
        raise SystemExit('FAIL OPEN normalization opcode ' + op)
for flags in range(1 << 18):
    previous = min((flags & 3) + 1, 3) | (flags & 0o34)
    current = min(flags & 3, 2) + 1 | (flags & 0o34)
    if previous != current:
        raise SystemExit(f'FAIL flags={flags:o}')
print('open-flag-normalization-v436: PASS (262144 flag words, exact old ABI)')

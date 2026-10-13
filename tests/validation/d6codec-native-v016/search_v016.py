#!/usr/bin/env python3
"""Exhaustive independent local rewrite search, assembler word-count objective.

Each candidate is assembled with DAS, not estimated by source length.
Only a separately simulator-tested candidate may be selected as validated.
"""
import itertools
import os
import re
import subprocess
from pathlib import Path

base = Path(__file__).resolve().parent
original = (base.parent / 'd6codec-native-v015' / 'decode_v015.s').read_text()
work = Path(os.environ.get('TMPDIR', str(Path.home() / 'tmp'))) / 'd6codec-optimizer-v016'
work.mkdir(parents=True, exist_ok=True)
# Each replacement is a potential peephole transformation. Branch conditions
# and register side effects must be validated by the actual PDP-6 simulator.
changes = [
 ('popcount', '        jumpl   11,d6v015_count_one\n        jrst    d6v015_count_next\n d6v015_count_one:\n        aoj     13,\n d6v015_count_next:',
  '        skipge  11\n        aoj     13,'),
 ('literal_bounds', '        camge   3,4\n        jrst    d6v015_lit_ok\n        jrst    d6v015_bad\n d6v015_lit_ok:',
  '        camge   3,4\n        jrst    d6v015_lit_ok\n        jrst    d6v015_bad\n d6v015_lit_ok:'),
 ('zero_bound', '        move    16,3\n        add     16,12\n        camle   16,4\n        jrst    d6v015_bad',
  '        move    16,4\n        sub     16,3\n        camge   16,12\n        jrst    d6v015_bad'),
 ('copy_bound', '        move    13,3\n        add     13,12\n        camle   13,4\n        jrst    d6v015_bad',
  '        move    13,4\n        sub     13,3\n        camge   13,12\n        jrst    d6v015_bad'),

]
# Eliminate no-op alternatives, then brute-force the true alternatives.
changes = [x for x in changes if x[1] != x[2]]
assert all(old in original for _, old, _ in changes)
results = []
for bits in itertools.product((False, True), repeat=len(changes)):
    text = original
    for enabled, (_, old, new) in zip(bits, changes):
        if enabled:
            text = text.replace(old, new, 1)
    asm = work / 'candidate.s'
    obj = work / 'candidate.dobj'
    asm.write_text(text)
    r = subprocess.run(['das', '-F', '-C', '-O', str(obj), str(asm)], capture_output=True, text=True)
    if r.returncode:
        continue
    r = subprocess.run(['pdp10-objdump', '-h', str(obj)], capture_output=True, text=True)
    match = re.search(r'text=(\d+)', r.stdout)
    if not match:
        continue
    words = int(match.group(1))
    results.append((words, bits, text))
results.sort(key=lambda x: x[0])
for words, bits, _ in results[:12]:
    print(words, ','.join(x[0] for b, x in zip(bits, changes) if b) or 'baseline')
print('assembled', len(results), 'combinations')
(base / 'optimizer-results-v016.txt').write_text('\n'.join(f'{w}\t{int(sum(b))}\t'+','.join(x[0] for bit,x in zip(b,changes) if bit) for w,b,_ in results)+'\n')
(base / 'decode_v016_best.s').write_text(results[0][2].replace('d6v015_', 'd6v016_'))

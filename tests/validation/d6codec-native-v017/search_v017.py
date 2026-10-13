#!/usr/bin/env python3
"""Enumerate structural rewrites; measure real DAS text words, no source heuristics."""
import itertools
import os
import re
import subprocess
from pathlib import Path

here = Path(__file__).resolve().parent
original = (here / 'decode_v017_baseline.s').read_text()
tmp = Path(os.environ.get('TMPDIR') or (Path.home() / 'tmp')) / 'd6codec-search-v017'
tmp.mkdir(parents=True, exist_ok=True)
# Alternatives that preserve guard predicates; the simulator is authoritative.
rewrites = [
 ('zero-branch',
  '        jumpe   16,d6v017_copy\n        caie    16,1\n        jrst    d6v017_bad\n        jumpn   13,d6v017_bad',
  '        jumpn   16,d6v017_check_zero\n        jrst    d6v017_copy\n d6v017_check_zero:\n        caie    16,1\n        jrst    d6v017_bad\n        jumpn   13,d6v017_bad'),
 ('finish-shared',
  ' d6v017_empty:\n        camn    3,4\n        jrst    d6v017_finish\n        jrst    d6v017_bad',
  ' d6v017_empty:\n        came    3,4\n        jrst    d6v017_bad\n        jrst    d6v017_finish'),
 ('literal-dispatch',
  '        jumpl   10,d6v017_match\n        camge   3,4\n        jrst    d6v017_lit_ok\n        jrst    d6v017_bad\n d6v017_lit_ok:',
  '        jumpl   10,d6v017_match\n        camge   3,4\n        jrst    d6v017_lit_ok\n        jrst    d6v017_bad\n d6v017_lit_ok:'),
 ('count-validation',
  '        jumpe   7,d6v017_bad\n        caile   7,036\n        jrst    d6v017_bad',
  '        caige   7,1\n        jrst    d6v017_bad\n        caile   7,036\n        jrst    d6v017_bad'),
 ('even-pair',
  '        jumpe   11,d6v017_left\n        hrrz    0,0\n        aoj     14,\n        setz    11,\n        jrst    d6v017_desc\n d6v017_left:\n        hlrz    0,0\n        movei   11,1',
  '        jumpe   11,d6v017_left\n        hrrz    0,0\n        aoj     14,\n        setz    11,\n        jrst    d6v017_desc\n d6v017_left:\n        hlrz    0,0\n        movei   11,1'),
]
rewrites = [(n,a,b) for n,a,b in rewrites if a != b]
assert all(a in original for _,a,_ in rewrites)
results = []
for bits in itertools.product((False,True), repeat=len(rewrites)):
    s = original
    for enabled,(_,a,b) in zip(bits,rewrites):
        if enabled: s = s.replace(a,b,1)
    src = tmp/'candidate.s'; obj = tmp/'candidate.dobj'
    src.write_text(s)
    if subprocess.run(['das','-F','-C','-O',str(obj),str(src)],capture_output=True).returncode: continue
    out = subprocess.run(['pdp10-objdump','-h',str(obj)],capture_output=True,text=True,check=True).stdout
    words = int(re.search(r'text=(\d+)',out).group(1))
    results.append((words,','.join(name for on,(name,_,_) in zip(bits,rewrites) if on) or 'baseline',s))
results.sort(key=lambda x:(x[0],x[1]))
(here/'optimizer-results-v017.tsv').write_text('words\trewrites\n'+''.join(f'{n}\t{names}\n' for n,names,_ in results))
(here/'decode_v017_candidate.s').write_text(results[0][2])
print('assembled',len(results),'candidates; best',results[0][:2])

#!/usr/bin/env python3
"""Generate the corrected K04 v1793 scratch-only SIDL/PREVM fixture.

Usage: fixture-v1793.py GENERATED_KCORE_ASM PREVIOUS_V1783_KCORE_ASM
The first directory must contain the proven v1785 mixed-owner source.
Only the two supplied generated assembly files are modified.
Never run this against the DAIMOS production source tree.
"""

"""Graft validated v1783 real PREVM B into v1785 SIDL A scratch."""
from pathlib import Path
import sys
base = Path(sys.argv[1])
prev = Path(sys.argv[2])
p = base / 'proc_pdp6.s'
s = p.read_text()
t = (prev / 'proc_pdp6.s').read_text()
assert s.count('v1785') > 30 and t.count('v1783') > 30
# Remove the v1785 post-VM PID6 pin: B must instead fail in PREVM.
start = '''        caie    1,6
        jrst    k04_post_release_real_v1785
'''
end = '''k04_post_release_real_v1785:
        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE
'''
assert s.count(start) == s.count(end) == 1
s = s.replace(start + s.split(start,1)[1].split(end,1)[0] + end,
              '        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE\n', 1)
# Remove post-VM first-refusal probe, then graft v1783 PREVM B probe.
a = '''        iorm    5,proc_finish_last_tick_v881 ; pending; no extra RAM word
'''
b = a + s.split(a,1)[1].split('proc_finish_fail:\n',1)[0]
assert s.count(b) == 1
s = s.replace(b,a+'        popj    17,\n',1)
# Replace only the VM retry / PREVM failure subroutine with validated B.
start = 'proc_finish_vm_retry_v997:\n'
end = 'proc_finish_vm_done:\n'
assert s.count(start) == s.count(end) == 1
assert t.count(start) == t.count(end) == 1
new_piece = start + t.split(start,1)[1].split(end,1)[0]
old_piece = start + s.split(start,1)[1].split(end,1)[0]
assert 'k04_prevm_base_v1783' in new_piece
s = s.replace(old_piece,new_piece.replace('v1783','v1788'),1)
# Retain v1785 SIDL A, and use versioned names for every fixture symbol.
s = s.replace('v1785','v1788')
# Twelve real SIDL attempts suffice to reach capped 01000 backoff and
# hold A throughout B's four deferred refusals.
a = '        caige   5,030                 ; 24 real VM destroy attempts'
b = '        caige   5,014                 ; 12 real VM destroy attempts'
assert s.count(a)==1
s = s.replace(a,b,1)
# Replace obsolete B post-VM scratch variables with B PREVM variables.
old_bss = '''        .globl  k04_post_base_v1788
k04_post_base_v1788:
        .block 1
        .globl  k04_post_calls_v1788
k04_post_calls_v1788:
        .block 1
        .globl  k04_post_done_v1788
k04_post_done_v1788:
        .block 1
'''
assert s.count(old_bss)==1
new_bss = ''
for name in ('base','calls','done'):
    label = 'k04_prevm_'+name+'_v1788'
    new_bss += '        .globl  '+label+'\n'+label+':\n        .block 1\n'
s = s.replace(old_bss,new_bss,1)
assert 'k04_post_' not in s
assert 'v1785' not in s and 'v1783' not in s
p.write_text(s)
q=base/'proc_run.s'
r=q.read_text()
assert r.count('v1785') > 0
q.write_text(r.replace('v1785','v1788'))
print('v1788: real SIDL A PID5 12 attempts + PREVM B PID6 5 attempts')

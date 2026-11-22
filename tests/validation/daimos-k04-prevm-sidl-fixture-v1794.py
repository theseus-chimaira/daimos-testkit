#!/usr/bin/env python3
"""Scratch-only reverse K04 PREVM PID5 / SIDL PID6 real-MM fixture."""
from pathlib import Path
import sys

base=Path(sys.argv[1])
prior=Path(sys.argv[2])
if base.name != "kcore-asm" or prior.name != "kcore-asm":
    raise SystemExit("must target generated scratch kcore-asm directories")
p=base/'proc_pdp6.s'
s=p.read_text()
t=(prior/'proc_pdp6.s').read_text()
assert s.count('v1784')>30 and t.count('v1781')>10
# Replace post-VM A (u-area) with PREVM A (pinned distinct VM).
start='''        caie    1,5
        jrst    k04_a_release_real_v1784
'''
end='''k04_a_release_real_v1784:
        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE
'''
assert s.count(start)==s.count(end)==1
old=start+s.split(start,1)[1].split(end,1)[0]+end
assert 'k04_a_done_v1784' in old
s=s.replace(old,'        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE\n',1)
# Preserve original proc_finish_mark_pending POPJ.  Never strip it.
marker='''        iorm    5,proc_finish_last_tick_v881 ; pending; no extra RAM word
        popj    17,
proc_finish_fail:
'''
assert s.count(marker)==1
# Insert existing and validated PREVM A code without modifying failure
# or return semantics; v1782 PREVM has 24 attempts, capped backoff.
a='proc_finish_vm_retry_v997:\n'
b='proc_finish_vm_done:\n'
assert s.count(a)==s.count(b)==t.count(a)==t.count(b)==1
snippet=a+t.split(a,1)[1].split(b,1)[0]
assert 'k04_prevm_active_v1781' in snippet
assert 'caige   5,030' in snippet
s=s.replace(a+s.split(a,1)[1].split(b,1)[0],
            snippet.replace('v1781','v1794'),1)
# 12 calls is enough to saturate, but retain 24 to maximize overlap.
# B SIDL stays at its existing fifth-attempt release and timing probes.
s=s.replace('v1784','v1794')
obsolete='''        .globl  k04_a_base_v1794
k04_a_base_v1794:
        .block 1
        .globl  k04_a_calls_v1794
k04_a_calls_v1794:
        .block 1
        .globl  k04_a_done_v1794
k04_a_done_v1794:
        .block 1
'''
assert s.count(obsolete)==1
new=''
for name in ('base','calls','done'):
    label='k04_prevm_'+name+'_v1794'
    new+='        .globl  '+label+'\n'+label+':\n        .block 1\n'
s=s.replace(obsolete,new,1)
assert 'k04_a_' not in s and 'v1784' not in s and 'v1781' not in s
assert s.count(marker)==1
p.write_text(s)
q=base/'proc_run.s'
r=q.read_text()
assert r.count('v1784')>=1 and 'caie    012,6' in r
q.write_text(r.replace('v1784','v1794'))
print('v1794: PREVM A PID5 24 real VM destroys; SIDL B PID6 five')

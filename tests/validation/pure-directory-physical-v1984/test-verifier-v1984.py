#!/usr/bin/env python3
"""Negative controls derived from the actual physical monitor transcript."""
import argparse
from pathlib import Path
import runpy
import re

v=runpy.run_path(str(Path(__file__).with_name('verify-pressure-v1984.py')))
p=argparse.ArgumentParser()
p.add_argument('build',type=Path)
p.add_argument('work',type=Path)
args=p.parse_args()
s=v['symbols'](args.build/'kcore.map')
t=(args.work/'physical.clean').read_text()
good=v['verify_restore'](args.build,args.work,t)
meta=v['words'](v['between'](t,'V1941_END_B','V1983_META'))
mode=meta[s['proc_storage_runtime_v29']]
slot=good['restored_slot']

def change_word(text,start,end,addr,transform):
    a=text.index(start)+len(start); b=text.index(end,a)
    part=text[a:b]
    pat=r'(?m)^([0-7]{1,7}):\s*([0-7]{12})$'
    changed=0
    def sub(m):
        nonlocal changed
        if int(m[1],8)!=addr:return m[0]
        changed+=1
        return '%s:\t%012o'%(m[1],transform(int(m[2],8)))
    out=re.sub(pat,sub,part)
    assert changed==1,(start,addr)
    return text[:a]+out+text[b:]

cases=[('fake-pressure',t.replace('x[BV1941_STAGE_B','x[Q V1941_STAGE_B',1)),
       ('shutdown-dump',t.replace('V1941_STAGE_B','SIGTERM\nV1941_STAGE_B',1)),
       ('missing-wait',t.replace('wwwwwwwZV1983_Z_STOP','wwwwwwZV1983_Z_STOP',1)),
       ('wrong-mode',change_word(t,'V1941_END_PRESSURE','V1983_MAP_PRESSURE',mode+slot//18,lambda x:x&~(3<<(2*(slot%18))))),
       ('wrong-finish-target',change_word(t,'\nV1983_FINISH\n','\nV1983_FINISH_AC\n',4,lambda x:x+1)),
       ('wrong-restore-slot',change_word(t,'\nV1983_RESTORE\n','\nV1983_AC\n',1,lambda x:x+1)),
       ('wrong-finish-current',change_word(t,'V1941_STAGE_FINISH','V1941_END_FINISH',s['proc_current_slot'],lambda x:slot))]
# Alter the actual pinned source meta, not an unrelated descriptor.
mm=v['words'](v['section'](t,'FINISH'))
addr=next(s['mm_extents']+2*i+1 for i in range(mm[s['mm_extent_count']])
          if mm[s['mm_extents']+2*i]&v['MASK']==good['source'])
cases.append(('missing-source-pin',change_word(t,'V1941_STAGE_FINISH','V1941_END_FINISH',addr,lambda x:x&~(255<<21))))
for name,trace in cases:
    assert trace!=t,name
    try:v['verify_restore'](args.build,args.work,trace)
    except (AssertionError,KeyError,StopIteration,ValueError):print('PASS: rejected '+name)
    else:raise SystemExit('FAIL: accepted '+name)

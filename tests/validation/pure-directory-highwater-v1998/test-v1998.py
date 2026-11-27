#!/usr/bin/env python3
"""Reject independently corrupted evidence; original files stay untouched."""
import copy
import json
from pathlib import Path
import runpy
import sys

w=Path(sys.argv[1])
m=runpy.run_path(str(Path(__file__).with_name('verify-v1998.py')))
replay=m['replay']
event=m['EVENT']
start=json.loads((w/'start-v1998.json').read_text())
trace=(w/'console-v1426.log').read_text().replace('\r','')
snaps={n:json.loads((w/(n+'.json')).read_text()) for n in ('initial','held','restored')}
replay(w,start,trace,snaps)
cases=[]
def add(name,t=trace,s=start,p=snaps):
    cases.append((name,t,s,p))
first=next(event.finditer(trace))
head='Breakpoint, PC: '+first.group(1)
add('unpaired event',trace.replace(head,head+'\n'+head,1))
add('unknown writer',trace.replace(head,'Breakpoint, PC: 000020',1))
addr=start['symbols']['mm_extent_count']
add('missing count watch',trace.replace('SET BREAK -W %o;'%addr,'MISSING -W %o;'%addr,1))
matches=list(event.finditer(trace))
x=next(x for x in matches if x.group(2)==('%o'%addr))
add('missing commit',trace[:x.start()]+trace[x.end():])
drop_pc=start['base']+start['mres']['mm_pure_bitmap_place_v1985']-m['labels'](w/'commit.labels')['mm_pure_bitmap_place_v1985']+m['labels'](w/'commit.labels')['mbc_place_store_v1985']+6
x=next(x for x in matches if int(x.group(1),8)==drop_pc)
add('bad DROP metadata',trace[:x.start()]+x.group(0).replace(x.group(3),'000001000002')+trace[x.end():])
s=copy.deepcopy(start);s['words'][str(start['symbols']['mm_arena_count'])]=2
add('changed arena',s=s)
p=copy.deepcopy(snaps);p['restored']['extents'][0]+=1
add('checkpoint mismatch',p=p)
add('missing HALT',trace.replace('HALT instruction','MISSING HALT'))
for name,t,s,p in cases:
    try: replay(w,s,t,p)
    except (AssertionError,ValueError,KeyError): print('PASS reject',name)
    else: raise SystemExit('FAIL accepted '+name)

#!/usr/bin/env python3
"""Check genuine full MM descriptor table and retry, no synthetic deposits."""
import json
from pathlib import Path
import re
import runpy
import sys

HERE=Path(__file__).resolve().parent
V=runpy.run_path(str(HERE.parent/'pure-runtime-reclaim-v1673/measure-v1673.py'))

def verify(fixture,coremap,console,core,target):
    assert core==48
    for name in V['EVENTS']:
        V['lookup'](fixture,name)
    t=Path(console).read_text(encoding='ascii')
    assert 'PURE                              LOADED' in t
    assert 'V1673 PASS RUN EXIT WAIT' in t
    assert re.findall(r'(?m)^V1953 CHILD (\d+)$',t)==['2','3','4','5']
    assert re.findall(r'(?m)^V1953 WAIT (\d+)$',t)==['2','3','4','5']
    n=int(re.search(r'(?m)^V1953 EXTRA PIPES (\d+)$',t)[1])
    assert 1<=n<6
    addrs={x:V['lookup'](coremap,x) for x in V['GLOBALS']+('mm_arenas','mm_extents')}
    d={};r={};e={}
    last=0
    for label in 'ABCD':
        h='V1673 HOLD '+label; end='V1673 RELEASE '+label
        assert t.count(h)==t.count(end)==1
        a,b=t.index(h),t.index(end)
        assert last<a<b
        last=b
        pairs=re.findall(r'(?m)^(?:sim> )?([0-7]{3,7}):\s+([0-7]{12})\s*$',t[a:b])
        d[label]={int(x,8):int(y,8) for x,y in pairs}
        assert len(d[label])==len(pairs)
        r[label]=V['read_event']({'words':d[label],'name':label},addrs,core)
        es=[]
        for i in range(r[label]['extents']):
            q=d[label][addrs['mm_extents']+2*i]
            m=d[label][addrs['mm_extents']+2*i+1]
            es.append((q&0o777777,q>>18,(m>>18)&7,(m>>21)&255,m&0o777777))
        e[label]=es
    def pipes(label):
        return [x for x in e[label] if x[2]==3 and x[4]==5]
    assert len(pipes('A'))==1 and len(pipes('D'))==0
    assert len(pipes('B'))==len(pipes('C'))==1+12+n
    for l in 'BC':
        assert r[l]['extents']==32 and r[l]['free_words']>=14
        assert r[l]['largest_free_words']>=14
        assert len(r[l]['process_states'])==5
        assert all(x['state']==3 for x in r[l]['process_states'] if x['slot']>1)
        assert all(x[1]==14 and x[3]==0 for x in pipes(l))
    assert r['B']['process_states']==r['C']['process_states']
    assert r['B']['mm_allocated_words']==r['C']['mm_allocated_words']
    assert r['D']['process_high_slot']==2 and len(r['D']['process_states'])==1
    assert r['D']['packed_apr_count']==0
    assert r['A']['pinned_extents']==r['B']['pinned_extents']==r['C']['pinned_extents']==r['D']['pinned_extents']
    # Only the coordination pipe and disposable 129-word block cache
    # may disappear. Every remaining owner must retain its identity.
    assert len([x for x in e['A'] if x[2:]==(3,0,6) and x[1]==129])==1
    assert e['D']==[x for x in e['A'] if not (x[2]==3 and x[4] in (5,6))]
    assert r['D']['free_words']==r['A']['free_words']+143
    Path(target).write_text(json.dumps(r,indent=2,sort_keys=True)+'\n')
    print('PASS physical descriptor exhaustion, close/retry/refuse, exact WAIT cleanup; MM',
          '->'.join(str(r[l]['extents']) for l in 'ABCD'))

if __name__=='__main__':
    assert len(sys.argv)==6
    verify(*sys.argv[1:4],int(sys.argv[4]),sys.argv[5])

#!/usr/bin/env python3
"""Additional actual MM conservation checks for the mixed FULL replay."""
import argparse
import json
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
V=runpy.run_path(str(HERE.parent/'pure-k07-full-v1941/verify-v1941.py'))
MASK=0o777777


def verify(build,work,prefix,core,children,trace=None):
    if trace is None:
        trace=(work/'physical.clean').read_text(encoding='ascii')
    s=V['symbols'](build/'kcore.map')
    assert 'git commit id: cb6a255' in trace
    d={l:V['words'](V['section'](trace,l)) for l in ('B','A','FULL','Z')}
    e={l:V['extents'](d[l],s,core) for l in d}
    def arena(l):
        snap=d[l]
        return [(w&MASK,(w&MASK)+(w>>18)) for w in
                (snap[s['mm_arenas']+i] for i in range(snap[s['mm_arena_count']]))]
    a=arena('B')
    assert all(arena(l)==a for l in d)
    managed=sum(y-x for x,y in a)
    report={}
    for l in d:
        assert d[l][s['proc_exec_resv_head_v1933']]==0
        ext=e[l]
        allocated=sum(y-x for x,y,*_ in ext)
        gaps=[]
        for start,end in a:
            cur=start
            for x,y,*_ in ext:
                if start<=x<end:
                    gaps.append(x-cur)
                    cur=y
            gaps.append(end-cur)
        assert min(gaps)>=0 and sum(gaps)+allocated==managed
        report[l]=dict(extents=len(ext),allocated=allocated,
                       free=sum(gaps),largest=max(gaps),
                       packed_words=sum(y-x for x,y,k,p,o in ext if k==4),
                       pinned_words=sum(y-x for x,y,k,p,o in ext if p),
                       tick=d[l][s['proc_timer_clock']])
    assert d['B'][s['proc_high_slot']]==children+2
    assert d['Z'][s['proc_high_slot']]==2
    assert e['B']==e['A']
    # Stable parent VM and u-area; boot kernel owners survive.
    def owners(l,kind,owner):
        return [q for q in e[l] if q[2]==kind and q[4]==owner]
    for k,o in [(1,1),(3,0o1001),(3,2),(3,3),(3,4),(3,0o12),(3,0o20)]:
        assert len(owners('B',k,o))==1
        assert owners('B',k,o)==owners('Z',k,o)
    assert [q for q in e['Z'] if q[2] in (1,4)]==owners('Z',1,1)
    assert len(e['Z'])==8
    assert all(q[3]==0 for q in e['Z'] if not (q[2]==3 and q[4]==2))
    # The pipe owner (5) disappears after close/WAIT. The runtime
    # block-cache owner (6) is allocated on demand, so total allocated delta
    # must account for these real owners rather than assume identical
    # non-child allocation tables.
    assert not owners('Z',3,5)
    assert len(owners('Z',3,6))==1
    assert sum(y-x for x,y,k,p,o in e['B'] if k==4)==children*0o7000
    assert report['B']['free']>=0o10000
    assert report['B']['largest']<0o10000
    assert report['Z']['free']>report['B']['free']
    report['gross_raw_words']=children*0o1000
    report['fixed_resident_including_mm']=core*1024-managed-0o60
    report['managed_words']=managed
    return report


def main():
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    p.add_argument('--core',type=int,choices=(48,64),required=True)
    p.add_argument('--children',type=int,choices=(5,9),required=True)
    a=p.parse_args()
    V['verify'](a.build,a.work,a.prefix,a.children,a.core)
    r=verify(a.build,a.work,a.prefix,a.core,a.children)
    (a.work/'conservation-v1951.json').write_text(json.dumps(r,indent=2)+'\n')
    print('PASS v1951 conservation',json.dumps(r,sort_keys=True))

if __name__=='__main__':
    main()

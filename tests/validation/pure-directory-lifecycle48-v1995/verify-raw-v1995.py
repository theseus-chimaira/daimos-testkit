#!/usr/bin/env python3
"""Independent physical RAW control for the same v1987 lifecycle workload."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
MASK=0o777777


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(build,work,baseline):
    s=v['symbols'](build/'kcore.map')
    mres=v['symbols'](build/'pure-mres-v1612.map')
    trace=(work/'physical.clean').read_text()
    hashes=dict((name,h) for h,name in (x.split() for x in (work/'images.sha256').read_text().splitlines()))
    assert set(hashes)=={'kcore.dxr','kinit.lowmem.words','pure-mres-v1612.dxr'}
    assert all(digest(build/n)==digest(baseline/n)==h for n,h in hashes.items())
    assert all(digest(build/f'media/dtc{i}.tap')==digest(work/f'media/dtc{i}.tap') for i in range(3))
    assert 'MEM                                  48 K' in trace and 'PURE                              LOADED' in trace
    hit=re.search(r'(a{4,12})x\[BV1941_STAGE_B\b',trace)
    assert hit
    children=len(hit[1])
    mm=v['words'](v['section'](trace,'PRESSURE'))
    assert mm==v['words'](v['section'](trace,'B'))
    assert mm[s['mm_extent_capacity']]==32 and mm[s['proc_current_slot']]==1
    assert mm[s['proc_high_slot']]==children+2 and not mm[s['proc_exec_resv_head_v1933']]
    e=v['extents'](mm,s,48)
    meta=v['words'](v['between'](trace,'V1941_END_B','V1983_META'))
    d=v['words'](v['between'](trace,'V1941_END_PRESSURE','V1983_MAP_PRESSURE'))
    modebase,slots=(meta[s['proc_storage_runtime_v29']+i] for i in (0,1))
    table=meta[s['proc_table']]
    assert children+2<=slots<=255
    service=mm[s['proc_swap_service_one']]
    assert service>>18==0o254000
    base=(service&MASK)-mres['proc_pure_mres_service_v1612']
    assert mm[s['proc_swap_reclaim']]==(0o254000<<18)|(base+mres['proc_pure_mres_reclaim_v1612'])
    assert meta[s['proc_swap_term_v1666']]==(0o254000<<18)|(base+mres['pdp6_pure_detach_v1609'])
    raw=[]
    for slot in range(2,children+2):
        pm,vm,sc=(d[table+3*slot+i] for i in range(3))
        mode=(d[modebase+slot//18]>>(2*(slot%18)))&3
        assert pm&0o600000==0o400000 and sc>>33==(3 if slot<4 else 6)
        owners=[x for x in e if x[4]==slot and x[2] in (1,4)]
        assert len(owners)==1
        lo,hi,kind,pin,_=owners[0]
        assert not pin and (pm>>18,(pm>>18)+0o410,3,0,0o1000+slot) in e
        if mode==2:
            assert kind==4 and not vm&MASK and hi-lo==3584 and vm>>18==4096
            raw.append(slot)
        else:
            assert mode==0 and kind==1 and vm&MASK==lo and vm>>18==hi-lo
    assert raw
    tail=v['between'](trace,'V1983_MAP_PRESSURE','V1983_Z_STOP')
    assert re.fullmatch(r'\s*k{%d}L(?:wwEX|wEXw)Z\s*'%(children-2),tail)
    assert 'SIGTERM' not in trace
    result=dict(children=children,raw_children=raw,physical_mm_extents=len(e),
                free=sum(mm[s['mm_arenas']+i]>>18 for i in range(mm[s['mm_arena_count']]))-sum(b-a for a,b,*_ in e))
    return v['verify_final'](build,work,result,trace,core=48)


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ('build','work','baseline'):
        p.add_argument(name,type=Path)
    args=p.parse_args()
    print(json.dumps(verify(args.build,args.work,args.baseline),indent=2,sort_keys=True))

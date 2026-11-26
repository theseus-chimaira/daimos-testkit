#!/usr/bin/env python3
"""Require a matched capacity gain and complete live teardown."""
import argparse
import json
from pathlib import Path
import re
import runpy

v=runpy.run_path(str(Path(__file__).resolve().parent.parent /
                      'pure-directory-physical-v1984/verify-pressure-v1984.py'))


def changed_word(trace,start,end,addr,transform):
    a=trace.index(start)+len(start)
    b=trace.index(end,a)
    changes=0
    def sub(match):
        nonlocal changes
        if int(match[1],8)!=addr:
            return match[0]
        changes+=1
        return '%s:\t%012o'%(match[1],transform(int(match[2],8)))
    middle=re.sub(r'(?m)^([0-7]{1,7}):\s*([0-7]{12})$',sub,trace[a:b])
    assert changes==1
    return trace[:a]+middle+trace[b:]


def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','old_build','old_work','raw_build','raw_work'):
        p.add_argument(name,type=Path)
    args=p.parse_args()
    trace=(args.work/'physical.clean').read_text()
    current=v['verify_restore'](args.build,args.work,trace)
    v['verify_final'](args.build,args.work,current,trace)
    old=v['verify_restore'](args.old_build,args.old_work)
    raw=v['verify_raw_completion'](args.raw_build,args.raw_work)
    assert current['fixtures']==old['fixtures']==raw['fixtures']
    assert current['children']>max(old['children'],raw['children'])
    assert any(x['base']%1024 for x in current['packed'])
    assert current['source']%1024, 'first actual restore did not use a moved source'
    assert (args.build/'kcore.dxr').read_bytes()==(args.old_build/'kcore.dxr').read_bytes()
    result=v['compare'](args.build,current,args.raw_build,raw)
    result.update(old_children=old['children'],new_checked_waits=current['guest_checked_waits'],
                  final_mm=current['final_mm_verified'],normal_halt=current['normal_halt'])
    assert result['net_equivalent_RAW']>0
    print(json.dumps(result,indent=2,sort_keys=True))
    # Mutate actual captured final state, not synthetic monitor records.
    s=v['symbols'](args.build/'kcore.map')
    meta=v['words'](v['between'](trace,'V1941_END_B','V1983_META'))
    modebase=meta[s['proc_storage_runtime_v29']]
    table=meta[s['proc_table']]
    mm=v['words'](v['section'](trace,'Z'))
    slot=current['restored_slot']
    owner=next(s['mm_extents']+2*i+1 for i in range(mm[s['mm_extent_count']])
               if (mm[s['mm_extents']+2*i+1]>>18)&7==3 and
               mm[s['mm_extents']+2*i+1]&0o777777!=0o1001)
    cases=[('stale-mode',changed_word(trace,'V1941_END_Z','V1983_MAP_Z',modebase+slot//18,
                                      lambda x:x|(3<<(2*(slot%18))))),
           ('stale-uarea-bit',changed_word(trace,'V1941_END_Z','V1983_MAP_Z',table+3*slot,
                                           lambda x:x|0o400000)),
           ('orphan-uarea',changed_word(trace,'V1941_STAGE_Z','V1941_END_Z',owner,
                                         lambda x:(x&~0o777777)|(0o1000+slot))),
           ('wrong-current',changed_word(trace,'V1941_STAGE_Z','V1941_END_Z',s['proc_current_slot'],lambda x:slot)),
           ('missing-halt',trace.replace('HALT instruction, PC: 000000','unexpected stop',1))]
    for name,bad in cases:
        assert bad!=trace,name
        try:v['verify_final'](args.build,args.work,{},bad)
        except (AssertionError,KeyError,StopIteration,ValueError):print('PASS: rejected '+name)
        else:raise SystemExit('FAIL: accepted '+name)
    print('PASS: matched placement capacity and final MM/HALT (not PI6/EXEC acceptance)')

if __name__=='__main__':
    main()

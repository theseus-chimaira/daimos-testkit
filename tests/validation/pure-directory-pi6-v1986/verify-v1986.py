#!/usr/bin/env python3
"""Independent actual PI6, READY_ONCE and first dispatch verification."""
import argparse
import json
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
binding=runpy.run_path(str(HERE.parent/'pure-k08-pi6-v1946/binding-v1946.py'))
words,between,section,extents,symbols=(v[k] for k in ('words','between','section','extents','symbols'))
MASK=0o777777
READY=0o1000


def verify(build,work,prefix,trace=None,scoped=False):
    if trace is None:
        trace=(work/'physical.clean').read_text()
    # Do not let added monitor output substitute for actual guest markers.
    before=between(trace,'V1983_MAP_RESTORE','V1986_PRE_FINISH')
    if scoped:
        after=between(trace,'V1983_MAP_FINISH','V1986_ID_READY')
        result=v['verify'](build,work,False,trace)
        r=words(between(trace,'\nV1983_RESTORE\n','\nV1983_AC\n'))
        f=words(between(trace,'\nV1983_FINISH\n','\nV1983_FINISH_AC\n'))
        slot,source,encoded,target=(f[i] for i in (1,2,3,4))
        original=next(x for x in result['packed'] if x['slot']==slot)
        assert r[1]==slot and original['base']==source and original['words']==encoded
        result.update(restored_slot=slot,source=source,target=target,peak=encoded+original['full'])
    else:
        after=between(trace,'V1983_MAP_FINISH','V1986_ID_GUEST')
        assert re.search(r'(?m)^w\s*V1986_GUEST_W$',after)
        plain=trace.split('V1983_MAP_RESTORE',1)[0]+'V1983_MAP_RESTORE'+trace.split('V1986_PRE_FINISH',1)[1]
        plain=plain.split('V1983_MAP_FINISH',1)[0]+'V1983_MAP_FINISH\nw'+plain.split('V1986_ID_GUEST',1)[1].lstrip('\n')
        result=v['verify_restore'](build,work,plain)
        v['verify_final'](build,work,result,plain)
    s=symbols(build/'kcore.map')
    mres=symbols(build/'pure-mres-v1612.map')
    for name in ('dtfs-mres.map','dtfs-mres.dxr','tape-mres.map','tape-mres.dxr'):
        assert v['digest'](build/name)==v['digest'](work/name)
    provider=binding['read'](build,work,prefix)
    base=result['installed_base']
    slot=result['restored_slot']
    source=result['source']; target=result['target']
    encoded=next(x['words'] for x in result['packed'] if x['slot']==slot)
    full=result['peak']-encoded
    assert source%1024 and target%1024==0
    full_pc=base+mres['proc_pure_bitmap_restore_v1980']
    finish_pc=base+mres['mm_pure_bitmap_finish_v1664']
    assert re.search(r'Breakpoint, PC: %06o\b'%full_pc,trace)
    assert re.search(r'Breakpoint, PC: %06o\b'%finish_pc,trace)
    assert 'SIGTERM' not in trace[:trace.index('V1986_ID_READY')]
    meta=words(between(trace,'V1941_END_B','V1983_META'))
    modebase=meta[s['proc_storage_runtime_v29']]
    p=meta[s['proc_table']]+3*slot
    lo,hi=s['proc_idle_loop'],s['proc_finish_backoff_advance_v885']
    code=words(between(trace,'V1983_MAP_RESTORE','V1986_IDLE_CODE'))
    ret=[a+1 for a,x in code.items() if lo<=a<hi and x==0o260740000000|s['proc_swap_service_one']]
    assert len(ret)==1
    ret=ret[0]
    loader=base+mres['exec_image_full_bounded_v1391']
    tick=s['proc_sched_pi_tick']; dispatch=s['proc_sched_restore_selected']
    assert [int(x,8) for x in re.findall(r'Breakpoint, PC: ([0-7]{6})\b',before)]==[loader,tick]
    assert [int(x,8) for x in re.findall(r'Breakpoint, PC: ([0-7]{6})\b',after)]==([ret] if scoped else [ret,dispatch])
    def state(label):
        mm=words(section(trace,label))
        cells=words(between(trace,'V1941_END_'+label,'V1983_MAP_'+label))
        scalars=words(between(trace,'V1983_MAP_'+label,'V1986_SCALARS_'+label))
        identity=words(between(trace,'V1986_SCALARS_'+label,'V1986_ID_'+label))
        mm.update(cells); mm.update(scalars); mm.update(identity)
        return mm,extents(mm,s,64)
    original,oe=state('LOADER')
    ua=original[p]>>18
    rec=original[s['proc_swap_records']]+slot
    backing=original[rec]; cred=original[ua+0o66]
    assert backing and cred&(1<<31)
    expected=(1<<32)|(3<<29)|((source>>7)<<18)|target
    pair=[(source,source+encoded,4,1,slot),(target,target+full,1,1,slot)]
    def packed(d,e):
        assert d[s['proc_current_slot']]==0 and d[s['proc_current_ptr']]==0
        assert d[s['proc_sched_cursor']]==slot
        assert d[p]&0o600000==0o600000 and d[p]>>18==ua
        assert d[p+1]==full<<18 and d[p+2]>>33==2
        assert (d[modebase+slot//18]>>(2*(slot%18)))&3==3
        assert (ua,ua+0o410,3,0,0o1000+slot) in e
        assert [x for x in e if x[4]==slot and x[2] in (1,4)]==sorted(pair)
        assert d[ua+0o67]==expected and d[ua+0o406]==backing==d[rec]
        assert d[ua+0o66]==cred and not d[ua+0o24]&6
        assert d[s['proc_swap_records']]==original[s['proc_swap_records']]
        assert d[s['proc_exec_resv_head_v1933']]==0
    packed(original,oe)
    assert original[1]==backing and original[2]==target and original[3]==ua and original[4]==full
    irq,ie=state('PI6'); packed(irq,ie)
    assert ie==oe
    saved=irq[s['pdp10_pi_level6']]
    assert saved&MASK and not saved&(0o10000<<18)
    region=binding['classify'](saved&MASK,irq,s,base,provider)
    assert irq[tick]==0o350040000000|s['proc_timer_clock']
    assert irq[s['proc_timer_clock']]>=original[s['proc_timer_clock']]
    a=words(between(trace,'V1986_ID_LOADER','V1986_PAYLOAD_LOADER'))
    b=words(between(trace,'V1986_ID_PI6','V1986_PAYLOAD_PI6'))
    assert set(a)==set(b)==set(range(source,source+encoded)) and a==b
    finish=words(section(trace,'FINISH'))
    finish.update(words(between(trace,'V1941_END_FINISH','V1983_MAP_FINISH')))
    assert extents(finish,s,64)==ie
    assert finish[s['proc_current_slot']]==0
    assert finish[p]&0o600000==0o600000 and finish[p]>>18==ua
    assert finish[p+1]==full<<18 and finish[p+2]>>33==2
    assert (finish[modebase+slot//18]>>(2*(slot%18)))&3==3
    assert finish[s['proc_timer_clock']]>irq[s['proc_timer_clock']]
    def resident(d,e,current):
        assert d[s['proc_current_slot']]==current
        assert d[p]&0o600000==0o400000 and d[p]>>18==ua
        assert d[p+1]==(full<<18)|target and d[p+2]>>33==2
        assert (d[modebase+slot//18]>>(2*(slot%18)))&3==0
        assert (ua,ua+0o410,3,0,0o1000+slot) in e
        assert [x for x in e if x[4]==slot and x[2] in (1,4)]==[(target,target+full,1,0,slot)]
        assert not any(x[0]<source+encoded and source<x[1] for x in e)
        assert d[ua+0o67]==d[ua+0o406]==0
        assert d[ua+0o66]==cred and d[rec]==backing
        assert d[s['proc_swap_records']]==original[s['proc_swap_records']]
    ready,ready_extents=state('READY'); resident(ready,ready_extents,0)
    assert ready[s['proc_sched_cursor']]==ready[1]==READY|slot
    assert ready[s['proc_timer_clock']]>=finish[s['proc_timer_clock']]
    summary=dict(slot=slot,source=source,encoded=encoded,target=target,full=full,
                 pi6_pc=saved&MASK,pi6_region=region,pi6_tick=irq[s['proc_timer_clock']],
                 finish_tick=finish[s['proc_timer_clock']],ready_tick=ready[s['proc_timer_clock']],
                 ready_once=True)
    if scoped:
        summary.update(first_dispatch=False,final_mm=False,normal_halt=False)
        return summary
    selected,se=state('DISPATCH'); resident(selected,se,0)
    assert selected[1]==selected[s['proc_sched_cursor']]==slot
    assert selected[s['proc_timer_clock']]>=ready[s['proc_timer_clock']] and se==ready_extents
    guest,ge=state('GUEST'); resident(guest,ge,slot)
    assert guest[s['proc_current_ptr']]==p
    assert guest[s['proc_timer_clock']]>=selected[s['proc_timer_clock']]
    summary.update(dispatch_tick=selected[s['proc_timer_clock']],guest_tick=guest[s['proc_timer_clock']],
                   first_dispatch=True,checked_waits=result['guest_checked_waits'],
                   final_mm=result['final_mm_verified'],normal_halt=result['normal_halt'])
    return summary


def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','prefix'): p.add_argument(name,type=Path)
    p.add_argument('--scoped',action='store_true',help='only through actual READY publication')
    args=p.parse_args()
    print(json.dumps(verify(args.build,args.work,args.prefix,scoped=args.scoped),indent=2,sort_keys=True))
    print('PASS: actual PI6 and READY publication only' if args.scoped else 'PASS: actual PI6, READY_ONCE, first dispatch, guest data and final MM/HALT')

if __name__=='__main__':
    main()

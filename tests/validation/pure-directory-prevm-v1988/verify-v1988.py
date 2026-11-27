#!/usr/bin/env python3
"""Independently verify one physical terminal pin fault and idle retries."""
import argparse
import json
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE.parent/'pure-directory-lifecycle-v1987/verify-v1987.py'))
words,section,extents,symbols,between=(v[k] for k in ('words','section','extents','symbols','between'))
MASK=0o777777
PIN=1<<21
LIFE=(1<<35)|(1<<33)|(1<<32)
TERM=0o400001


def verify(build,work,baseline,trace=None):
    if trace is None:
        trace=(work/'physical.clean').read_text()
    s=symbols(build/'kcore.map')
    mres=symbols(build/'pure-mres-v1612.map')
    # Strip ONLY the delimited, separately verified fault observation.
    # Preserve the original real k marker and all subsequent lifecycle
    # snapshots for the full, independent v1987 oracle.
    match=re.search(r'(?m)^V1987_FILES_([0-7]+)\n(?=[\s\S]*?^V1988_BACKOFF_CODE\n)',trace)
    assert match
    slot=int(match[1])
    start=match.end()
    end=trace.index('V1988_RELEASE\n',start)+len('V1988_RELEASE\n')
    assert trace.count('V1988_RELEASE\n')==1
    fault=trace[start:end]
    healthy=v['verify'](build,work,baseline,trace[:start]+trace[end:])
    assert slot==healthy['compressed_terminal'][0]
    meta=words(between(trace,'V1941_END_B','V1983_META'))
    modebase=meta[s['proc_storage_runtime_v29']]
    proc=meta[s['proc_table']]+3*slot
    clock=s['proc_timer_clock']
    advance=s['proc_finish_backoff_advance_v885']
    def state(label):
        mm=words(section(trace,label))
        mm.update(words(between(trace,'V1941_END_'+label,'V1983_MAP_'+label)))
        return mm,extents(mm,s,64)
    def identity(d,label):
        ua=d[proc]>>18
        rec=words(between(trace,'V1983_MAP_'+label,'V1987_RECORD_PTR_'+label))[s['proc_swap_records']]+slot
        m=words(between(trace,'V1987_RECORD_PTR_'+label,'V1987_ID_'+label))
        return (ua,m[ua+0o20],m[ua+0o24],m[ua+0o66],m[ua+0o67],m[ua+0o406],m[rec])
    label='TERM_%d'%slot
    d,e=state(label)
    assert d[s['proc_current_slot']]==1
    source,endaddr,kind,pins,owner=next(x for x in e if x[4]==slot and x[2]==4)
    assert kind==4 and pins==0 and owner==slot
    assert source%128==0 and source%1024!=0
    encoded=endaddr-source
    ua,pc,ctl,cred,escrow,backing,record=identity(d,label)
    assert not escrow and backing==record and record
    assert pc&(0o10000<<18) and not ctl&6
    cell=next(s['mm_extents']+2*i+1 for i in range(d[s['mm_extent_count']])
              if d[s['mm_extents']+2*i]&MASK==source)
    orig=d[cell]
    assert orig==(4<<18)|slot
    code=words(between(trace,'V1987_FILES_%d'%slot,'V1988_BACKOFF_CODE'))
    assert code[advance]>>18==0o200200 and code[advance+1]==0o607200400000
    retry=code[advance]&MASK
    assert 0<retry<source
    before=words(between(trace,'V1988_BACKOFF_CODE','V1988_EXTRA_BEFORE'))
    assert not before[retry]>>35
    payload={a:before[a] for a in range(source,endaddr)}
    assert words(between(trace,'V1988_EXTRA_BEFORE','V1988_PIN'))=={cell:orig|PIN}
    term=(meta[s['proc_swap_term_v1666']]&MASK)
    assert term==(d[s['proc_swap_service_one']]&MASK)-mres['proc_pure_mres_service_v1612']+mres['proc_pure_term_v1982']
    assert [int(a,8) for a in re.findall(r'Breakpoint, PC: ([0-7]{6})\b',fault)]==[advance,term,advance,term]
    expected_tag=LIFE|(7<<29)|((source>>7)<<18)|TERM
    expected_span=(encoded<<18)|source
    expected_extents=sorted([x for x in e if x[4]!=slot or x[2]!=4]+[(source,endaddr,4,1,slot)])
    ticks=[]
    previous=d[clock]
    last='V1988_PIN'
    for attempt,interval in ((1,0o20),(2,0o40)):
        for phase,address,delay in (('BACKOFF',advance,interval),('RETRY',term,interval*2)):
            label=phase+str(attempt)
            # No actual guest WAIT or execution marker may occur while held.
            marker=between(trace,last,'V1987_HIT_'+label)
            assert re.fullmatch(r'\s*Breakpoint, PC: %06o\b[^\n]*\s*'%address,marker)
            ac=words(between(trace,'V1987_HIT_'+label,'V1987_AC_'+label))
            if phase=='RETRY':
                assert (ac[1],ac[2],ac[3])==(slot,proc,record)
            dd,ee=state(label)
            assert dd[s['proc_current_slot']]==0
            assert not dd[s['proc_exec_resv_head_v1933']]
            assert all(dd[proc+i]==d[proc+i] for i in range(3))
            assert dd[proc]&0o600000==0o600000
            assert (dd[modebase+slot//18]>>(2*(slot%18)))&3==3
            # Every neighboring MM owner must survive unchanged.
            assert ee==expected_extents
            assert identity(dd,label)==(ua,pc,ctl,cred,expected_tag,backing,record)
            mm=words(between(trace,'V1987_ID_'+label,'V1988_EXTRA_'+label))
            assert mm[ua+0o407]==expected_span
            assert mm[retry]>>18==0o400000|delay
            assert all(mm[a]==payload[a] for a in payload)
            assert (mm[retry]&MASK)==(dd[clock]&0o377777)
            if phase=='BACKOFF':
                assert (dd[clock]-previous)&0o377777>=interval
                previous=dd[clock]
                ticks.append(dd[clock])
            else:
                assert dd[clock]==previous
            last='V1988_EXTRA_'+label
    assert words(between(trace,last,'V1988_RELEASE'))=={cell:orig}
    # Original guest's typed TERM wait and exact owner absence verified
    # by v1987. The private retry word is sampled during both actual
    # attempts, not after successful retirement.
    healthy.update(fault_slot=slot,source=source,encoded=encoded,
                   external_pin_released=True,idle_retry_ticks=ticks,
                   retry_delays=[16,32,64],original_span_preserved=True)
    return healthy


def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','baseline'):
        p.add_argument(name,type=Path)
    a=p.parse_args()
    print(json.dumps(verify(a.build,a.work,a.baseline),indent=2,sort_keys=True))
    print('PASS: physical mode3 terminal pin refusal, idle backoff, exact retirement and lifecycle')


if __name__=='__main__':
    main()

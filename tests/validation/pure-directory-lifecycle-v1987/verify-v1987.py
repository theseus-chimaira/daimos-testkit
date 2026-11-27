#!/usr/bin/env python3
"""Independent offline verifier for actual stopped TERM and restored EXEC."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
words,section,extents,symbols=(v[k] for k in ('words','section','extents','symbols'))
MASK=0o777777
MARK=1<<31

def between(trace,a,b):
    # Labels, not substring prefixes such as TERM_1 versus TERM_10.
    return v['between'](trace,a+'\n',b+'\n')

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def verify(build,work,baseline,trace=None):
    if trace is None: trace=(work/'physical.clean').read_text()
    s=symbols(build/'kcore.map')
    mres=symbols(build/'pure-mres-v1612.map')
    for name in ('kcore.dxr','kinit.lowmem.words','pure-mres-v1612.dxr'):
        assert digest(build/name)==digest(baseline/name)
    hashes={name:d for d,name in (x.split() for x in (work/'images.sha256').read_text().splitlines())}
    assert set(hashes)=={'kcore.dxr','kinit.lowmem.words','pure-mres-v1612.dxr'}
    assert all(digest(build/name)==d for name,d in hashes.items())
    for i in range(3):
        tape='media/dtc%d.tap'%i
        assert digest(build/tape)==digest(work/tape), 'root tape changed'
    paths={}
    for line in (build.parent/'tsfs.manifest').read_text().splitlines():
        f=line.split()
        if f[:2] in (['F','/SYSTEM/INIT'],['F','/SYSTEM/COMP'],['F','/SYSTEM/POST']):
            paths[f[1]]=Path(f[2])
    assert len(paths)==3
    def hdr(p):
        a=p.read_bytes()
        return [int.from_bytes(a[i:i+8],'little') for i in (0,8,16)]
    init,comp,post=(hdr(paths['/SYSTEM/'+x]) for x in ('INIT','COMP','POST'))
    assert init[0]==comp[0] and init[1]|0o100000==comp[1]
    assert init[2]|(1<<35)==comp[2] and not init[2]&(1<<35) and not post[2]&(1<<35)
    assert post[1]!=init[1]
    assert 'MEM                                  64 K' in trace and 'PURE                              LOADED' in trace
    hit=re.search(r'(a{4,12})x\[BV1941_STAGE_B\b',trace)
    assert hit
    children=len(hit[1])
    meta=words(between(trace,'V1941_END_B','V1983_META'))
    modebase,slots=(meta[s['proc_storage_runtime_v29']+i] for i in (0,1))
    table=meta[s['proc_table']]
    assert children+2<=slots<=255
    def state(label):
        mm=words(section(trace,label))
        mm.update(words(between(trace,'V1941_END_'+label,'V1983_MAP_'+label)))
        return mm,extents(mm,s,64)
    def cells(d,slot): return tuple(d[table+3*slot+i] for i in range(3))
    def mode(d,slot): return (d[modebase+slot//18]>>(2*(slot%18)))&3
    def owners(e,slot): return [x for x in e if x[4]==slot and x[2] in (1,4)]
    def ident(d,slot,label):
        ua=cells(d,slot)[0]>>18
        # The previous marker is followed by the actual record pointer
        # read, then the u-area and record words.
        start='V1983_MAP_'+label if not label.startswith('PRESSURE_') else 'V1983_MAP_PRESSURE'
        if label.startswith('PRESSURE_') and slot>2:
            start='V1987_ID_PRESSURE_%d'%(slot-1)
        rec=words(between(trace,start,'V1987_RECORD_PTR_'+label))[s['proc_swap_records']]+slot
        m=words(between(trace,'V1987_RECORD_PTR_'+label,'V1987_ID_'+label))
        return dict(ua=ua,pc=m[ua+0o20],ctl=m[ua+0o24],cred=m[ua+0o66],
                    escrow=m[ua+0o67],backing=m[ua+0o406],record=m[rec])
    def retired(d,e,slot):
        p,vm,sched=cells(d,slot)
        assert not p&0o400000 and sched>>33==0 and mode(d,slot)==0
        assert not owners(e,slot)
        assert not any(x[2]==3 and x[4]==0o1000+slot for x in e)
    def at(label,pc):
        # Actual stop must immediately precede the monitor-owned HIT label.
        assert re.search(r'Breakpoint, PC: %06o\b[^\n]*\nV1987_HIT_%s\n'%(pc,label),trace)
        return words(between(trace,'V1987_HIT_'+label,'V1987_AC_'+label))
    p,pe=state('PRESSURE')
    assert all(p[a]==x for a,x in words(section(trace,'B')).items())
    assert p[s['proc_current_slot']]==1 and p[s['proc_high_slot']]==children+2
    assert not p[s['proc_exec_resv_head_v1933']]
    service=p[s['proc_swap_service_one']]
    assert service>>18==0o254000
    base=(service&MASK)-mres['proc_pure_mres_service_v1612']
    assert p[s['proc_swap_reclaim']]==(0o254000<<18)|(base+mres['proc_pure_mres_reclaim_v1612'])
    term=base+mres['proc_pure_term_v1982']
    fullpc=base+mres['proc_pure_bitmap_restore_v1980']
    finishpc=base+mres['mm_pure_bitmap_finish_v1664']
    assert meta[s['proc_swap_term_v1666']]==(0o254000<<18)|term
    initial={}
    for slot in range(2,children+2):
        pm,vm,sc=cells(p,slot); md=mode(p,slot)
        assert pm&0o600000==0o400000 and sc>>33==(3 if slot<4 else 6)
        o=owners(pe,slot)
        assert len(o)==1 and o[0][3]==0
        assert (pm>>18,(pm>>18)+0o410,3,0,0o1000+slot) in pe
        assert (md==0 and o[0][2]==1 and vm&MASK==o[0][0] and vm>>18==o[0][1]-o[0][0] or
                md in (2,3) and o[0][2]==4 and not vm&MASK)
        id=ident(p,slot,'PRESSURE_%d'%slot)
        assert bool(id['cred']&MARK)==(slot!=2)
        assert id['record'] and not id['escrow'] and id['backing']==(id['record'] if md else 0)
        if slot>=4: assert id['pc']&(0o10000<<18) and not (sc>>18)&0o60000
        initial[slot]=(md,o[0],id)
    assert initial[2][0]==2 and initial[3][0]==3
    nonresident=[i for i in initial if i>=4 and initial[i][0] in (2,3)]
    packed=[i for i in nonresident if initial[i][0]==3]
    assert packed
    # Require exactly the original nonresident terminal entries, no
    # restore before parent completed all TERM waits.
    expected=[term]*len(nonresident)+[fullpc,finishpc,s['exec_replace_current'],s['proc_exec_enter']]
    assert [int(a,8) for a in re.findall(r'Breakpoint, PC: ([0-7]{6})\b',trace)]==expected
    last='V1987_ID_PRESSURE_%d'%(children+1)
    k_count=0
    for slot in nonresident:
        label='TERM_%d'%slot
        ac=at(label,term)
        d,e=state(label)
        assert d[s['proc_current_slot']]==1 and ac[1]==slot and ac[2]==table+3*slot
        assert not d[s['proc_exec_resv_head_v1933']]
        pm,vm,sc=cells(d,slot)
        md,owner,old=initial[slot]
        assert pm&0o600000==0o600000 and sc>>33==6 and not (sc>>18)&0o60000
        assert mode(d,slot)==md and not vm&MASK and owners(e,slot)==[owner]
        id=ident(d,slot,label)
        assert id['ua']==old['ua'] and id['pc']==old['pc'] and id['cred']==old['cred']
        assert id['backing']==id['record']==old['record']==ac[3] and not id['ctl']&6
        f=words(between(trace,'V1987_ID_'+label,'V1987_FILES_%d'%slot))
        assert all(not f[id['ua']+0o26+2*i] for i in range(16))
        marker=between(trace,'V1987_FILES_%d'%slot,'V1941_STAGE_K_%d'%slot)
        assert re.fullmatch(r'kV1987_K_%d\s*'%slot,marker.strip())
        tail=between(trace,last,'V1987_HIT_'+label)
        # Guest markers before the next breakpoint can only be earlier
        # resident children whose typed TERM WAIT has completed.
        stop=re.fullmatch(r'(k*)\s*Breakpoint, PC: [^\n]+\s*',tail.strip())
        assert stop
        k_count+=len(stop[1])+1
        kd,ke=state('K_%d'%slot)
        retired(kd,ke,slot)
        last='V1983_MAP_K_%d'%slot
    tail=between(trace,last,'V1941_STAGE_L')
    m=re.fullmatch(r'(k*)LV1987_L\s*',tail.strip())
    assert m and k_count+len(m[1])==children-2
    d,e=state('L')
    for slot in range(4,children+2): retired(d,e,slot)
    assert mode(d,3)==3 and owners(e,3)==[initial[3][1]]
    assert d[s['proc_current_slot']]==1
    assert re.fullmatch(r'w\s*Breakpoint, PC: [^\n]+\s*',between(trace,'V1983_MAP_L','V1987_HIT_RESTORE').strip())
    ac=at('RESTORE',fullpc); d,e=state('RESTORE')
    assert ac[1]==3 and d[s['proc_current_slot']]==0
    assert mode(d,3)==3 and owners(e,3)==[initial[3][1]]
    assert cells(d,3)[0]&0o200000
    ac=at('FINISH',finishpc); d,e=state('FINISH')
    slot,source,encoded,target=(ac[i] for i in range(1,5))
    full=cells(d,3)[1]>>18
    assert slot==3 and d[s['proc_current_slot']]==0 and mode(d,3)==3
    assert initial[3][1]==(source,source+encoded,4,0,3)
    assert owners(e,3)==sorted([(source,source+encoded,4,1,3),(target,target+full,1,1,3)])
    assert target%1024==0 and full%1024==0 and (source+encoded<=target or target+full<=source)
    ac=at('EXEC',s['exec_replace_current']); d,e=state('EXEC')
    assert d[s['proc_current_slot']]==3 and mode(d,3)==0 and cells(d,3)[1]==(full<<18)|target
    assert owners(e,3)==[(target,target+full,1,0,3)]
    assert cells(d,3)[0]&0o600000==0o400000
    old=ident(d,3,'EXEC')
    assert old['cred']&MARK and old['record']==initial[3][2]['record'] and not old['backing'] and not old['escrow']
    assert re.fullmatch(r'wE\s*Breakpoint, PC: [^\n]+\s*',between(trace,'V1983_MAP_FINISH','V1987_HIT_EXEC').strip())
    ac=at('ENTER',s['proc_exec_enter']); d,e=state('ENTER')
    assert ac[1]==symbols(build.parent/'user/post.map')['_start'] and ac[3]==1
    new=ident(d,3,'ENTER')
    assert d[s['proc_current_slot']]==3 and mode(d,3)==0 and new['ua']==old['ua']
    assert new['record'] and new['record']!=old['record'] and not new['cred']&MARK
    assert not new['escrow'] and not new['backing'] and not d[s['proc_exec_resv_head_v1933']]
    pm,vm,sc=cells(d,3)
    assert pm&0o600000==0o400000 and sc>>33==2
    assert owners(e,3)==[(vm&MASK,(vm&MASK)+(vm>>18),1,0,3)]
    assert re.fullmatch(r'X\s*',v['between'](trace,'V1987_ID_ENTER\n','V1987_X'))
    d,e=state('X')
    assert d[s['proc_current_slot']]==3 and mode(d,3)==0
    assert re.search(r'(?m)^Z\s*V1983_Z_STOP',trace)
    v['verify_final'](build,work,{},trace)
    return dict(children=children,stopped_term_waits=children-2,compressed_terminal=packed,
                restored_exec_slot=3,original_bitmap_words=encoded,old_record=old['record'],
                new_record=new['record'],old_apr_words=full,new_apr_words=vm>>18,
                final_mm=True,normal_halt=True)

def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','baseline'): p.add_argument(name,type=Path)
    args=p.parse_args()
    print(json.dumps(verify(args.build,args.work,args.baseline),indent=2,sort_keys=True))
    print('PASS: actual stopped mode3 terminal, restored EXEC and final MM/HALT')
if __name__=='__main__':
    main()

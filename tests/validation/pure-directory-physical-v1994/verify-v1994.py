#!/usr/bin/env python3
"""Independent offline audit of actual bounded dirty DROP rollback."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE.parent/'pure-directory-lifecycle-v1987/verify-v1987.py'))
words,extents,symbols,between=(v[k] for k in ('words','extents','symbols','between'))
MASK=0o777777


def verify(build,work,trace=None):
    if trace is None:
        trace=(work/'physical.clean').read_text()
    s=symbols(build/'kcore.map')
    mres=symbols(build/'pure-mres-v1612.map')
    digest=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    hashes={name:d for d,name in (line.split() for line in (work/'images.sha256').read_text().splitlines())}
    assert set(hashes)=={'kcore.dxr','kinit.lowmem.words','pure-mres-v1612.dxr'}
    assert all(digest(build/name)==d for name,d in hashes.items())
    for i in range(3):
        name='media/dtc%d.tap'%i
        assert digest(build/name)==digest(work/name)
    assert 'MEM                                  64 K' in trace and 'PURE                              LOADED' in trace
    assert 'QV1941_STAGE_Q' in trace and 'x[BV1941_STAGE_B' in trace
    assert 'SIGTERM' not in trace
    lines=trace.splitlines()
    labels={}
    for i,line in enumerate(lines):
        if line.startswith(('V1991_','V1994_','V1987_','V1983_')):
            assert line not in labels,line
            labels[line]=i
    def read(label):
        pos=labels[label]
        out=[]
        for line in reversed(lines[:pos]):
            if re.fullmatch(r'\s*[0-7]{1,7}:\s*[0-7]{1,12}\s*',line):
                out.append(line)
            elif not line.strip():
                continue
            else:
                break
        assert out,label
        return words('\n'.join(reversed(out)))
    def obs(label): return read('V1991_'+label)
    q=words(between(trace,'V1941_STAGE_Q','V1941_END_Q'))
    meta=read('V1994_EARLY_META')
    assert meta==read('V1983_META')
    table=meta[s['proc_table']]
    modebase=meta[s['proc_storage_runtime_v29']]
    nslots=meta[s['proc_storage_runtime_v29']+1]
    service=q[s['proc_swap_service_one']]
    base=(service&MASK)-mres['proc_pure_mres_service_v1612']
    assert service>>18==0o254000 and base>=s['__kcore_low_end']
    assert q[s['proc_swap_reclaim']]==(0o254000<<18)|(base+mres['proc_pure_mres_reclaim_v1612'])
    def mpc(name): return base+mres[name]
    def state(label):
        mm=words(between(trace,'V1941_STAGE_'+label,'V1941_END_'+label))
        mm.update(words(between(trace,'V1941_END_'+label,'V1983_MAP_'+label)))
        return mm,extents(mm,s,64)
    def cells(d,slot): return tuple(d[table+3*slot+i] for i in range(3))
    def mode(d,slot): return (d[modebase+slot//18]>>(2*(slot%18)))&3
    def owners(e,slot): return [x for x in e if x[4]==slot and x[2] in (1,4)]
    def at(label,pc):
        assert re.search(r'Breakpoint, PC: %06o\b[^\n]*\nV1987_HIT_%s\n'%(pc,label),trace),label
        return words(between(trace,'V1987_HIT_'+label,'V1987_AC_'+label))
    def ret(label):
        sp=obs('STACK_'+label)[0o17]&MASK
        return obs('RETURN_'+label)[sp]&MASK
    def identity(d,slot,label):
        ua=cells(d,slot)[0]>>18
        rec=read('V1987_RECORD_PTR_'+label)[s['proc_swap_records']]+slot
        m=read('V1987_ID_'+label)
        return tuple(m[ua+i] for i in (0o20,0o24,0o66,0o67,0o406))+(m[rec],)
    ac=at('ENCODE',mpc('pbmd_encode_v1977'))
    source,raw,apr,skip=(ac[i] for i in range(1,5))
    full=raw+skip
    slot=3
    assert source==apr+skip and apr%1024==0 and skip%128==0 and full%1024==0
    d,e=state('ENCODE')
    ua=cells(d,slot)[0]>>18
    assert d[s['proc_current_slot']]==1 and mode(d,slot)==0
    assert cells(d,slot)[0]&0o600000==0o600000
    assert cells(d,slot)[1]==(full<<18)|apr
    assert owners(e,slot)==[(apr,apr+full,1,1,slot)]
    old=identity(d,slot,'ENCODE')
    assert old[2]&(1<<31) and old[3]==(0o13<<29)|((source>>7)<<18)
    assert not old[4] and old[5]
    assert ((old[5]>>22)&0o37777)+0o20 & ~0o177==skip
    advance=s['proc_finish_backoff_advance_v885']
    code=obs('BACKOFF_CODE')
    assert code[advance]>>18==0o200200 and code[advance+1]==0o607200400000
    retry=code[advance]&MASK
    init=obs('INITIAL')
    heap=init[ua+0o407]
    assert not init[retry]>>35
    payload=obs('RAW_ENCODE')
    assert set(payload)==set(range(source,source+raw))
    original=obs('PREFIX_ORIGINAL')
    dirty=obs('PREFIX_DIRTY')
    assert set(original)==set(dirty)==set(range(apr,source))
    walk=obs('WALK_CODE')
    patch,=[a+1 for a,x in walk.items() if x==0o202343000000]
    invalid,=[a for a,x in walk.items() if x==0o211040000004]
    assert mpc('pbmd_walk_v1977')<patch<invalid<mpc('pbmd_walk_v1977')+0o220
    assert walk[patch]>>18==0o254000
    ac=at('AFTER_STORE',patch)
    assert [a for a in original if original[a]!=dirty[a]]==[ac[3]]
    assert dirty[ac[3]]==payload[ac[1]-1]
    assert state('AFTER_STORE')[1]==e and obs('RAW_AFTER_STORE')==payload
    assert obs('PATCH_CODEC')=={patch:(0o254000<<18)|invalid}
    assert at('ENCODE_FAILED',ret('ENCODE'))[1]==(1<<36)-6
    assert obs('RESTORED_CODEC')=={patch:walk[patch]}
    assert state('ENCODE_FAILED')[1]==e and obs('RAW_ENCODE_FAILED')==payload
    assert obs('PREFIX_FAILED')==dirty
    def held(label,phase,packed=False,pin=1,clean=False):
        dd,ee=state(label)
        pm,vm,sc=cells(dd,slot)
        assert pm>>18==ua and bool(pm&0o200000)==(not clean)
        assert sc>>33 in (2,3,6)
        assert mode(dd,slot)==(2 if packed else 0)
        assert vm==(full<<18)|(0 if packed else apr)
        assert owners(ee,slot)==[(source if packed else apr,apr+full,4 if packed else 1,pin,slot)]
        assert (ua,ua+0o410,3,0,0o1000+slot) in ee
        id=identity(dd,slot,label)
        tag=((0o13 if phase else 3)<<29)|((source>>7)<<18)|0o600000|\
            ((full>>10)<<7)|(((old[2]>>27)&0o37)<<2)|phase
        assert id[:3]==old[:3] and id[4:]==(old[5],old[5])
        assert id[3]==(0 if clean else tag)
        xx=obs('EXTRA_'+label)
        assert xx[ua+0o407]==heap and not xx[s['proc_sched_cursor']]&0o1000
        assert obs('RAW_'+label)==payload
        return dd,ee,xx
    rebase=mpc('mm_pure_rebase_pinned_v1381')
    unpin=s['mm_unpin']
    recover=mpc('proc_pure_dirty_recover_v1993')
    faultpcs=[]
    for label,pc,packed in [('REBASE_INITIAL',rebase,False),('REBASE_RETRY',rebase,False),
                             ('UNPIN_INITIAL',unpin,True),('UNPIN_RETRY',unpin,True)]:
        ac=at(label,pc)
        assert (ac[1]==source if packed else tuple(ac[i] for i in range(1,5))==(apr,slot,skip,full))
        _,ee,_=held(label,0,packed)
        original_op=obs('ORIGINAL_'+label)
        assert set(original_op)=={pc} and original_op[pc]!=(0o254000<<18)|s['kret_neg1']
        assert obs('PATCH_'+label)=={pc:(0o254000<<18)|s['kret_neg1']}
        r=ret(label)
        assert at('REFUSED_'+label,r)[1]==(1<<36)-1
        assert obs('RESTORED_'+label)==original_op
        _,after,_=held('REFUSED_'+label,0,packed)
        assert ee==after
        faultpcs.append((pc,r))
    assert at('ARM',s['proc_pure_recover_arm_v1902'])[1]==ua
    armed,_,xx=held('ARM',0)
    assert not xx[retry]>>35
    previous=armed[s['proc_timer_clock']]&0o377777
    ticks=[]
    for i,delay in enumerate((16,32,64,128),1):
        packed=i>=3
        phase=2 if packed else 1
        at('BACKOFF%d'%i,advance)
        dd,_,xx=held('BACKOFF%d'%i,phase,packed)
        tick=dd[s['proc_timer_clock']]&0o377777
        assert dd[s['proc_current_slot']]==0 and (tick-previous)&0o377777>=delay
        assert xx[retry]==((0o400000|delay)<<18)|tick
        assert at('RECOVER%d'%i,recover)[1]==slot
        dd,_,xx=held('RECOVER%d'%i,phase,packed)
        assert dd[s['proc_current_slot']]==0 and xx[retry]==((0o400000|delay*2)<<18)|tick
        ticks.append(tick); previous=tick
    finalret=ret('RECOVER4')
    assert at('RECOVERED',finalret)[1]==0
    held('RECOVERED',0,True,0,True)
    p,pe=state('PRESSURE')
    children=p[s['proc_high_slot']]-2
    assert 4<=children<=12 and p[s['proc_current_slot']]==1
    assert mode(p,slot)==2 and not cells(p,slot)[0]&0o200000
    own,=owners(pe,slot)
    assert own[1]-own[0]==raw and own[2:]==(4,0,slot)
    assert list(obs('RAW_PRESSURE').values())==list(payload.values())
    restore=mpc('proc_pure_restore_v1384')
    restorepcs=[]
    for i in range(1,9):
        label='RAW_RESTORE%d'%i
        if 'V1987_HIT_'+label+'\n' not in trace: break
        ac=at(label,restore)
        restorepcs.append(restore)
        dd,ee=state(label)
        assert dd[s['proc_current_slot']]==0 and ac[1] in (2,slot)
        if ac[1]==slot:
            assert mode(dd,slot)==2 and len(owners(ee,slot))==1
            assert list(obs('RAW_RESTORE').values())==list(payload.values())
            break
        r=ret(label)
        at('PEER_RETURN%d'%i,r)
        restorepcs.append(r)
    else:
        raise AssertionError('missing victim restore')
    assert ac[1]==slot
    at('EXEC',s['exec_replace_current'])
    dd,ee=state('EXEC')
    assert dd[s['proc_current_slot']]==slot and mode(dd,slot)==0
    assert cells(dd,slot)[0]>>18==ua and not cells(dd,slot)[0]&0o200000
    assert identity(dd,slot,'EXEC')[3:]==(0,0,old[5])
    at('ENTER',s['proc_exec_enter'])
    dd,ee=state('ENTER')
    new=identity(dd,slot,'ENTER')
    assert cells(dd,slot)[0]>>18==ua and new[5]!=old[5] and new[5]
    assert not new[2]&(1<<31) and not new[3] and not new[4]
    expected=[mpc('pbmd_encode_v1977'),patch,ret('ENCODE'),*faultpcs[0],
              s['proc_pure_recover_arm_v1902'],advance,recover,*faultpcs[1],
              advance,recover,*faultpcs[2],advance,recover,*faultpcs[3],
              advance,recover,finalret,*restorepcs,s['exec_replace_current'],s['proc_exec_enter']]
    assert [int(a,8) for a in re.findall(r'Breakpoint, PC: ([0-7]{6})\b',trace)]==expected
    # Count actual guest markers across the monitor stops. The guest
    # emits k only after exact TERM WAIT, w only after sparse-data check.
    tail=trace.split('V1983_MAP_PRESSURE\n',1)[1]
    assert re.search(r'(?m)^k{%d}L'% (children-2),tail)
    assert re.search(r'(?m)^X\s*V1987_X',tail) and re.search(r'(?m)^Z\s*V1983_Z_STOP',tail)
    v['v']['verify_final'](build,work,{},trace)
    return dict(slot=slot,apr=apr,full=full,raw=raw,source=source,
                children=children,ticks=ticks,scoped_faults=5,partial_stores=1,
                raw_preserved=True,exec_verified=True,final_mm=True,normal_halt=True)


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('build',type=Path);p.add_argument('work',type=Path)
    a=p.parse_args()
    print(json.dumps(verify(a.build,a.work),indent=2,sort_keys=True))
    print('PASS v1994 independent dirty DROP and lifecycle audit')

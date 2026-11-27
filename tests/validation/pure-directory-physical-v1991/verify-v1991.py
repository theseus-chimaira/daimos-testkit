#!/usr/bin/env python3
"""Independent offline fault and lifecycle witnesses for v1991."""
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

def section(trace,label):
    # FINISH and FINISH_RETRY are distinct complete monitor labels.
    return between(trace,'V1941_STAGE_'+label,'V1941_END_'+label)

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def verify(build,work,baseline,trace=None):
    if trace is None:
        trace=(work/'physical.clean').read_text()
    s=symbols(build/'kcore.map')
    mres=symbols(build/'pure-mres-v1612.map')
    assert digest(build/'kcore.dxr')==digest(baseline/'kcore.dxr')
    assert digest(build/'pure-mres-v1612.dxr')!=digest(baseline/'pure-mres-v1612.dxr')
    # Check the actual manifest paths, not just the convenience
    # symlink to the accepted v1987 guest directory.
    paths={}
    for line in (build.parent/'tsfs.manifest').read_text().splitlines():
        f=line.split()
        if f[:2] in (['F','/SYSTEM/INIT'],['F','/SYSTEM/COMP'],['F','/SYSTEM/POST']):
            assert f[1] not in paths
            paths[f[1]]=Path(f[2])
    assert len(paths)==3
    for name in ('init','comp','post'):
        assert digest(paths['/SYSTEM/'+name.upper()])==digest(baseline.parent/'user'/(name+'.dxr'))
        assert digest(build.parent/'user'/(name+'.dxr'))==digest(paths['/SYSTEM/'+name.upper()])
    meta=words(between(trace,'V1941_END_B','V1983_META'))
    table=meta[s['proc_table']]
    proc=table+9
    modebase=meta[s['proc_storage_runtime_v29']]
    def state(label):
        mm=words(section(trace,label))
        mm.update(words(between(trace,'V1941_END_'+label,'V1983_MAP_'+label)))
        return mm,extents(mm,s,64)
    def cells(d):
        return tuple(d[proc+i] for i in range(3))
    def mode(d):
        return (d[modebase]>>6)&3
    def owners(e):
        return [x for x in e if x[4]==3 and x[2] in (1,4)]
    def at(label,pc):
        assert re.search(r'Breakpoint, PC: %06o\b[^\n]*\nV1987_HIT_%s\n'%(pc,label),trace)
        return words(between(trace,'V1987_HIT_'+label,'V1987_AC_'+label))
    def read(label):
        # A monitor examine marker is unique and ends its address dump.
        # The preceding monitor label or breakpoint separates it.
        end=trace.index('V1991_'+label+'\n')
        assert trace.count('V1991_'+label+'\n')==1
        lines=trace[:end].splitlines()
        block=[]
        for line in reversed(lines):
            if re.fullmatch(r'\s*[0-7]{1,7}:\s*[0-7]{1,12}\s*',line):
                block.append(line)
            elif not line.strip():
                continue
            else:
                break
        assert block,label
        return words('\n'.join(reversed(block)))
    def identity(d,label):
        ua=cells(d)[0]>>18
        # ORIGINAL and INITIAL are read after the FINISH MM snapshot.
        ptr=read_label('V1987_RECORD_PTR_'+label)
        rec=ptr[s['proc_swap_records']]+3
        m=words(between(trace,'V1987_RECORD_PTR_'+label,'V1987_ID_'+label))
        return (ua,m[ua+0o20],m[ua+0o24],m[ua+0o66],m[ua+0o67],m[ua+0o406],m[rec])
    def read_label(label):
        end=trace.index(label+'\n')
        assert trace.count(label+'\n')==1
        return words('\n'.join(trace[:end].splitlines()[-2:]))
    d,e=state('FINISH')
    base=(d[s['proc_swap_service_one']]&MASK)-mres['proc_pure_mres_service_v1612']
    finish=base+mres['mm_pure_bitmap_finish_v1664']
    fullpc=base+mres['proc_pure_bitmap_restore_v1980']
    recover=base+mres['proc_pure_bitmap_recover_v1989']
    arm=base+mres['proc_pure_bitmap_arm_v1990']
    unpin=s['mm_unpin']
    advance=s['proc_finish_backoff_advance_v885']
    ac=at('FINISH',finish)
    slot,source,n,target=(ac[i] for i in range(1,5))
    assert slot==3 and target%1024==0 and source%128==0 and n>0
    full=cells(d)[1]>>18
    assert full%1024==0 and full>n
    original=cells(d)
    ua=original[0]>>18
    assert original[0]&0o600000==0o600000 and mode(d)==3
    assert original[1]&MASK==0
    assert owners(e)==sorted([(source,source+n,4,1,3),(target,target+full,1,1,3)])
    ident=identity(d,'ORIGINAL')
    assert ident[5]==ident[6]!=0 and ident[3]&(1<<31)
    code=read('BACKOFF_CODE')
    assert code[advance]>>18==0o200200 and code[advance+1]==0o607200400000
    retry=code[advance]&MASK
    x=read('EXTRA_ORIGINAL')
    heap=x[ua+0o407]&~(0o1777<<18)
    assert heap==(full<<18)|full
    assert not x[retry]>>35
    payload={a:x[a] for a in range(source,source+n)}
    clock=s['proc_timer_clock']
    cursor=s['proc_sched_cursor']
    pressure=s['proc_swap_pressure_ticks']
    # Preserve the entire MM table and process identity throughout hold.
    def held(label,phase):
        dd,ee=state(label)
        assert dd[s['proc_current_slot']]==0 and mode(dd)==3 and cells(dd)==original
        assert ee==e, label
        assert (ua,ua+0o410,3,0,0o1003) in ee
        assert dd[s['proc_exec_resv_head_v1933']]==0
        ii=identity(dd,label)
        tag=((3 if phase==1 else 0o13)<<29)|((source>>7)<<18)|(phase<<15)|n
        assert ii[:4]==ident[:4] and ii[5:]==ident[5:] and ii[4]==tag
        xx=read('EXTRA_'+label)
        assert xx[ua+0o407]==heap|((0o1000|(target>>10))<<18)
        assert all(xx[a]==payload[a] for a in payload)
        assert not xx[cursor]&0o1000
        return dd,xx
    initial=identity(d,'INITIAL')
    assert initial==ident
    assert ident[4]==(3<<29)|((source>>7)<<18)|(1<<15)|n
    assert read('EXTRA_INITIAL')[ua+0o407]==heap|((0o1000|(target>>10))<<18)
    # Verify exactly three scoped one-call MM refusals, every original
    # instruction restored and return PC taken from the live stack.
    patched=(0o254000<<18)|s['kret_neg1']
    returns=[]
    for label,pc in (('FINISH',finish),('UNPIN_INITIAL',unpin),('UNPIN_RETRY',unpin)):
        orig=read('ORIGINAL_'+label)
        assert set(orig)=={pc} and orig[pc]!=patched
        if pc==finish:
            assert orig[pc]==0o200257777777 # MOVE 5,-1(17)
        else:
            assert orig[pc]==0o474100000000 # SETO 2,
        sp=read('STACK_'+label)[0o17]&MASK
        ret=read('RETURN_'+label)[sp]&MASK
        assert ret!=pc
        assert read('PATCH_'+label)=={pc:patched}
        assert at('REFUSED_'+label,ret)[1]==(1<<36)-1
        assert read('RESTORED_'+label)==orig
        held('REFUSED_'+label,1)
        returns.append(ret)
    for label in ('UNPIN_INITIAL','UNPIN_RETRY'):
        assert at(label,unpin)[1]==target
        held(label,1)
    assert at('ARM',arm)[1]==3
    dd,xx=held('ARM',2)
    assert not xx[retry]>>35
    assert at('FIXED_ARM',s['proc_pure_recover_arm_v1902'])[1]==ua
    armed,xx=held('FIXED_ARM',2)
    ticks=[]
    for i,delay in ((1,0o20),(2,0o40)):
        at('BACKOFF%d'%i,advance)
        dd,xx=held('BACKOFF%d'%i,2)
        assert xx[retry]==((0o400000|delay)<<18)|(dd[clock]&0o377777)
        prev=armed[clock] if i==1 else ticks[-1]
        assert (dd[clock]-prev)&0o377777>=delay
        ticks.append(dd[clock])
        assert at('RECOVER%d'%i,recover)[1]==3
        dd,xx=held('RECOVER%d'%i,2)
        assert xx[retry]>>18==0o400000|delay*2
        assert xx[retry]&MASK==ticks[-1]&0o377777
        assert xx[pressure]<=0o100
    sp=read('STACK_RECOVER2')[0o17]&MASK
    ret=read('RETURN_RECOVER2')[sp]&MASK
    assert at('RECOVERED',ret)[1]==0
    dd,ee=state('RECOVERED')
    assert dd[s['proc_current_slot']]==0 and mode(dd)==3
    assert cells(dd)==(original[0]&~0o200000,original[1],original[2])
    expected=sorted([x for x in e if x not in ((target,target+full,1,1,3),(source,source+n,4,1,3))]+[(source,source+n,4,0,3)])
    assert ee==expected
    ii=identity(dd,'RECOVERED')
    assert ii[:4]==ident[:4] and not ii[4] and ii[5:]==ident[5:]
    xx=read('EXTRA_RECOVERED')
    assert xx[ua+0o407]==heap and not xx[cursor]&0o1000
    assert all(xx[a]==payload[a] for a in payload)
    assert at('RESTORE_RETRY',fullpc)[1]==3
    dd,ee=state('RESTORE_RETRY')
    assert mode(dd)==3 and dd[s['proc_current_slot']]==0 and owners(ee)==[(source,source+n,4,0,3)]
    xx=read('EXTRA_RESTORE_RETRY')
    assert not xx[retry]>>18 and xx[ua+0o407]==heap
    assert all(xx[a]==payload[a] for a in payload)
    ac=at('FINISH_RETRY',finish)
    assert (ac[1],ac[2],ac[3])==(3,source,n)
    # Remove only the fault observation from the healthy lifecycle
    # oracle, replacing the first finish with the actual second one.
    a=re.search(r'Breakpoint, PC: %06o\b[^\n]*\nV1987_HIT_FINISH\n'%finish,trace)
    b=re.search(r'Breakpoint, PC: %06o\b[^\n]*\nV1987_HIT_FINISH_RETRY\n'%finish,trace)
    assert a and b and a.start()<b.start()
    fault=trace[a.start():b.start()]
    expected_pcs=[finish,returns[0],unpin,returns[1],arm,s['proc_pure_recover_arm_v1902'],
                  advance,recover,unpin,returns[2],advance,recover,ret,fullpc]
    assert [int(x,8) for x in re.findall(r'Breakpoint, PC: ([0-7]{6})\b',fault)]==expected_pcs
    # No guest output marker is allowed during failure/rollback.
    assert not re.search(r'(?m)^[wEkXZ!]+(?:V[0-9]+_|\s*$)',fault)
    healthy=trace[:a.start()]+trace[b.start():].replace('FINISH_RETRY','FINISH')
    result=v['verify'](build,work,build,healthy)
    # Report actual pressure, not an extrapolation from package words.
    pp,pe=state('PRESSURE')
    gaps=[]
    for i in range(pp[s['mm_arena_count']]):
        arena=pp[s['mm_arenas']+i]
        lo=arena&MASK
        end=lo+(arena>>18)
        pos=lo
        for a,z,*_ in pe:
            if lo<=a<end:
                if pos<a: gaps.append((pos,a))
                pos=z
        if pos<end: gaps.append((pos,end))
    result.update(pressure_free=sum(z-a for a,z in gaps),
                  pressure_largest_apr_aligned=max([0]+[max(0,z-((a+1023)//1024*1024)) for a,z in gaps]),
                  pressure_descriptors=len(pe),
                  pressure_packed=[dict(slot=x[4],base=x[0],words=x[1]-x[0])
                                   for x in pe if x[2]==4])
    result.update(source=source,encoded=n,first_target=target,retry_ticks=ticks,
                  original_heap=heap,physical_rollback=True,scoped_refusals=3)
    return result

def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','baseline'):
        p.add_argument(name,type=Path)
    a=p.parse_args()
    print(json.dumps(verify(a.build,a.work,a.baseline),indent=2,sort_keys=True))
    print('PASS v1991 physical FULL rollback and complete lifecycle')

if __name__=='__main__':
    main()

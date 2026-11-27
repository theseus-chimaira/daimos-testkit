#!/usr/bin/env python3
"""Independent read-only pressure-state accounting for RAW and directory."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy

previous = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                              'pure-k07-full-v1941/verify-v1941.py'))
symbols, words, section, extents = (previous[k] for k in
                                   ('symbols', 'words', 'section', 'extents'))
MASK = 0o777777


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def between(trace, a, b):
    assert trace.count(a) == trace.count(b) == 1, (a, b)
    start, end = trace.index(a), trace.index(b)
    assert start < end
    return trace[start+len(a):end]


def fixture(build):
    # The disposable media manifest includes the independently linked COMP.
    paths = {}
    for line in (build.parent/'tsfs.manifest').read_text().splitlines():
        fields = line.split()
        if fields[:2] in (['F', '/SYSTEM/INIT'], ['F', '/SYSTEM/COMP']):
            paths[fields[1]] = Path(fields[2])
    assert set(paths) == {'/SYSTEM/INIT', '/SYSTEM/COMP'}
    init, comp = (paths[k] for k in ('/SYSTEM/INIT', '/SYSTEM/COMP'))
    def header(path):
        raw = path.read_bytes()[:24]
        assert len(raw) == 24
        return [int.from_bytes(raw[i:i+8], 'little') for i in range(0, 24, 8)]
    a, c = header(init), header(comp)
    assert a[0] == c[0] and a[1] | 0o100000 == c[1]
    assert not a[2] & (1<<35) and a[2] | (1<<35) == c[2]
    skip = ((a[2] >> 18) + 0o20) & ~0o177
    return skip, [digest(init), digest(comp)]


def verify(build, work, raw=False, trace=None):
    s = symbols(build/'kcore.map')
    mres = symbols(build/'pure-mres-v1612.map')
    if trace is None:
        f = work/'physical.clean'
        trace = (f if f.exists() else work/'physical.log').read_text()
    hashes = dict((name, value) for value, name in
                  (line.split() for line in (work/'images.sha256').read_text().splitlines()))
    assert set(hashes) == {'kcore.dxr', 'pure-mres-v1612.dxr', 'kinit.lowmem.words'}
    assert all(digest(build/name) == value for name,value in hashes.items())
    assert 'MEM                                  64 K' in trace
    assert 'PURE                              LOADED' in trace
    hit = re.search(r'(a{4,12})x\[BV1941_STAGE_B\b', trace)
    assert hit, 'no genuine pressure marker'
    children = len(hit.group(1))
    assert 'SIGTERM' not in trace[:trace.index('V1983_MAP_PRESSURE')]
    before = words(section(trace, 'B'))
    mm = words(section(trace, 'PRESSURE'))
    meta = words(between(trace, 'V1941_END_B', 'V1983_META'))
    cells = words(between(trace, 'V1941_END_PRESSURE', 'V1983_MAP_PRESSURE'))
    assert before == mm, 'MM changed while monitor held'
    rt = s['proc_storage_runtime_v29']
    modebase, slots = meta[rt], meta[rt+1]
    table = meta[s['proc_table']]
    assert 0 < modebase < 65536 and 0 < table < 65536
    assert children+2 <= slots <= 255
    assert mm[s['proc_current_slot']] == 1
    assert mm[s['proc_high_slot']] == children+2
    assert mm[s['proc_exec_resv_head_v1933']] == 0
    assert mm[s['mm_extent_capacity']] == 40
    installed = mm[s['proc_swap_service_one']]
    assert installed >> 18 == 0o254000
    base = (installed & MASK)-mres['proc_pure_mres_service_v1612']
    assert base >= s['__kcore_low_end']
    assert mm[s['proc_swap_reclaim']] == (0o254000<<18)|(base+mres['proc_pure_mres_reclaim_v1612'])
    term = 'pdp6_pure_detach_v1609' if raw else 'proc_pure_term_v1982'
    assert meta[s['proc_swap_term_v1666']] == (0o254000<<18)|(base+mres[term])
    e = extents(mm,s,64)
    skip, fixtures = fixture(build)
    packed = []
    raw_words = []
    resident = []
    for slot in range(1,slots):
        mode = (cells[modebase+slot//18]>>(2*(slot%18)))&3
        p, vm, sched = (cells[table+3*slot+i] for i in range(3))
        owner = [x for x in e if x[4]==slot and x[2] in (1,4)]
        if slot >= children+2:
            assert mode == 0 and not owner and sched>>33 == 0
            continue
        assert p&0o400000 and not p&0o200000, 'not stable u-area owner'
        ua = p>>18
        assert (ua,ua+0o410,3,0,0o1000+slot) in e
        assert len(owner)==1
        lo,hi,kind,pin,_ = owner[0]
        full = vm>>18
        assert full and full%1024==0 and pin==0
        if slot == 1:
            assert mode==0 and kind==1 and lo==vm&MASK and hi-lo==full
            continue
        assert sched>>33==3, 'child not sleeping'
        if mode==0:
            assert kind==1 and lo==vm&MASK and lo%1024==0 and hi-lo==full
            resident.append(dict(slot=slot,base=lo,words=full,full=full))
            continue
        assert not vm&MASK and kind==4
        expected_raw = full-skip
        assert expected_raw>0
        if mode==3:
            assert not raw and slot!=2 and lo%(128 if "mm_pure_bitmap_place_v1985" in mres else 1024)==0
            assert (expected_raw+35)//36 <= hi-lo <= skip and hi-lo<expected_raw
            packed.append(dict(slot=slot,base=lo,words=hi-lo,full=full,raw=expected_raw))
        elif mode==2:
            assert lo%128==0 and hi-lo==expected_raw and (lo-skip)%1024==0
            raw_words.append(dict(slot=slot,base=lo,words=hi-lo,full=full))
        else:
            raise AssertionError('unexpected child mode %d'%mode)
    assert len(packed)+len(raw_words)+len(resident)==children
    assert raw_words and (not packed if raw else bool(packed))
    gaps=[]
    for i in range(mm[s['mm_arena_count']]):
        arena=mm[s['mm_arenas']+i]
        lo=arena&MASK
        end=lo+(arena>>18)
        cursor=lo
        for a,z,*_ in e:
            if lo<=a<end:
                if cursor<a:gaps.append((cursor,a))
                cursor=z
        if cursor<end:gaps.append((cursor,end))
    gross=sum(x['raw']-x['words'] for x in packed)
    return dict(children=children,skip=skip,fixtures=fixtures,raw=raw_words,
                packed=packed,resident=resident,gross=gross,
                free=sum(z-a for a,z in gaps),
                largest_aligned=max(max(0,z-((a+1023)//1024*1024)) for a,z in gaps),
                installed_base=base,extent_count=len(e))


def verify_restore(build, work, trace=None):
    """Independent actual mode3 restore/finish and guest completion proof.

    This is deliberately not a READY_ONCE/PI6/terminal-fault oracle.
    A guest Z proves the source checks completed, not final MM teardown.
    """
    if trace is None:
        trace = (work/'physical.clean').read_text()
    result=verify(build,work,False,trace)
    s=symbols(build/'kcore.map')
    mres=symbols(build/'pure-mres-v1612.map')
    base=result['installed_base']
    meta=words(between(trace,'V1941_END_B','V1983_META'))
    modebase=meta[s['proc_storage_runtime_v29']]
    table=meta[s['proc_table']]
    full=base+mres['proc_pure_bitmap_restore_v1980']
    finish=base+mres['mm_pure_bitmap_finish_v1664']
    assert re.search(r'Breakpoint, PC: %06o\b'%full,trace)
    assert re.search(r'Breakpoint, PC: %06o\b'%finish,trace)
    r=words(between(trace,'\nV1983_RESTORE\n','\nV1983_AC\n'))
    f=words(between(trace,'\nV1983_FINISH\n','\nV1983_FINISH_AC\n'))
    slot,source,encoded,target=(f[i] for i in (1,2,3,4))
    assert r[1]==slot
    original=next(x for x in result['packed'] if x['slot']==slot)
    assert source==original['base'] and encoded==original['words']
    full_words=original['full']
    assert target%1024==0 and (target+full_words<=source or source+encoded<=target)
    for label,expected in [('RESTORE',[(source,source+encoded,4,0,slot)]),
                           ('FINISH',[(source,source+encoded,4,1,slot),(target,target+full_words,1,1,slot)])]:
        mm=words(section(trace,label)); e=extents(mm,s,64)
        cells=words(between(trace,'V1941_END_'+label,'V1983_MAP_'+label))
        assert mm[s['proc_current_slot']]==0 and mm[s['proc_exec_resv_head_v1933']]==0
        assert (cells[modebase+slot//18]>>(2*(slot%18)))&3==3
        p,vm,sched=(cells[table+3*slot+i] for i in range(3))
        assert p&0o400000 and p&0o200000 and sched>>33==2
        assert vm==full_words<<18
        ua=p>>18
        assert (ua,ua+0o410,3,0,0o1000+slot) in e
        assert sorted(expected)==[x for x in e if x[4]==slot and x[2] in (1,4)]
    before=between(trace,'V1983_OPCODE','\nBreakpoint, PC: %06o'%full)
    after=between(trace,'V1983_MAP_FINISH','V1983_Z_STOP')
    assert re.fullmatch(r'\s*[0-7]{6}/[0-7]{6}\]<[0-7]{6}\+[0-7]{6}>\[A[0-7]{6}/[0-7]{6}\]\{[0-7]{6}-[0-7]{6}\}Lw+\s*',before)
    tail=re.fullmatch(r'\s*(w+)Z\s*',after)
    assert tail and before.count('w')+len(tail.group(1))==result['children']
    assert not between(trace,'V1983_MAP_RESTORE','\nBreakpoint, PC: %06o'%finish).strip()
    assert 'SIGTERM' not in trace[:trace.index('V1983_Z_STOP')]
    result.update(restored_slot=slot,source=source,target=target,peak=encoded+full_words,
                  guest_checked_waits=result['children'])
    return result


def verify_final(build,work,result,trace=None,core=64):
    """Require the actual post-WAIT retirement and normal guest HALT."""
    if trace is None:
        trace=(work/'physical.clean').read_text()
    s=symbols(build/'kcore.map')
    meta=words(between(trace,'V1941_END_B','V1983_META'))
    rt=s['proc_storage_runtime_v29']
    modebase,slots=meta[rt],meta[rt+1]
    table=meta[s['proc_table']]
    mm=words(section(trace,'Z'))
    cells=words(between(trace,'V1941_END_Z','V1983_MAP_Z'))
    e=extents(mm,s,core)
    assert mm[s['proc_current_slot']]==1 and mm[s['proc_exec_resv_head_v1933']]==0
    for slot in range(2,slots):
        assert (cells[modebase+slot//18]>>(2*(slot%18)))&3==0
        p,vm,sched=(cells[table+3*slot+i] for i in range(3))
        assert sched>>33==0 and not p&0o400000
        assert not any(x[4]==slot and x[2] in (1,4) or
                       x[4]==0o1000+slot and x[2]==3 for x in e)
    p,vm,sched=(cells[table+3+i] for i in range(3))
    assert p&0o400000 and not p&0o200000 and sched>>33==2
    assert (cells[modebase]>>2)&3==0
    assert (vm&MASK,(vm&MASK)+(vm>>18),1,0,1) in e
    assert (p>>18,(p>>18)+0o410,3,0,0o1001) in e
    tail=trace.split('V1983_MAP_Z',1)[1]
    assert re.search(r'HALT instruction, PC: 000000\b',tail)
    assert trace.count('HALT instruction')==1 and 'Goodbye' in tail
    assert 'SIGTERM' not in trace
    result['final_mm_verified']=True
    result['normal_halt']=True
    return result


def verify_raw_completion(build,work):
    trace=(work/'physical.clean').read_text()
    result=verify(build,work,True,trace)
    tail=between(trace,'V1983_MAP_PRESSURE','V1983_Z_STOP')
    match=re.fullmatch(r'\s*[0-7]{6}/[0-7]{6}\]<[0-7]{6}\+[0-7]{6}>\[A[0-7]{6}/[0-7]{6}\]\{[0-7]{6}-[0-7]{6}\}L(w+)Z\s*',tail)
    assert match and len(match.group(1))==result['children']
    assert 'SIGTERM' not in trace[:trace.index('V1983_Z_STOP')]
    result['guest_checked_waits']=result['children']
    return result


def resident_words(path):
    data=path.read_bytes()
    word=int.from_bytes(data[8:16],'little')
    return (word>>18)+(word&MASK)


def compare(directory_build, directory, raw_build, raw):
    assert directory['fixtures']==raw['fixtures'], 'unmatched guest images'
    cost=sum(resident_words(directory_build/name)-resident_words(raw_build/name)
             for name in ('kcore.dxr','pure-mres-v1612.dxr'))
    return dict(directory_children=directory['children'],raw_children=raw['children'],
                raw_checked_waits=raw.get('guest_checked_waits'),
                directory_free=directory['free'],raw_free=raw['free'],
                directory_largest_aligned=directory['largest_aligned'],
                raw_largest_aligned=raw['largest_aligned'],resident_cost=cost,
                net_equivalent_RAW=directory['gross']-cost,
                capacity_gain=directory['children']-raw['children'])


def main():
    p=argparse.ArgumentParser()
    p.add_argument('build',type=Path)
    p.add_argument('work',type=Path)
    p.add_argument('--raw',action='store_true')
    p.add_argument('--restore',action='store_true')
    p.add_argument('--final',action='store_true')
    p.add_argument('--raw-build',type=Path)
    p.add_argument('--raw-work',type=Path)
    args=p.parse_args()
    assert not (args.raw and args.restore)
    result=verify_restore(args.build,args.work) if args.restore else verify(args.build,args.work,args.raw)
    if args.final:
        assert args.restore or args.raw
        if args.raw: result=verify_raw_completion(args.build,args.work)
        verify_final(args.build,args.work,result)
    print(json.dumps(result,indent=2,sort_keys=True))
    if args.raw_build or args.raw_work:
        assert args.raw_build and args.raw_work and not args.raw
        baseline=verify_raw_completion(args.raw_build,args.raw_work)
        print(json.dumps(compare(args.build,result,args.raw_build,baseline),indent=2,sort_keys=True))
    print('PASS: independent final MM and HALT verification (not PI6/EXEC acceptance)' if args.final else 'PASS: independent restore/guest WAIT verification (not final MM/PI6 acceptance)' if args.restore else 'PASS: independent pressure-state verification (not lifecycle acceptance)')

if __name__=='__main__':
    main()

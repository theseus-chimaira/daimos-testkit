#!/usr/bin/env python3
"""Check native DISK ownership, bitmap, and MM conservation at CTY barriers."""
import json
import re
import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
V = runpy.run_path(str(HERE.parent/'pure-runtime-reclaim-v1673/measure-v1673.py'))
HALF = (1 << 18) - 1


def verify(coremap, text):
    assert 'V1673 PASS RUN EXIT WAIT' in text
    assert re.findall(r'(?m)^V1673 CHILD PID (\d+)$', text) == [
        str(x) for x in range(2, 8)]
    names = V['GLOBALS'] + (
        'mm_arenas', 'mm_extents', 'proc_swap_blocks_used',
        'backstore_blocks_used', 'backstore_enabled', 'backstore_blocks',
        'backstore_bitmap', 'proc_exec_resv_head_v1933', 'storage_state',
        'storage_count', 'mfsdev_io_in', 'mfsdev_io_out',
        'mfsdev_storage_errors')
    a = {x: V['lookup'](coremap, x) for x in names}
    reports = {}
    for l in 'ABC':
        h, end = 'V1673 HOLD '+l, 'V1673 RELEASE '+l
        assert text.count(h) == text.count(end) == 1
        segment = text.split(h, 1)[1].split(end, 1)[0]
        assert 'sim> ' in segment
        pairs = re.findall(r'(?m)^(?:sim> )?([0-7]{3,7}):\s+([0-7]{12})\s*$', segment)
        d = {int(x, 8): int(y, 8) for x, y in pairs}
        assert len(d) == len(pairs)
        def word(n):
            return d[a[n]]
        assert word('mm_core_words') == 65536
        assert word('mm_extent_capacity') == 40
        assert word('backstore_enabled') == 1
        assert word('storage_state') == word('storage_count') == 0
        assert word('proc_exec_resv_head_v1933') == 0
        n = word('mm_extent_count')
        assert 0 < n <= 40
        arenas = []
        for i in range(word('mm_arena_count')):
            q = d[a['mm_arenas']+i]
            lo = q & HALF
            hi = lo + (q >> 18)
            assert lo < hi <= 65536
            assert not arenas or arenas[-1][1] <= lo
            arenas.append((lo, hi))
        ext = []
        for i in range(n):
            q = d[a['mm_extents']+2*i]
            m = d[a['mm_extents']+2*i+1]
            lo = q & HALF
            hi = lo + (q >> 18)
            kind, pin, owner = (m >> 18)&7, (m >> 21)&255, m&HALF
            assert lo < hi and any(x <= lo < hi <= y for x,y in arenas)
            assert not ext or ext[-1][1] <= lo
            assert kind in (1,2,3)
            ext.append((lo,hi,kind,pin,owner))
        allocated = sum(y-x for x,y,*_ in ext)
        managed = sum(y-x for x,y in arenas)
        gaps = []
        for lo,hi in arenas:
            cursor=lo
            for x,y,*_ in ext:
                if lo <= x < hi:
                    gaps.append(x-cursor)
                    cursor=y
            gaps.append(hi-cursor)
        assert min(gaps)>=0 and sum(gaps)+allocated==managed
        owners = {}
        for e in ext:
            if e[2]==1:
                assert e[4] not in owners
                owners[e[4]]=e
        pins = [e for e in ext if e[3]]
        assert len(pins)==1 and pins[0][2:]==(3,1,2)
        t, r, mode = [word(x) for x in (
            'proc_table','proc_swap_records','proc_storage_runtime_v29')]
        high=word('proc_high_slot')
        assert high==(8 if l=='B' else 2)
        assert d[t]==d[t+1]==0 and d[t+2]>>33==2
        runs = []
        live = []
        bitmap=set()
        for slot in range(1,high):
            meta, vm, sched = (d[t+3*slot+i] for i in range(3))
            assert sched>>33==3
            assert meta&0o400000
            uarea=meta>>18
            assert len([e for e in ext if e[0]==uarea and e[1]-e[0]==264
                        and e[2:]==(3,0,0o1000+slot)])==1
            backing=d[r+slot]
            saved=d[uarea+0o406]
            m=(d[mode+slot//18]>>(2*(slot%18)))&3
            size, base=vm>>18,vm&HALF
            assert size>0
            if slot>1:
                assert size==8192
            if m==0:
                assert owners.pop(slot)==(base,base+size,1,0,slot)
                assert saved==0
            else:
                assert m==1 and slot>1 and base==0 and slot not in owners
                first,count=backing>>18,backing&HALF
                assert count==size//128 and 0<=first<first+count<=word('backstore_blocks')
                assert not bitmap.intersection(range(first,first+count))
                bitmap.update(range(first,first+count))
                runs.append(dict(slot=slot,first=first,blocks=count))
            live.append(dict(slot=slot,mode=m,base=base,size=size,uarea=uarea))
        assert not owners
        actual=set()
        ptr=word('backstore_bitmap')
        for i in range(word('backstore_blocks')):
            if d[ptr+i//36] & (1<<(i%36)):
                actual.add(i)
        assert actual==bitmap
        assert word('proc_swap_blocks_used')==word('backstore_blocks_used')==len(bitmap)
        assert bool(runs)==(l=='B')
        reports[l]=dict(extents=n,free=sum(gaps),largest=max(gaps),
                        allocated=allocated,managed=managed,runs=runs,
                        live=live,bitmap_used=len(bitmap),
                        reads=d[a['mfsdev_io_in']+0o16],
                        writes=d[a['mfsdev_io_out']+0o16],
                        errors=d[a['mfsdev_storage_errors']+2],
                        owners=ext)
    assert reports['A']['live']==reports['C']['live']
    # Cache ownership can legitimately change; all non-cache, non-pipe
    # owners must survive exact. No child or pipe owner after WAIT.
    def stable(r):
        return [x for x in r['owners'] if not (x[2]==3 and x[4] in (5,6))]
    assert stable(reports['A'])==stable(reports['C'])
    assert not any(e[2]==3 and e[4]==5 for e in reports['C']['owners'])
    assert reports['B']['writes']>reports['A']['writes']
    assert reports['C']['reads']>reports['B']['reads']
    assert reports['A']['errors']==reports['B']['errors']==reports['C']['errors']
    return reports


if __name__ == '__main__':
    assert len(sys.argv)==4
    result=verify(sys.argv[1],Path(sys.argv[2]).read_text())
    Path(sys.argv[3]).write_text(json.dumps(result,indent=2)+'\n')
    print('PASS real DISK swap, bitmap, restored canaries and exact WAIT cleanup')
    for l,r in result.items():
        print(l, 'MM',r['extents'],'free',r['free'],'bitmap',r['bitmap_used'],
              'disk runs',r['runs'],'reads/writes',r['reads'],r['writes'])

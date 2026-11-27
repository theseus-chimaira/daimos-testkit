#!/usr/bin/env python3
"""Compare independently verified physical lifecycle traces and guest bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy

HERE = Path(__file__).resolve().parent
LIFE = runpy.run_path(str(HERE.parent/'pure-directory-lifecycle-v1987/verify-v1987.py'))
RAW = runpy.run_path(str(HERE.parent/'pure-directory-lifecycle48-v1995/verify-raw-v1995.py'))
PRESSURE = runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
MASK = 0o777777


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(build):
    files = {}
    for line in (build.parent/'tsfs.manifest').read_text().splitlines():
        f = line.split()
        if f[:2] in (['F','/SYSTEM/INIT'],['F','/SYSTEM/COMP'],['F','/SYSTEM/POST']):
            assert f[1] not in files
            files[f[1]] = digest(Path(f[2]))
    assert len(files) == 3
    return files


def measure(paths, core=48, raw=False):
    build, work, source = map(Path, paths)
    checked = RAW['verify'](build,work,source) if raw else LIFE['verify'](build,work,source,core=core)
    s = PRESSURE['symbols'](build/'kcore.map')
    trace = (work/'physical.clean').read_text()
    snap = PRESSURE['words'](PRESSURE['section'](trace,'PRESSURE'))
    extents = PRESSURE['extents'](snap,s,core)
    gaps = []
    for i in range(snap[s['mm_arena_count']]):
        arena = snap[s['mm_arenas']+i]
        start = arena & MASK
        end = start+(arena>>18)
        cursor = start
        for lo,hi,*_ in extents:
            if start <= lo < end:
                if lo > cursor:
                    gaps.append((cursor,lo))
                cursor = hi
        if cursor < end:
            gaps.append((cursor,end))
    aligned = max(max(0,hi-((lo+1023)//1024)*1024) for lo,hi in gaps)
    packed = [(lo,hi-lo,owner) for lo,hi,kind,pin,owner in extents if kind==4 and hi-lo<3584]
    raw_owners = [(lo,hi-lo,owner) for lo,hi,kind,pin,owner in extents if kind==4 and hi-lo==3584]
    resident = [(lo,hi-lo,owner) for lo,hi,kind,pin,owner in extents if kind==1 and owner>=2]
    assert len(packed)+len(raw_owners)+len(resident)==checked['children']
    clusters = {}
    for lo,n,_ in packed:
        if lo//1024==(lo+n-1)//1024:
            clusters[lo//1024] = clusters.get(lo//1024,0)+1
    return dict(children=checked['children'],bitmap=packed,raw=raw_owners,resident=resident,
                mm_extents=len(extents),free=sum(hi-lo for lo,hi in gaps),
                largest_aligned=aligned,largest_apr=aligned//1024*1024,
                largest_cluster=max(clusters.values(),default=0),
                mres_words=PRESSURE['resident_words'](build/'pure-mres-v1612.dxr'),
                kcore_words=PRESSURE['resident_words'](build/'kcore.dxr'),
                fixtures=fixture(build))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('raw','lower','both'):
        p.add_argument('--'+name,nargs=3,required=True,metavar=('BUILD','REPLAY','SOURCE'))
    p.add_argument('--check-64',nargs=3,metavar=('BUILD','REPLAY','SOURCE'))
    a=p.parse_args()
    raw,lower,both=measure(a.raw,raw=True),measure(a.lower),measure(a.both)
    assert raw['fixtures']==lower['fixtures']==both['fixtures'],'unmatched guest fixture'
    assert digest(Path(a.lower[0])/'kcore.dxr')==digest(Path(a.both[0])/'kcore.dxr'),'fixed KCORE changed'
    assert both['children']>lower['children']==raw['children'],'no measured capacity increase'
    assert both['largest_cluster']>lower['largest_cluster'],'no physical consolidation'
    result=dict(raw=raw,lower=lower,both=both,extra_children=both['children']-lower['children'],
                extra_mres_words=both['mres_words']-lower['mres_words'])
    if a.check_64:
        high=measure(a.check_64,core=64)
        assert high['fixtures']==both['fixtures'] and high['children']==12,'64K fixture ceiling not preserved'
        result['64K']=high
    print(json.dumps(result,indent=2,sort_keys=True))


if __name__=='__main__':
    main()

#!/usr/bin/env python3
"""Replay v1997 real DSH with every physical MM table write watched."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

HERE = Path(__file__).resolve().parent
old = runpy.run_path(str(HERE.parent/'pure-directory-dsh-v1997/direct-observe-v1997.py'))
g = old['main'].__globals__
cap = g['cap']
original_snapshot = g['snap']
watch = []

def arm(c, s, w, label):
    result = original_snapshot(c, s, w, label)
    if label == 'initial':
        capacity = result['meta']['mm_extent_capacity']
        assert capacity == 32
        addresses = [s[n] for n in ('mm_extent_count', 'mm_extent_capacity',
                                     'mm_core_words', 'mm_arena_count')]
        addresses += list(range(s['mm_arenas'], s['mm_arenas']+3))
        addresses += list(range(s['mm_extents'], s['mm_extents']+2*capacity))
        assert len(set(addresses)) == 71
        ex = cap['examine']
        shadow = {a: ex(c, a, 1)[0] for a in addresses}
        # Bind the actual installed MRES from the two independent jump slots.
        b = Path(sys.argv[1])
        m = g['m']['pressure']['symbols'](b/'pure-mres-v1612.map')
        base = (ex(c, s['proc_swap_service_one'], 1)[0]&0o777777)-m['proc_pure_mres_service_v1612']
        assert (ex(c, s['proc_swap_reclaim'], 1)[0]&0o777777) == base+m['proc_pure_mres_reclaim_v1612']
        (w/'start-v1998.json').write_text(json.dumps(dict(words=shadow, symbols=s, mres=m, base=base),indent=2)+'\n')
        ini = w/'watch-v1998.ini'
        ini.write_text(''.join('break -W %o;ex %o;go\n'%(a,a) for a in addresses))
        c.command('do '+str(ini))
        listing = c.command('show -C -W break')
        import re
        assert {int(x,8) for x in re.findall(r'(?m)^SET BREAK -W ([0-7]+);',listing)} == set(addresses), repr(listing)
        (w/'armed-v1998.txt').write_text(listing)
        watch.extend(addresses)
        print('PASS armed 71 physical write watches before DSH SET',flush=True)
    return result

def main():
    b,u,src,w = (Path(x).resolve() for x in sys.argv[1:])
    w.mkdir()
    # Copy all private media; do not touch the previous accepted evidence.
    for p in src.iterdir():
        if p.suffix in ('.tap','.dxr','.map') or p.name=='image-sha256':
            shutil.copyfile(p,w/p.name)
    ini=(src/'headless.ini').read_text().replace(str(src),str(w))
    # Reassign listeners; this direct fixture uses CTY only.
    import re
    port=39000+os.getpid()%8000
    ini=re.sub(r'(?m)^attach -q dcs0 .*$', 'attach -q dcs0 '+str(port),ini)
    ini=re.sub(r'(?m)^attach -q ge0 .*$', 'attach -q ge0 '+str(port+12000),ini)
    assert ini.endswith('go 020\n')
    (w/'headless.ini').write_text(ini+'exit\n')
    paths=sorted(w.glob('*.tap'))+sorted(w.glob('*.dxr'))+[b/'kcore.dxr',b/'pure-mres-v1612.dxr',b/'kinit.lowmem.words',u/'dsh.dxr']
    before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    (w/'hashes-v1998.json').write_text(json.dumps(before,indent=2)+'\n')
    g['snap']=arm
    sys.argv=[sys.argv[0],str(b),str(u),str(w)]
    old['main']()
    assert len(watch)==71
    for p,h in before.items():
        assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
    print('PASS all source images and copied tapes unchanged',flush=True)

if __name__=='__main__': main()

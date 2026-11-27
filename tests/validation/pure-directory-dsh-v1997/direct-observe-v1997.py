#!/usr/bin/env python3
"""Direct actual DSH TTY wake/restore, with an independent pressure parent."""
import json
import os
from pathlib import Path
import runpy
import sys

HERE=Path(__file__).resolve().parent
m=runpy.run_path(str(HERE/'observe-v1997.py'))
cap=m['capture']; snap=m['snapshot']; mask=m['MASK']


def row_at(result,slot):
    return next(r for r in result['processes'] if r['slot']==slot)


def main():
    b,u,w=map(Path,sys.argv[1:4])
    ini=w/'headless.ini'; t=ini.read_text(); assert t.endswith('go 020\nexit\n'); ini.write_text(t[:-5])
    s=m['pressure']['symbols'](b/'kcore.map')
    c=cap['Console'](Path(os.environ['PDP10_PREFIX'])/'bin/pdp6',ini,w)
    timeout=int(os.environ.get('V1997_COMMAND_TIMEOUT','300'))
    try:
        c.take('K15BOOT',timeout); print('PASS direct pressure INIT',flush=True)
        c.take('DSH V1',timeout); c.take('# ',timeout)
        initial=snap(c,s,w,'initial')
        payload,image,text=cap['read_dxr'](u/'dsh.dxr')
        dmap=cap['map_symbols'](u/'dsh.map')
        shell=cap['find_shell'](c,s,dmap,payload,image,text)
        slot=shell['slot']; before=row_at(initial,slot)
        assert before['mode']==0 and before['credential']&(1<<31) and before['backing']
        c.send('go\r'); c.send('SET KEEP DAIMOS-K15-STATE\r'); c.take('# ',timeout)
        c.send('SET\r'); out=c.take('# ',timeout)
        assert 'KEEP=DAIMOS-K15-STATE' in out
        print('PASS real DSH SET before pressure',flush=True)
        c.take('K15HELD\r',timeout)
        held=snap(c,s,w,'held'); r=row_at(held,slot)
        assert r['uarea']==before['uarea'] and r['backing']==before['backing'] and r['credential']==before['credential']
        assert r['state']==3 and r['mode']==3 and not r['base'] and not r['escrow'] and not r['meta']&(1<<16)
        assert r['saved_backing']==r['backing'] and len(r['owners'])==1
        base,n,kind,pins=r['owners'][0]
        raw=r['words']-(((r['backing']>>22 & 0o37777)+0o20)&~0o177)
        assert kind==4 and not pins and base%128==0 and 0<n<raw
        packed=cap['examine'](c,base,n); groups=(raw+35)//36
        decoded=[]; pos=groups
        for bitmap in packed[:groups]:
            for j in range(36):
                bit=bitmap & (1<<(35-j))
                if len(decoded)>=raw: assert not bit
                elif bit:
                    assert pos<n and packed[pos]
                    decoded.append(packed[pos]); pos+=1
                else: decoded.append(0)
        assert len(decoded)==raw and pos==n
        canary='DAIMOS-K15-STATE'
        words=[sum((ord(ch)-32)<<(30-6*j) for j,ch in enumerate(canary[i:i+6])) for i in range(0,len(canary),6)]
        assert any(decoded[i:i+len(words)]==words for i in range(raw-len(words)+1))
        (w/'held-bitmap.json').write_text(json.dumps(dict(base=base,encoded=n,raw=raw,packed=packed))+'\n')
        print('PASS actual DSH mode3 slot',slot,'owner',oct(base),'encoded',n,'raw',raw,flush=True)
        c.send('go\r'); c.take('K15REAPED\r',timeout)
        # Only after the pressure child has been reaped, wake DSH by CTY.
        c.send('SET\r'); out=c.take('# ',timeout)
        assert 'KEEP=DAIMOS-K15-STATE' in out
        restored=snap(c,s,w,'restored'); rr=row_at(restored,slot)
        assert rr['uarea']==r['uarea'] and rr['backing']==r['backing'] and rr['credential']==r['credential']
        assert rr['mode']==0 and rr['base'] and not rr['escrow'] and not rr['saved_backing'] and not rr['meta']&(1<<16)
        assert rr['owners']==[(rr['base'],rr['words'],1,0)]
        assert cap['find_shell'](c,s,dmap,payload,image,text)['slot']==slot
        print('PASS actual DSH FULL, same identity and variable',flush=True)
        c.send('go\r'); c.send('EXIT 57\r'); c.take('K15DONE\r',timeout)
        c.take('HALT instruction',timeout)
        print('PASS typed DSH and child WAIT, normal HALT',flush=True)
    finally: c.close()

if __name__=='__main__': main()

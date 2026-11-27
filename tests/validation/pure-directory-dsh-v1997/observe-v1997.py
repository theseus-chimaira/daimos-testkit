#!/usr/bin/env python3
"""Read-only real DSH checkpoints; single actual DCS login, no guest patches."""
import json
import os
from pathlib import Path
import re
import runpy
import socket
import sys
import time

HERE=Path(__file__).resolve().parent
capture=runpy.run_path(str(HERE.parent/'d6codec-shell-live-v1426/capture-v1426.py'))
pressure=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1984/verify-pressure-v1984.py'))
MASK=0o777777

class DCS:
    def __init__(self, port, work):
        deadline=time.monotonic()+30
        while True:
            try:
                self.sock=socket.create_connection(('127.0.0.1',port),timeout=2)
                break
            except OSError:
                if time.monotonic()>deadline: raise
                time.sleep(.25)
        self.sock.settimeout(.5)
        self.pending=b''
        self.log=open(work/'dcs-v1997.log','wb',buffering=0)

    def take(self, marker, timeout):
        end=time.monotonic()+timeout
        while marker not in self.pending:
            if time.monotonic()>end: raise TimeoutError(repr(self.pending[-500:]))
            try: data=self.sock.recv(4096)
            except TimeoutError: continue
            if not data: raise EOFError('DCS disconnected')
            self.log.write(data)
            self.pending+=data
        i=self.pending.index(marker)+len(marker)
        out,self.pending=self.pending[:i],self.pending[i:]
        return out

    def send(self,line):
        self.sock.sendall(line.encode('ascii')+b'\r')

    def close(self):
        self.sock.close(); self.log.close()


def snapshot(c,s,work,label):
    ex=lambda addr,n:capture['examine'](c,addr,n)
    c.stop()
    names=('proc_table','proc_current_slot','proc_high_slot','mm_extent_count','mm_extent_capacity','proc_storage_runtime_v29','proc_timer_clock','proc_swap_records','storage_state','storage_count')
    meta={n:ex(s[n],1)[0] for n in names}
    high=meta['proc_high_slot']; table=meta['proc_table']; modes=meta['proc_storage_runtime_v29']
    assert 1<high<=255 and modes and table
    t=ex(table,high*3); sm=ex(modes,(high+17)//18)
    mm=ex(s['mm_extents'],2*meta['mm_extent_count'])
    rows=[]
    for i in range(1,high):
        m,v,sc=t[i*3:i*3+3]
        if not m or not sc>>33: continue
        ua=m>>18 if m & (2<<16) else 0
        own=[(mm[j]&MASK,mm[j]>>18,(mm[j+1]>>18)&7,(mm[j+1]>>21)&255) for j in range(0,len(mm),2) if mm[j+1]&MASK==i and (mm[j+1]>>18)&7 in (1,4)]
        rows.append(dict(slot=i,uarea=ua,meta=m,base=v&MASK,words=v>>18,state=sc>>33,mode=(sm[i//18]>>(2*(i%18)))&3,owners=own,escrow=ex(ua+0o67,1)[0] if ua else 0,
                         backing=ex(meta['proc_swap_records']+i,1)[0],
                         saved_backing=ex(ua+0o406,1)[0] if ua else 0,
                         credential=ex(ua+0o66,1)[0] if ua else 0))
    pc=c.command('ex pc')
    result=dict(label=label,meta=meta,processes=rows,pc=pc,extents=mm)
    (work/(label+'.json')).write_text(json.dumps(result,indent=2)+'\n')
    print('SNAPSHOT',label, 'current',meta['proc_current_slot'],'PC',pc.strip(), 'processes',[(r['slot'],r['state'],r['mode'],r['words'],r['owners']) for r in rows],flush=True)
    return result


def main():
    b,u,w=map(Path,sys.argv[1:4]); port=int(sys.argv[4]); variant=sys.argv[5]
    ini=w/'headless.ini'; t=ini.read_text(); assert t.endswith('go 020\nexit\n'); ini.write_text(t[:-5])
    s=pressure['symbols'](b/'kcore.map')
    c=capture['Console'](Path(os.environ['PDP10_PREFIX'])/'bin/pdp6',ini,w)
    d=None
    timeout=int(os.environ.get('V1997_COMMAND_TIMEOUT','300'))
    assert timeout>0
    try:
        c.take('INIT V1',180)
        d=DCS(port,w)
        d.take(b'LOGIN: ',240)
        print('LOGIN prompt',flush=True)
        # The first prompt may precede the blocking read; wait once, then
        # supply a single login line instead of sending empty retries.
        time.sleep(2); d.send('ROOT')
        d.take(b'DSH V1',240); d.take(b'# ',120)
        print('DSH prompt',variant,flush=True)
        time.sleep(1)
        initial=snapshot(c,s,w,'initial');
        payload,image,text=capture['read_dxr'](u/'dsh.dxr')
        shell=capture['find_shell'](c,s,capture['map_symbols'](u/'dsh.map'),payload,image,text)
        (w/'shell.json').write_text(json.dumps(shell,indent=2)+'\n')
        c.send('go\r')
        for name,cmd,expect in [('set','SET KEEP DAIMOS-K15-STATE',None),('list','SET',b'KEEP=DAIMOS-K15-STATE'),('echo','ECHO VALUE:$KEEP',b'VALUE:DAIMOS-K15-STATE'),('after','SET',b'KEEP=DAIMOS-K15-STATE')]:
            d.send(cmd)
            try: out=d.take(b'# ',timeout)
            except TimeoutError:
                snapshot(c,s,w,name+'-timeout'); raise
            if expect: assert expect in out,repr(out)
            print('PASS',name,repr(out[-300:]),flush=True)
            time.sleep(.3); snapshot(c,s,w,name); c.send('go\r')
        print('PASS real DSH state and external ECHO',flush=True)
        if (w/'pressure.dxr').exists():
            d.send('K15PR')
            try: out=d.take(b'K15HELD\r',timeout)
            except TimeoutError:
                snapshot(c,s,w,'pressure-timeout'); raise
            time.sleep(.5)
            held=snapshot(c,s,w,'held')
            row=next(r for r in held['processes'] if r['slot']==shell['slot'])
            assert row['uarea']==shell['meta']>>18 and row['state']==3, row
            assert row['mode']==3 and not row['base'] and not row['escrow'] and not row['meta']&(1<<16), row
            assert row['credential']&(1<<31) and row['saved_backing']==row['backing']!=0
            assert len(row['owners'])==1
            base,n,kind,pins=row['owners'][0]
            raw=row['words']-(((row['backing']>>22 & 0o37777)+0o20)&~0o177)
            assert kind==4 and not pins and base%128==0 and 0<n<raw
            packed=capture['examine'](c,base,n)
            groups=(raw+35)//36
            decoded=[]; pos=groups
            for i,mask in enumerate(packed[:groups]):
                for j in range(36):
                    bit=mask & (1<<(35-j))
                    if len(decoded)>=raw:
                        assert not bit
                    elif bit:
                        assert pos<n and packed[pos]
                        decoded.append(packed[pos]); pos+=1
                    else: decoded.append(0)
            assert len(decoded)==raw and pos==n
            canary='DAIMOS-K15-STATE'
            words=[sum((ord(ch)-32)<<(30-6*j) for j,ch in enumerate(canary[i:i+6])) for i in range(0,len(canary),6)]
            assert any(decoded[i:i+len(words)]==words for i in range(raw-len(words)+1)), 'variable value absent in real bitmap'
            (w/'held-bitmap.json').write_text(json.dumps(dict(base=base,encoded=n,raw=raw,packed=packed))+'\n')
            print('PASS actual DSH mode3',row['slot'],oct(base),n,'raw',raw,flush=True)
            c.send('go\r'); d.send('X')
            try: out=d.take(b'K15REAPED\r',timeout); d.take(b'# ',timeout)
            except TimeoutError:
                snapshot(c,s,w,'restore-timeout'); raise
            restored=snapshot(c,s,w,'restored')
            r=next(r for r in restored['processes'] if r['slot']==row['slot'])
            assert r['uarea']==row['uarea'] and r['backing']==row['backing'] and r['credential']==row['credential']
            assert r['mode']==0 and r['base'] and not r['escrow'] and not r['saved_backing'] and not r['meta']&(1<<16)
            assert r['owners']==[(r['base'],r['words'],1,0)]
            capture['find_shell'](c,s,capture['map_symbols'](u/'dsh.map'),payload,image,text)
            c.send('go\r'); d.send('SET'); out=d.take(b'KEEP=DAIMOS-K15-STATE',timeout); d.take(b'# ',timeout)
            print('PASS actual restored DSH identity and shell state',flush=True)
        # Stop on the real guest HALT rather than killing a running guest.
        d.send('HALT')
        c.take('HALT instruction',timeout)
        print('PASS real HALT',flush=True)
    finally:
        if d: d.close()
        c.close()

if __name__=='__main__': main()

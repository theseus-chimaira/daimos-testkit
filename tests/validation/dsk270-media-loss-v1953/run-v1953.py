#!/usr/bin/env python3
"""Read-only instruction-level disk removal during SNA and ADT."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess

def main():
    p=argparse.ArgumentParser()
    for n in ('simulator','prefix','work'):
        p.add_argument(n,type=Path)
    a=p.parse_args()
    a.work.mkdir()
    w=a.work.resolve()
    def run(*args):
        subprocess.run([str(x) for x in args],check=True,stdout=subprocess.DEVNULL)
    run(a.prefix/'bin/das','-F','-C','-O',w/'probe.dobj',
        Path(__file__).with_name('probe-v1953.s'))
    run(a.prefix/'bin/dlink','-b','01000','-o',w/'probe.dxr','-M',w/'probe.map',w/'probe.dobj')
    run(a.prefix/'bin/dxrconvert','--simh','-b','01000',w/'probe.dxr',w/'probe.rim')
    rim=(w/'probe.rim').read_text().splitlines()
    assert rim[-1]=='go 001000' and all(x.startswith('deposit ') for x in rim[:-1])
    (w/'deposits.ini').write_text('\n'.join(rim[:-1])+'\n')
    sym=dict(re.findall(r'(?m)^(\w+)\s+([0-7]{6})$',(w/'probe.map').read_text()))
    disk=w/'disk0.dsk'
    with disk.open('wb') as f:
        f.truncate(0o130000*128*8)
    before=hashlib.sha256(disk.read_bytes()).hexdigest()
    bad=[]
    peer=w/'disk1.dsk'
    with peer.open('wb') as f:
        f.truncate(0o130000*128*8)
    peer_before=hashlib.sha256(peer.read_bytes()).hexdigest()
    for mode in ('sna','adt','early','peer'):
        ini=w/(mode+'.ini')
        commands=('set cpu 32k\nset dpy disable\nset wcnsls disable\n'
            'set ocnsls disable\nset dsk enabled\n'
            f'attach -q dsk0 {disk}\nattach -q dsk1 {peer}\ndo {w/"deposits.ini"}\n'
            f'break {sym[mode+"_loss"]}\ngo {sym[mode+"_start"]}\n')
        commands+='detach '+('dsk1' if mode=='peer' else 'dsk0')+'\n'
        if mode=='early':
            commands+=f'attach -q dsk0 {disk}\n'
        commands+='nobreak all\ncont\nexamine 1\nexamine 2\n'
        if mode in ('sna','adt'):
            commands+=f'attach -q dsk0 {disk}\n'
        if mode!='peer':
            commands+=f'go {sym["recovery"]}\nexamine 1\nexamine 2\n'
        ini.write_text(commands+'exit\n')
        r=subprocess.run([str(a.simulator),str(ini)],capture_output=True,text=True,
                         timeout=45,env=dict(os.environ,TERM='dumb'))
        t=r.stdout+r.stderr
        (w/(mode+'.log')).write_text(t)
        ac1=[int(x,8) for x in re.findall(r'(?m)^0*1:\s+([0-7]{12})\s*$',t)]
        ac2=[int(x,8) for x in re.findall(r'(?m)^0*2:\s+([0-7]{12})\s*$',t)]
        if mode=='peer':
            result=ac1==[0] and ac2==[0o40000]
        else:
            error=0o100102 if mode=='early' else 0o100103
            result=(len(ac2)==2 and ac1==[0,0] and
                    ac2[0]&0o140103==error and ac2[1]==0o40000)
        ok=(r.returncode==0 and t.count('HALT instruction')==(1 if mode=='peer' else 2)
            and result and ('Breakpoint, PC: '+sym[mode+'_loss']) in t)
        print(mode,'PASS' if ok else 'FAIL','AC1',ac1,'AC2',[oct(x) for x in ac2],flush=True)
        if not ok: bad.append(mode)
    assert hashlib.sha256(disk.read_bytes()).hexdigest()==before
    assert hashlib.sha256(peer.read_bytes()).hexdigest()==peer_before
    if bad: raise SystemExit('Failed: '+', '.join(bad))
if __name__=='__main__':
    main()

#!/usr/bin/env python3
"""Native DFR/SCS removal, READ END and no stale WRITE to reattached media."""
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
    w=a.work.resolve()
    w.mkdir()
    def run(*args):
        subprocess.run([str(x) for x in args],check=True,stdout=subprocess.DEVNULL)
    run(a.prefix/'bin/das','-F','-C','-O',w/'probe.dobj',
        Path(__file__).with_name('probe-v1954.s'))
    run(a.prefix/'bin/dlink','-b','01000','-o',w/'probe.dxr','-M',w/'probe.map',w/'probe.dobj')
    run(a.prefix/'bin/dxrconvert','--simh','-b','01000',w/'probe.dxr',w/'probe.rim')
    rim=(w/'probe.rim').read_text().splitlines()
    assert rim[-1]=='go 001000' and all(x.startswith('deposit ') for x in rim[:-1])
    (w/'deposits.ini').write_text('\n'.join(rim[:-1])+'\n')
    sym=dict(re.findall(r'(?m)^(\w+)\s+([0-7]{6})$',(w/'probe.map').read_text()))
    disks=[w/'disk0.dsk',w/'replacement.dsk']
    for i,d in enumerate(disks):
        with d.open('wb') as f:
            f.write(bytes([i])*1024)
            f.truncate(0o130000*128*8)
    before=[hashlib.sha256(d.read_bytes()).hexdigest() for d in disks]
    bad=[]
    for mode,entry,gate in [('dfr','read_start','ready_loss'),
                            ('read','read_start','read_loss'),
                            ('read-reattach','read_start','read_loss'),
                            ('write-reattach','write_start','write_loss')]:
        ini=w/(mode+'.ini')
        cmd=('set cpu 32k\nset dpy disable\nset wcnsls disable\n'
             'set ocnsls disable\nset dsk enabled\n'
             f'attach -q dsk0 {disks[0]}\ndo {w/"deposits.ini"}\n'
             f'break {sym[gate]}\ngo {sym[entry]}\n'
             'examine 2\ndetach dsk0\nnobreak all\n')
        if mode.endswith('reattach'):
            cmd+=f'attach -q dsk0 {disks[1]}\n'
        cmd+=f'go {sym["ready_check"]}\n' if mode=='dfr' else 'cont\n'
        cmd+='examine 1\nexamine 2\n'
        if mode!='write-reattach':
            if not mode.endswith('reattach'):
                cmd+=f'attach -q dsk0 {disks[0]}\n'
            cmd+=f'go {sym["recovery"]}\nexamine 1\nexamine 2\n'
        ini.write_text(cmd+'exit\n')
        r=subprocess.run([str(a.simulator),str(ini)],capture_output=True,text=True,
                         timeout=45,env=dict(os.environ,TERM='dumb'))
        t=r.stdout+r.stderr
        (w/(mode+'.log')).write_text(t)
        ac1=[int(x,8) for x in re.findall(r'(?m)^0*1:\s+([0-7]{12})\s*$',t)]
        ac2=[int(x,8) for x in re.findall(r'(?m)^0*2:\s+([0-7]{12})\s*$',t)]
        count=1 if mode=='write-reattach' else 2
        expected=0o100000 if mode=='dfr' else 0o4000 if count==1 else 0o400000
        ok=(r.returncode==0 and t.count('HALT instruction')==count and
            ac1==[0]*count and len(ac2)==count+1 and
            ac2[0]&0o776000==(0o40000 if mode=='dfr' else 0o4000) and
            ac2[1]&0o776000==expected and
            (count==1 or ac2[2]==0o40000) and
            ('Breakpoint, PC: '+sym[gate]) in t)
        print(mode,'PASS' if ok else 'FAIL','AC1',ac1,'AC2',[oct(x) for x in ac2],flush=True)
        if not ok: bad.append(mode)
    assert [hashlib.sha256(d.read_bytes()).hexdigest() for d in disks]==before
    if bad: raise SystemExit('Failed: '+', '.join(bad))
if __name__=='__main__':
    main()

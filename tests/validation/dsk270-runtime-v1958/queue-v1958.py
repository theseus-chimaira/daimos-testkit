#!/usr/bin/env python3
"""Source-linked production queue and address gate, real APR clock."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys

def main():
    assert len(sys.argv) in (4,5)
    mode = sys.argv[4] if len(sys.argv)==5 else 'queue'
    assert mode in ('queue','read','silent')
    machine=os.environ.get('DAIMOS_TEST_MACHINE','pdp6')
    assert machine in ('pdp6','ka10')
    unsafe=os.environ.get('V1959_EXPECT_UNSAFE')=='1'
    assert not unsafe or mode=='silent'
    root,driver,w=map(lambda x:Path(x).resolve(),sys.argv[1:4])
    w.mkdir()
    prefix=Path(os.environ.get('PDP10_PREFIX',str(Path.home()/'cross')))
    def run(*args):
        subprocess.run([str(x) for x in args],check=True,stdout=subprocess.DEVNULL)
    sources=[Path(__file__).with_name('queue-v1958.s' if mode=='queue' else 'recover-v1958.s'),driver,
             root/'system/kernel/storage/storage_router.s',
             root/'system/kernel/drivers/device_state.s',
             root/'system/kernel/core/ret.s']
    objs=[]
    for i,p in enumerate(sources):
        o=w/('part%d.dobj'%i)
        run(prefix/'bin/das','-F','-C','-O',o,p)
        objs.append(o)
    run(prefix/'bin/dlink','-b','01000','-o',w/'probe.dxr','-M',w/'probe.map',*objs)
    run(prefix/'bin/dxrconvert','--simh','-b','01000',w/'probe.dxr',w/'probe.rim')
    rim=(w/'probe.rim').read_text().splitlines()
    assert rim[-1]=='go 001000'
    (w/'deposits.ini').write_text('\n'.join(rim[:-1])+'\n')
    sym=dict(re.findall(r'(?m)^(\w+)\s+([0-7]{6})$',(w/'probe.map').read_text()))
    disks=[w/('disk%d.dsk'%i) for i in range(3)]
    for i,d in enumerate(disks):
        with d.open('wb') as f:
            for sector in range(3):
                f.write((16*(i+1)+sector).to_bytes(8,'little')*128)
            f.truncate(0o130000*128*8)
    before=[hashlib.sha256(d.read_bytes()).hexdigest() for d in disks]
    if mode=='queue':
        gate=sym['loss_gate']
    elif mode=='read':
        image=subprocess.check_output([str(prefix/'bin/dxrcheck'),'-d',
                                       str(w/'probe.dxr')],text=True)
        pc,=[int(x,8) for x in re.findall(r'(?m)^IMAGE\s+([0-7]+) 727200001105$',image)]
        gate='%06o'%(0o1000+pc+1)
    else:
        gate=None
    ini=w/'test.ini'
    cmd=('set cpu 32k\nset dpy disable\nset wcnsls disable\n'
        'set ocnsls disable\nset dsk enabled\nset dct enabled\n'
        f'attach -q dsk0 {disks[0]}\nattach -q dsk1 {disks[1]}\n'
        f'do {w/"deposits.ini"}\n')
    if machine=='ka10':
        # RH10 controllers are assigned 270 first; use Type 270 instead.
        cmd=('set cpu oneseg\nset cpu nomaoff\n'
             'set rpa disabled\nset rpb disabled\nset rpc disabled\n'
             'set rpd disabled\nset tua disabled\n')+cmd
    if gate:
        cmd+=f'break {gate}\ngo {sym["start"]}\n'
        cmd+=f'detach dsk0\nattach -q dsk0 {disks[2]}\nnobreak all\ngo\n'
    else:
        cmd+=f'go {sym["silent_start"]}\n'
    cmd+='ex 1\nex 2\nex '+sym['ticks']+'\nex '+sym['wakes']+'\n'
    if mode!='queue':
        cmd+='ex '+sym['first_elapsed']+'\n'
    if 'forced_once_v1959' in sym:
        cmd='set debug -n '+str(w/'controller.log')+'\n'+cmd
        cmd=cmd.replace('set dsk enabled\n',
                        'set dsk enabled\nset dsk debug=dataio\n')
        cmd+='ex '+sym['forced_once_v1959']+'\n'
    if unsafe:
        cmd+='ex 3\nex 4\n'
    ini.write_text(cmd+'exit\n')
    r=subprocess.run([str(prefix/'bin'/('pdp10-ka' if machine=='ka10' else 'pdp6')),str(ini)],capture_output=True,text=True,
                     timeout=60,env=dict(os.environ,TERM='dumb'))
    t=r.stdout+r.stderr
    (w/'console.log').write_text(t)
    assert [hashlib.sha256(d.read_bytes()).hexdigest() for d in disks]==before
    print(t,flush=True)
    assert r.returncode==0
    if gate:
        assert 'Breakpoint, PC: '+gate in t
    if unsafe:
        # Demand the actual wrong-medium data witness, not just a
        # nonzero host exit (which might indicate a broken test).
        assert 'forced_once_v1959' in sym
        assert ('HALT instruction, PC: %06o'%(int(sym['failed'],8)+1)) in t
        for ac,word in ((1,1),(3,0o20),(4,0o40)):
            assert re.search(r'(?m)^0*%o:\s+%012o$'%(ac,word),t), t
        assert re.search(r'(?m)^0*'+sym['forced_once_v1959'].lstrip('0')+
                         r':\s+000000000001$',t)
        debug=(w/'controller.log').read_text()
        assert re.search(r'DATO 000000200000, PC=[0-7]+ 020',debug)
        assert not re.search(r'DATO 000000200000, PC=[0-7]+ 040',debug)
        print('PASS unsafe mutation reproduced wrong-medium data (020 vs 040)')
        return
    assert 'HALT instruction, PC: '+sym['passed'] in t or (
        'HALT instruction, PC: %06o'%(int(sym['passed'],8)+1)) in t
    assert re.search(r'(?m)^0*1:\s+000000000000$',t)
    if 'forced_once_v1959' in sym:
        assert re.search(r'(?m)^0*'+sym['forced_once_v1959'].lstrip('0')+
                         r':\s+000000000001$',t)
        debug=(w/'controller.log').read_text()
        # First peer DATAO in DFR really was ignored. Require a later
        # DATAO for the same peer in ADT, not merely an injected delay.
        rejected=re.search(r'DATO 000000200000, PC=[0-7]+ 020',debug)
        assert rejected, debug
        assert re.search(r'DATO 000000200000, PC=[0-7]+ 040',
                         debug[rejected.end():]), debug
        print('PASS one real rejected DFR DATAO, then accepted ADT retry')
    print('PASS native '+mode+' controller/queue lifecycle',flush=True)
if __name__=='__main__':
    main()

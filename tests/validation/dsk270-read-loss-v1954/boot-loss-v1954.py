#!/usr/bin/env python3
"""Remove DSK0 after actual KINIT READ command, observe native PI5 error/fail closed."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import runpy
import select
import shutil
import subprocess
import time

HERE=Path(__file__).resolve().parent
V=runpy.run_path(str(HERE.parent/'pure-k07-full-v1941/replay-v1941.py'))
symbols,words=V['symbols'],V['words']
MASK=0o777777

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):
            h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix','simulator'):
        p.add_argument(n,type=Path)
    p.add_argument('--timeout',type=int,default=600)
    p.add_argument('--silent-controller',action='store_true',
                   help='verify bounded KINIT failure using v1953 missing-event model')
    a=p.parse_args()
    b,w,prefix,sim=(x.resolve() for x in (a.build,a.work,a.prefix,a.simulator))
    w.mkdir()
    core=symbols(b/'kcore.map')
    init=symbols(b/'kinit.map')
    mod=symbols(b/'dsk-mres.map')
    # dxrcheck uses IMAGE, not SIMH colon format.
    image={int(x,8):int(y,8) for x,y in re.findall(
        r'(?m)^IMAGE\s+([0-7]+) ([0-7]{12})$',subprocess.check_output(
            [str(prefix/'bin/dxrcheck'),'-d',str(b/'dsk-mres.dxr')],text=True))}
    datao=[x for x,y in image.items() if y==0o727140000001]
    # Distinguish the PI5 error leaf from the new boot-timeout abort.
    err=[x for x,y in image.items() if y==0o727200030200 and
         x<mod['dsk_read_sector']]
    assert len(datao)==2 and len(err)==1
    assert all(image[x+1]==0o727200000125 for x in datao)
    copies={}
    lines=[]
    for line in (b/'boot.ini').read_text().splitlines():
        f=line.split()
        if line.startswith('deposit SW '):
            line='deposit SW 1' # explicit DSK: never fall back to tape/drum
        elif line.startswith('set -q -n log '):
            line='set -q -n log '+str(w/'simh.log')
        elif line.startswith('attach -q -n '):
            line='attach -q -n '+f[3]+' '+str(w/(f[3]+'.out'))
        elif line.startswith('attach -q '):
            dev=f[2]
            if dev.startswith(('dr','dtc','mtc')):
                continue
            if re.fullmatch(r'dsk[0-3]',dev):
                src=Path(f[3]); dst=w/(dev+'.dsk')
                shutil.copyfile(src,dst); copies[dst]=digest(src)
                line='attach -q '+dev+' '+str(dst)
        lines.append(line)
    source='\n'.join(lines)+'\n'
    assert len(copies)==4 and source.count('go 060\nexit\n')==1
    source=source.replace('go 060\nexit\n',
        'break %06o\ngo 060\necho V1954_SELECT\nexamine %06o\necho V1954_BIND_END\n'%(
            init['d6fs_boot_select'],core['dsk270_read_call']))
    (w/'physical.ini').write_text(source)
    port=37000+os.getpid()%7000
    subprocess.run(['sh',str(HERE.parents[1]/'lib/daimos-simh-headless.sh'),
                    str(w/'physical.ini'),str(w/'headless.ini'),str(port),str(port+12000)],check=True)
    deadline=time.monotonic()+a.timeout
    proc=subprocess.Popen(['stdbuf','-o0','-e0',str(sim),str(w/'headless.ini')],
        cwd=b,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
        env=dict(os.environ,TERM='dumb'),bufsize=0)
    output=bytearray()
    with (w/'console.log').open('wb',buffering=0) as log:
        def wait(marker,start):
            while marker.encode() not in output[start:]:
                if time.monotonic()>deadline:
                    raise RuntimeError('timeout before '+marker)
                if not select.select([proc.stdout],[],[],0.4)[0]:
                    continue
                q=os.read(proc.stdout.fileno(),65536)
                if not q:
                    raise RuntimeError('simulator exited before '+marker)
                log.write(q);output.extend(q)
                if len(output)>2000000:
                    raise RuntimeError('oversized transcript')
            return output[start:].decode('ascii','replace').replace('\r','')
        def send(cmd):
            start=len(output);proc.stdin.write(cmd.encode('ascii'));proc.stdin.flush()
            return start
        try:
            t=wait('V1954_BIND_END',0)
            assert ('Breakpoint, PC: %06o'%init['d6fs_boot_select']) in t
            patch=words(t.split('V1954_SELECT',1)[1])[core['dsk270_read_call']]
            assert patch>>18==0o322200,oct(patch)
            base=(patch&MASK)-mod['dsk_read_sector']
            assert base>=core['__kcore_low_end']
            pcs=[base+x+1 for x in datao]
            addresses=[base+x for x in datao]+pcs+[base+err[0]]
            start=send('nobreak all\n'+''.join('examine %06o\n'%x for x in addresses)+
                       'echo V1954_OPCODES\n')
            t=wait('V1954_OPCODES',start);d=words(t)
            for addr in addresses:
                assert d[addr]==image[addr-base],(oct(addr),oct(d[addr]))
            start=send(''.join('break %06o\n'%x for x in pcs)+
                       'cont\necho V1954_DATAO\nexamine 1\nexamine %06o\necho V1954_DATAO_END\n'%core['storage_state'])
            t=wait('V1954_DATAO_END',start)
            hit=re.search(r'Breakpoint, PC: ([0-7]+)',t)
            assert hit and int(hit[1],8) in pcs
            d=words(t.split('V1954_DATAO',1)[1])
            assert d[1]==0 and d[core['storage_state']]==((1<<36)-3)
            read=[x for x,y in image.items() if y==0o727200001105]
            assert len(read)==1
            pc=base+read[0]+1
            start=send('nobreak all\nexamine %06o\nbreak %06o\ncont\necho V1954_READ\nexamine %06o\nexamine %06o\nexamine %06o\necho V1954_READ_END\n'%(
                pc-1,pc,core['storage_state'],core['storage_count'],core['wall_clock_ticks']))
            t=wait('V1954_READ_END',start)
            assert ('Breakpoint, PC: %06o'%pc) in t
            assert words(t)[pc-1]==0o727200001105
            assert words(t.split('V1954_READ\n',1)[1])[core['storage_state']]==((1<<36)-3)
            print('actual KINIT READ CONO at %06o; removing DSK0'%(pc-1),flush=True)
            if a.silent_controller:
                d=words(t.split('V1954_READ\n',1)[1])
                count=d[core['storage_count']]-(1<<36)
                tick=d[core['wall_clock_ticks']]
                assert -300<=count<0
                timeout_pc=base+mod['dsk_boot_timeout_v1954']
                start=send('detach dsk0\nnobreak all\nbreak %06o\nbreak %06o\ncont\necho V1954_TIMEOUT\nexamine %06o\nexamine %06o\nexamine %06o\necho V1954_TIMEOUT_END\n'%(
                    timeout_pc,base+err[0],core['storage_count'],core['storage_state'],core['wall_clock_ticks']))
                t=wait('V1954_TIMEOUT_END',start)
                assert ('Breakpoint, PC: %06o'%timeout_pc) in t
                assert ('Breakpoint, PC: %06o'%(base+err[0])) not in t
                d=words(t.split('V1954_TIMEOUT\n',1)[1])
                assert d[core['storage_count']]==0
                assert d[core['storage_state']]==((1<<36)-3)
                assert d[core['wall_clock_ticks']]-tick==-count
                print('actual boot timeout at %06o, %d remaining clock ticks elapsed'%(
                    timeout_pc,-count),flush=True)
            else:
                start=send('detach dsk0\nnobreak all\nbreak %06o\ncont\necho V1954_PIERR\nexamine 1\necho V1954_PIERR_END\n'%(base+err[0]))
                t=wait('V1954_PIERR_END',start)
                assert 'Breakpoint, PC: %06o'%(base+err[0]) in t
                status=words(t.split('V1954_PIERR',1)[1])[1]
                assert status>>18==0o1105
                assert status&3==3
                print('actual PI5 error, CONI %012o'%status,flush=True)
            start=send('nobreak all\ncont\necho V1954_HALT\n'+
                       ''.join('examine %06o\n'%core[x] for x in
                               ('vfs_namespace_root','storage_state','storage_count'))+'exit\n')
            t=wait('Goodbye',start)
            assert ('HALT instruction, PC: %06o'%init['kinit_halt']) in t
            whole=output.decode('ascii','replace')
            assert whole.count('HALT instruction')==1 and 'INIT V1' not in whole
            assert 'DSK270                                OK' in whole
            final=words(t.split('V1954_HALT',1)[1])
            assert all(final[core[x]]==0 for x in
                       ('vfs_namespace_root','storage_state','storage_count'))
            assert proc.wait(timeout=10)==0
        finally:
            if proc.poll() is None:
                proc.terminate()
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill();proc.wait()
            (w/'console.clean').write_bytes(output.replace(b'\r',b''))
    assert all(digest(dst)==h for dst,h in copies.items())
    print('PASS actual KINIT DSK media-loss failure, no root or active storage, media unchanged')

if __name__=='__main__':
    main()

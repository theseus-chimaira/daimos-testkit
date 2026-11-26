#!/usr/bin/env python3
"""Boot current KCC FULL AUTO images and inspect original live service words."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
old = runpy.run_path(str(HERE.parent/'pure-k07-loss-v1945/verify-v1945.py'))
symbols, words = old['symbols'], old['words']
MASK = 0o777777
JUMP = 0o254000000000
SERVICES = ('proc_swap_reclaim', 'proc_swap_service_one', 'proc_swap_term_v1666',
            'backstore_bitmap_words', 'backstore_init', 'backstore_alloc',
            'backstore_free', 'backstore_verify_allocated_v795')
STATE = ('vfs_namespace_root', 'backstore_enabled', 'backstore_blocks',
         'backstore_blocks_used', 'backstore_bitmap', 'proc_current_slot',
         'proc_high_slot', 'mm_core_words', 'mm_extent_count')
SWAP = ('proc_swap_mres_reclaim_v481','proc_swap_mres_service_v481',
        'proc_swap_mres_terminal_v1666','backstore_mres_bitmap_words_v484',
        'backstore_mres_init_v484','backstore_mres_alloc_v484',
        'backstore_mres_free_v484','backstore_mres_verify_allocated_v880')
PURE = ('proc_pure_mres_reclaim_v1612','proc_pure_mres_service_v1612',
        'pdp6_pure_detach_v1609')


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def verify(build, work, prefix, root, service, text=None):
    s = symbols(build/'kcore.map')
    if text is None:
        text=(work/'console.clean').read_text()
    assert 'INIT V1V1948_STATE' in text, 'guest INIT witness missing'
    assert text.count('V1948_STATE') == text.count('V1948_END') == 1
    assert not re.search(r'\?RT|HALT instruction|INIT: (RUN|RESPAWN) FAILED',text)
    before,state=text.split('V1948_STATE\n',1)
    assert 'INIT V1' in before and 'MEM                                 256 K' in before
    d=words(state.split('V1948_END\n',1)[0])
    assert d[s['vfs_namespace_root']]>>30==root
    assert d[s['proc_current_slot']]==1 and d[s['proc_high_slot']]==2
    assert d[s['backstore_blocks_used']]==0
    assert d[s['mm_core_words']]==0o1000000
    vals=[d[s[n]] for n in SERVICES]
    assert all(x>>18==0o254000 for x in vals)
    fallback=JUMP|s['kret_neg1']
    if service=='pure':
        assert 'PURE                              LOADED' in before
        assert vals[3:]==[fallback]*5
        assert not any(d[s[n]] for n in STATE[1:5])
        names=PURE
        mod='pure-mres-v1612'
    elif service=='swap':
        assert 'PURE                              LOADED' not in before
        # INIT has not yet executed the user-policy enable syscall.
        assert d[s['backstore_enabled']] in (0,1)
        assert d[s['backstore_blocks']]==(0o1000 if root==7 else 0o2000)
        assert d[s['backstore_bitmap']]
        names=SWAP
        mod='swap-mres-v481'
    else:
        raise AssertionError(service)
    m=symbols(build/(mod+'.map'))
    bases=[(x&MASK)-m[n] for x,n in zip(vals,names)]
    assert len(set(bases))==1 and bases[0]>=s['__kcore_low_end']
    hdr=subprocess.check_output([str(prefix/'bin/dxrcheck'),str(build/(mod+'.dxr'))],text=True)
    match=re.search(r'image=([0-7]+) bss=([0-7]+)',hdr)
    assert match
    size=sum(int(x,8) for x in match.groups())
    assert all(bases[0]<=x&MASK<bases[0]+size for x in vals[:len(names)])
    print('PASS',work.name,'provider',root,'service',service,
          'base %06o'%bases[0],'installed words',size,
          'backstore blocks',d[s['backstore_blocks']],
          'MM',d[s['mm_extent_count']],flush=True)


def execute(build, tape, drum, work, prefix, case, port, timeout):
    work.mkdir()
    s=symbols(build/'kcore.map')
    root=6 if case in ('disk','drum') else 7
    service='pure' if case=='tape-noaux' else 'swap'
    # Each case uses only disposable media. No physical writes to build roots.
    aux=None
    if case in ('tape-dsk','tape-dsk-explicit','tape-drm'):
        aux=work/'aux.dsk'
        mk=str(prefix/'bin/mkauxstore')
        with (work/'aux.log').open('w') as f:
            subprocess.run([mk,'--blank',str(aux),'--blocks',
                            '0130000' if case.startswith('tape-dsk') else '020000'],
                           stdout=f,check=True)
            subprocess.run([mk,'-i',str(aux),'--confirm-destructive',
                            '--d6fs-base','1','--d6fs-blocks','07000',
                            '--d6fs-super-a','0','--d6fs-super-b','1',
                            '--backstore-blocks','01000','--logstore-blocks','0',
                            '--cache-blocks',('0117777' if case.startswith('tape-dsk') else '07777')],stdout=f,check=True)
            subprocess.run([mk,'--inspect',str(aux)],stdout=f,check=True)
    lines=[]
    for line in (build/'boot.ini').read_text().splitlines():
        f=line.split()
        if line.startswith('attach -q -n '):
            line='attach -q -n '+f[3]+' '+str(work/(f[3]+'.out'))
        elif line.startswith('attach -q '):
            dev=f[2]
            src=Path(f[3])
            if dev.startswith('dsk'):
                if case=='disk':
                    pass
                elif case.startswith('tape-dsk') and dev=='dsk0':
                    src=aux
                else:
                    continue
            elif re.fullmatch(r'dr[0-3]',dev):
                if case=='drum':
                    src=drum/'drum'/('dsk'+dev[-1]+'.dsk')
                elif case=='tape-drm' and dev=='dr0':
                    src=aux
                else:
                    continue
            elif re.fullmatch(r'dtc[0-3]',dev):
                if root==7 and dev!='dtc3':
                    src=tape/'media'/('tsfs-root'+dev[-1]+'.dta')
                else:
                    continue
            if dev.startswith(('dsk','dr','dtc','mtc')):
                dst=work/(dev+src.suffix)
                shutil.copyfile(src,dst)
                line='attach -q '+dev+' '+str(dst)
        elif line.startswith('set -q -n log '):
            line='set -q -n log '+str(work/'simh.log')
        lines.append(line)
    ini='\n'.join(lines)+'\n'
    assert ini.count('go 060\nexit\n')==1 and 'deposit SW 0\n' in ini
    if case=='tape-dsk-explicit':
        ini=ini.replace('deposit SW 0\n','deposit SW 2\n')
    ini=ini.replace('go 060\nexit\n','expect "INIT V1"\ngo 060\necho V1948_STATE\n'+
                    ''.join('examine %06o\n'%s[n] for n in SERVICES+STATE)+
                    'echo V1948_END\nexit\n')
    (work/'physical.ini').write_text(ini)
    subprocess.run(['sh',str(HERE.parents[1]/'lib/daimos-simh-headless.sh'),
                    str(work/'physical.ini'),str(work/'headless.ini'),
                    str(port),str(port+12000)],check=True)
    with (work/'console.log').open('wb') as f:
        r=subprocess.run(['timeout','-k','3s',str(timeout),'stdbuf','-o0','-e0',
                          str(prefix/'bin/pdp6'),str(work/'headless.ini')],
                          cwd=build,stdout=f,stderr=subprocess.STDOUT,
                          env=dict(os.environ,TERM='dumb'))
    t=(work/'console.log').read_bytes().replace(b'\r',b'').decode('ascii','replace')
    (work/'console.clean').write_text(t)
    assert r.returncode==0, (case,r.returncode)
    verify(build,work,prefix,root,service,t)


def main():
    p=argparse.ArgumentParser()
    for n in ('build','tape','drum','work','prefix'):
        p.add_argument(n,type=Path)
    p.add_argument('--timeout',type=int,default=600)
    p.add_argument('--cases',nargs='+',choices=['disk','tape-noaux','tape-dsk','tape-dsk-explicit','tape-drm','drum'],
                   default=['disk','tape-noaux','tape-dsk','tape-dsk-explicit','tape-drm','drum'])
    a=p.parse_args()
    a.work.mkdir(parents=True,exist_ok=True)
    for n in ('kcore.dxr','kinit.dxr','pure-mres-v1612.dxr','swap-mres-v481.dxr'):
        print(n,digest(a.build/n),flush=True)
    port=34000+os.getpid()%7000
    with ThreadPoolExecutor(max_workers=5) as pool:
        jobs=[(c,pool.submit(execute,a.build,a.tape,a.drum,a.work/c,
                             a.prefix,c,port+i,a.timeout)) for i,c in enumerate(a.cases)]
        failed=[]
        for c,j in jobs:
            try:
                j.result()
            except Exception as e:
                print('FAIL',c,repr(e),flush=True)
                failed.append(c)
        assert not failed,failed


if __name__=='__main__':
    main()

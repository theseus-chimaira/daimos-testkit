#!/usr/bin/env python3
"""Measure actual installed low-memory footprint at the same INIT output."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
V = runpy.run_path(str(HERE.parent/'pure-k07-full-v1941/replay-v1941.py'))
symbols, words = V['symbols'], V['words']
MASK = 0o777777
GLOBALS = ('mm_core_words', 'mm_extent_capacity', 'mm_extent_count',
           'mm_arena_count', 'sys_resident_words_immediate',
           'vfs_namespace_root', 'backstore_blocks', 'proc_current_slot',
           'proc_high_slot', 'proc_swap_reclaim', 'proc_swap_service_one',
           'proc_swap_term_v1666')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def boot(build, work, prefix, core, pure, port):
    work.mkdir()
    s = symbols(build/'kcore.map')
    capacity = 4 * (core // 8) + 8
    source = (build/'boot.ini').read_text()
    assert source.count('go 020\nexit\n') == 1
    lines = []
    for line in source.splitlines():
        fields = line.split()
        if line.startswith('set cpu '):
            line = 'set cpu %dk' % core
        elif line.startswith('set -q -n log '):
            line = 'set -q -n log '+str(work/'simh.log')
        elif line.startswith('attach -q -n '):
            line = 'attach -q -n '+fields[3]+' '+str(work/(fields[3]+'.out'))
        elif line.startswith('attach -q '):
            dev = fields[2]
            if dev.startswith(('dsk','dr')):
                continue
            if dev.startswith(('dtc','mtc')):
                src = Path(fields[3])
                dst = work/(dev+src.suffix)
                shutil.copyfile(src,dst)
                line = 'attach -q '+dev+' '+str(dst)
        lines.append(line)
    source = '\n'.join(lines)+'\n'
    commands = ('expect "INIT V1"\ngo 020\necho V1951_BEGIN\n' +
                ''.join('examine %06o\n'%s[n] for n in GLOBALS) +
                'examine %06o-%06o\n'%(s['mm_arenas'],s['mm_arenas']+2) +
                'examine %06o-%06o\n'%(s['mm_extents'],s['mm_extents']+2*capacity-1) +
                'echo V1951_END\nexit\n')
    (work/'physical.ini').write_text(source.replace('go 020\nexit\n',commands))
    subprocess.run(['sh',str(HERE.parents[1]/'lib/daimos-simh-headless.sh'),
                    str(work/'physical.ini'),str(work/'headless.ini'),
                    str(port),str(port+12000)],check=True)
    with (work/'console.log').open('wb') as f:
        r = subprocess.run(['timeout','-k','3s','480','stdbuf','-o0','-e0',
                            str(prefix/'bin/pdp6'),str(work/'headless.ini')],
                           cwd=build,stdout=f,stderr=subprocess.STDOUT,
                           env=dict(os.environ,TERM='dumb'))
    t = (work/'console.log').read_bytes().replace(b'\r',b'').decode('ascii','replace')
    (work/'console.clean').write_text(t)
    assert r.returncode == 0
    return verify(build,work,prefix,core,pure)


def verify(build, work, prefix, core, pure, trace=None, write=True):
    s = symbols(build/'kcore.map')
    capacity = 4 * (core // 8) + 8
    t = trace if trace is not None else (work/'console.clean').read_text(encoding='ascii')
    assert t.count('V1951_BEGIN') == t.count('V1951_END') == 1
    assert t.count('Goodbye') == 1 and 'HALT instruction' not in t
    assert 'INIT V1V1951_BEGIN' in t and 'git commit id: cb6a255' in t
    assert ('PURE                              LOADED' in t) == pure
    d = words(t.split('V1951_BEGIN\n',1)[1].split('V1951_END\n',1)[0])
    def get(n):
        return d[s[n]]
    assert get('mm_core_words') == core*1024
    assert get('mm_extent_capacity') == capacity
    assert get('vfs_namespace_root') >> 30 == 7
    assert get('proc_current_slot') == 1 and get('proc_high_slot') == 2
    assert get('backstore_blocks') == 0
    resident = get('sys_resident_words_immediate') & MASK
    assert get('sys_resident_words_immediate') >> 18 == 0o201140
    if pure:
        m = symbols(build/'pure-mres-v1612.map')
        targets = ('proc_pure_mres_reclaim_v1612','proc_pure_mres_service_v1612',
                   'pdp6_pure_detach_v1609')
        bases = [ (get(n)&MASK)-m[q] for n,q in zip(GLOBALS[-3:],targets)]
        assert len(set(bases)) == 1 and bases[0] >= s['__kcore_low_end']
        assert all(get(n)>>18 == 0o254000 for n in GLOBALS[-3:])
    else:
        assert all(get(n) == 0o254000000000|s['kret_neg1'] for n in GLOBALS[-3:])
    arenas = []
    for i in range(get('mm_arena_count')):
        w = d[s['mm_arenas']+i]
        a,n = w&MASK,w>>18
        assert n and a+n <= core*1024
        arenas.append((a,a+n))
    assert arenas == sorted(arenas) and len(arenas) in range(1,4)
    assert all(a[1]<=b[0] for a,b in zip(arenas,arenas[1:]))
    extents = []
    for i in range(get('mm_extent_count')):
        span,meta = (d[s['mm_extents']+2*i+j] for j in (0,1))
        a,n = span&MASK,span>>18
        kind,owner,pin = (meta>>18)&7,meta&MASK,(meta>>21)&255
        assert n and kind in (1,2,3,4)
        assert any(x<=a and a+n<=y for x,y in arenas)
        extents.append((a,a+n,kind,owner,pin))
    assert extents==sorted(extents) and all(a[1]<=b[0] for a,b in zip(extents,extents[1:]))
    assert get('mm_extent_count') <= capacity
    managed=sum(b-a for a,b in arenas)
    allocated=sum(b-a for a,b,*_ in extents)
    kernel_dynamic=sum(b-a for a,b,k,o,p in extents if k==3 and o<0o1000)
    # SYS_MEMINFO includes the fixed table between KCORE and MRES.
    # Subtract it to report linked resident code/data without double count.
    table=2*capacity
    assert core*1024-managed == s['d6b_image_start_v1458']+resident
    # Reconcile the observed resident interval with actual lowmem packages.
    # PCLK boot uses no software-clock fallback; no auxiliary medium means
    # DISK SWAP is not installed even if present in disposable KINIT.
    common=('cty','clk','pclk','monitorfs','dcs','ge','tty','tape','dsk','drm','dtfs')
    packages={}
    for name in common+('purev1612',)*pure:
        hdr=subprocess.check_output([str(prefix/'bin/pdp10-objdump'),'-h',
                                     str(build/(name+'-mres.dobj'))],text=True)
        packages[name]=int(re.search(r'\bresident=(\d+)',hdr)[1])
    fixed=s['__kcore_low_end']-s['d6b_image_start_v1458']
    assert 'PCLK                                  OK' in t
    assert fixed+table+sum(packages.values())==resident
    report=dict(core=core,pure=pure,fixed_kcore=s['__kcore_low_end']-s['d6b_image_start_v1458'],
                fixed_resident=resident-table,mm_table=table,managed=managed,
                allocated=allocated,free=managed-allocated,
                boot_kernel_dynamic=kernel_dynamic,
                installed_packages=packages,
                fixed_plus_table=resident,
                extents=extents,arenas=arenas,
                kcore_sha256=digest(build/'kcore.dxr'),
                kinit_sha256=digest(build/'kinit.dxr'),
                simulator_sha256=digest(prefix/'bin/pdp6'))
    if write:
        (work/'budget.json').write_text(json.dumps(report,indent=2)+'\n')
    print(work.name, 'resident',resident-table,'MM table',table,'kernel dynamic',
          kernel_dynamic,'free',managed-allocated,flush=True)
    return report


def main():
    p=argparse.ArgumentParser()
    for n in ('off','raw','work','prefix'):
        p.add_argument(n,type=Path)
    p.add_argument('--core',type=int,choices=(48,64),default=64)
    p.add_argument('--verify-only',action='store_true')
    a=p.parse_args()
    a.work.mkdir(parents=True,exist_ok=True)
    port=35000+os.getpid()%6000
    if a.verify_only:
        o=verify(a.off,a.work/'off',a.prefix,a.core,False)
        r=verify(a.raw,a.work/'raw',a.prefix,a.core,True)
    else:
        with ThreadPoolExecutor(max_workers=2) as pool:
            off=pool.submit(boot,a.off,a.work/'off',a.prefix,a.core,False,port)
            raw=pool.submit(boot,a.raw,a.work/'raw',a.prefix,a.core,True,port+1)
            o,r=off.result(),raw.result()
    assert o['kcore_sha256']==r['kcore_sha256']
    assert r['fixed_resident']-o['fixed_resident']==3879
    assert o['mm_table']==r['mm_table']
    print('PASS same fixed KCORE; installed PURE delta 3879 words',flush=True)
    print('16K fixed-resident budget:', 'PASS' if r['fixed_plus_table']<16384 else 'FAIL',
          r['fixed_plus_table'],'words before managed scratch',flush=True)

if __name__=='__main__':
    main()

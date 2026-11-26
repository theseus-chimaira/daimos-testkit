#!/usr/bin/env python3
"""Reject altered actual snapshots, not simulated hardware faults."""
import argparse
from pathlib import Path
import re
import runpy

V=runpy.run_path(str(Path(__file__).with_name('budget-v1951.py')))

def main():
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    a=p.parse_args()
    s=V['symbols'](a.build/'kcore.map')
    trace=(a.work/'console.clean').read_text(encoding='ascii')
    V['verify'](a.build,a.work,a.prefix,64,True,write=False)
    d=V['words'](trace.split('V1951_BEGIN\n',1)[1].split('V1951_END\n',1)[0])
    cases=[('wrong root',s['vfs_namespace_root'],0o060000000000),
           ('fake resident',s['sys_resident_words_immediate'],d[s['sys_resident_words_immediate']]+1),
           ('stale service',s['proc_swap_service_one'],0o254000000000|s['kret_neg1']),
           ('overlap',s['mm_extents']+2,d[s['mm_extents']])]
    for label,addr,val in cases:
        changed,n=re.subn(r'(?m)^(0*%o:\s*)[0-7]{12}$'%addr,
                         lambda m:m.group(1)+'%012o'%val,trace)
        assert n==1 and changed!=trace
        try:
            V['verify'](a.build,a.work,a.prefix,64,True,changed,False)
        except (AssertionError,KeyError,ValueError):
            print('PASS rejects altered snapshot:',label)
        else:
            raise AssertionError('accepted altered snapshot: '+label)
if __name__=='__main__':
    main()

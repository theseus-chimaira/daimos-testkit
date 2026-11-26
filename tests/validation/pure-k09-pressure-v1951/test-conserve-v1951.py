#!/usr/bin/env python3
"""Reject altered actual v1951 conservation observations."""
import argparse
from pathlib import Path
import re
import runpy

V=runpy.run_path(str(Path(__file__).with_name('conserve-v1951.py')))
old=V['V']

def main():
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    a=p.parse_args()
    t=(a.work/'physical.clean').read_text()
    s=old['symbols'](a.build/'kcore.map')
    V['verify'](a.build,a.work,a.prefix,48,5,t)
    z=old['words'](old['section'](t,'Z'))
    e=old['extents'](z,s,48)
    parent=next(i for i,q in enumerate(e) if q[2]==3 and q[4]==0o1001)
    meta=s['mm_extents']+2*parent+1
    for label,addr,val in [('unretired slot',s['proc_high_slot'],7),
                           ('lost parent owner',meta,z[meta]+1),
                           ('leaked parent pin',meta,z[meta]+(1<<21)),
                           ('live reservation',s['proc_exec_resv_head_v1933'],1)]:
        before,tail=t.split('V1941_STAGE_Z',1)
        body,after=tail.split('V1941_END_Z',1)
        body,n=re.subn(r'(?m)^(0*%o:\s*)[0-7]{12}$'%addr,
                      lambda m:m.group(1)+'%012o'%val,body)
        assert n==1
        changed=before+'V1941_STAGE_Z'+body+'V1941_END_Z'+after
        assert changed!=t
        try:
            V['verify'](a.build,a.work,a.prefix,48,5,changed)
        except (AssertionError,KeyError,ValueError):
            print('PASS rejects altered conservation:',label)
        else:
            raise AssertionError('accepted '+label)
if __name__=='__main__':
    main()

#!/usr/bin/env python3
"""Full v1946 replay plus final slot/storage conservation and retry oracle."""
import argparse
from pathlib import Path
import re
import runpy

HERE = Path(__file__).resolve().parent
v = runpy.run_path(str(HERE.parent/'pure-k08-pi6-v1946/verify-v1946.py'))
MASK = 0o777777


def verify(b, w, prefix, trace=None):
    if trace is None:
        trace = (w/'physical.clean').read_text(encoding='ascii')
    v['verify'](b,w,prefix,trace)
    s = v['symbols'](b/'kcore.map')
    def data(label):
        return v['words'](trace.split('V1945_STAGE_'+label+'\n',1)[1]
                          .split('V1945_END_'+label+'\n',1)[0])
    B,Z = data('B'),data('Z')
    assert B[s['proc_high_slot']]==7, 'five-child pressure fixture required'
    assert Z[s['proc_high_slot']]==2, 'child process slots not retired'
    assert Z[Z[s['proc_storage_runtime_v29']]]==0, 'stale storage modes'
    assert Z[Z[s['proc_swap_records']]]==0, 'idle backing not empty'
    assert Z[Z[s['dtfs_media_base']]+1]==0o100003, 'retired medium unhealthy'
    p0,p1=B[s['proc_table']]+3,Z[s['proc_table']]+3
    assert B[p0]>>18==Z[p1]>>18, 'parent u-area moved or replaced'
    assert Z[p1+1]&MASK, 'parent VM missing'
    assert B[p0+1]>>18==Z[p1+1]>>18, 'parent APR capacity changed'
    assert B[B[s['proc_swap_records']]+1]==Z[Z[s['proc_swap_records']]+1]
    e=v['extents'](Z,s)
    assert len(e)==8
    assert [q for q in e if q[2] in (1,4)]==[
        (Z[p1+1]&MASK,(Z[p1+1]&MASK)+(Z[p1+1]>>18),1,0,1)]
    print('PASS v1947: final high slot 2, storage map empty, parent owner intact, MM8, healthy retired medium')


def mutations(b,w,prefix):
    t=(w/'physical.clean').read_text(encoding='ascii')
    s=v['symbols'](b/'kcore.map')
    def data(label):
        return v['words'](t.split('V1945_STAGE_'+label+'\n',1)[1].split('V1945_END_'+label+'\n',1)[0])
    Z=data('Z')
    M=data('MISSING')
    foreign=re.findall(r'V1945_STAGE_(FOREIGN_[0-9]+)\n',t)[-1]
    def change(label,addr,value):
        a,x=t.split('V1945_STAGE_'+label+'\n',1)
        x,z=x.split('V1945_END_'+label+'\n',1)
        x,n=re.subn(r'(?m)^(0*%o:\s*)[0-7]{12}$'%addr,
                    lambda m:m.group(1)+'%012o'%value,x)
        assert n==1,(label,addr)
        return a+'V1945_STAGE_'+label+'\n'+x+'V1945_END_'+label+'\n'+z
    cases=[
        ('repeated foreign stop',foreign,s['proc_timer_clock'],M[s['proc_timer_clock']]),
        ('stale packed mode','Z',Z[s['proc_storage_runtime_v29']],0o200),
        ('unhealthy retired medium','Z',Z[s['dtfs_media_base']]+1,0o300003),
        ('lost parent backing','Z',Z[s['proc_swap_records']]+1,0),
    ]
    for name,label,addr,value in cases:
        altered=change(label,addr,value)
        assert altered!=t
        try:
            verify(b,w,prefix,altered)
        except (AssertionError,KeyError,ValueError):
            print('PASS rejected v1947 altered trace:',name)
        else:
            raise AssertionError('accepted unsafe trace: '+name)


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    p.add_argument('--mutants',action='store_true')
    a=p.parse_args()
    verify(a.build,a.work,a.prefix)
    if a.mutants:
        mutations(a.build,a.work,a.prefix)

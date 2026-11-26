#!/usr/bin/env python3
"""Reject altered completed physical traces; not additional live faults."""
import argparse
from pathlib import Path
import re
import runpy

v=runpy.run_path(str(Path(__file__).with_name('verify-v1946.py')))


def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','prefix'):
        p.add_argument(name,type=Path)
    a=p.parse_args()
    b,w,prefix=a.build,a.work,a.prefix
    t=(w/'physical.clean').read_text(encoding='ascii')
    v['verify'](b,w,prefix,t)
    s=v['symbols'](b/'kcore.map')
    ready=re.findall(r'V1946_STAGE_(READY_[0-9]+)\n',t)[-1]
    def data(label):
        return v['words'](t.split('V1946_STAGE_'+label+'\n',1)[1].split('V1946_END_'+label+'\n',1)[0])
    def change(label,addr,value):
        a,body=t.split('V1946_STAGE_'+label+'\n',1)
        body,z=body.split('V1946_END_'+label+'\n',1)
        body,n=re.subn(r'(?m)^(0*%o:\s*)[0-7]{12}$'%addr,
                       lambda m:m.group(1)+'%012o'%value,body)
        assert n==1,(label,addr,n)
        return a+'V1946_STAGE_'+label+'\n'+body+'V1946_END_'+label+'\n'+z
    def reject(name,mutant):
        assert mutant!=t
        try: v['verify'](b,w,prefix,mutant)
        except (AssertionError,KeyError,ValueError):
            print('PASS rejected altered trace:',name)
        else: raise AssertionError('accepted unsafe trace: '+name)
    mid=data('MIDFULL')
    peer=data('PEER')
    post=data('POSTFAIL')
    dst=next(q for q in v['extents'](mid,s) if q[2:]==(1,1,3))
    for i in range(mid[s['mm_extent_count']]):
        addr=s['mm_extents']+2*i
        if mid[addr]&0o777777==dst[0]:
            meta=addr+1
            break
    else: raise AssertionError('missing target metadata')
    reject('PI6 interrupted user',change('MIDFULL',s['pdp10_pi_level6'],
           mid[s['pdp10_pi_level6']]|(0o10000<<18)))
    reject('PI6 in idle loop',change('MIDFULL',s['pdp10_pi_level6'],
           s['proc_idle_loop']))
    reject('PI6 target pin lost',change('MIDFULL',meta,mid[meta]&~(1<<21)))
    reject('wrong original PI6 opcode',change('POSTFAIL',s['proc_sched_pi_tick'],0))
    reject('no peer progress',change('PEER',s['proc_timer_clock'],post[s['proc_timer_clock']]))
    reject('wrong peer',change('PEER',s['proc_current_slot'],3))
    src=next(q for q in v['extents'](peer,s) if q[2:]==(4,0,3))
    reject('lost retained suffix',change('PEER',src[0],peer[src[0]]^1))
    reject('missing READY_ONCE',change(ready,s['proc_sched_cursor'],3))
    reject('wrong dispatch slot',change('DISPATCH',1,4))
    reject('missing real peer output',t.replace('wV1946_STAGE_PEER\n','!V1946_STAGE_PEER\n',1))
    print('PASS v1946: 10 altered physical traces rejected')


if __name__=='__main__':
    main()

#!/usr/bin/env python3
"""Mutate a completed physical trace; these are verifier tests only."""
import argparse
from pathlib import Path
import re
import runpy

v = runpy.run_path(str(Path(__file__).with_name('verify-v1945.py')))


def main():
    p = argparse.ArgumentParser()
    for n in ('build', 'work', 'prefix'):
        p.add_argument(n, type=Path)
    a = p.parse_args()
    b,w,prefix = a.build,a.work,a.prefix
    trace = (w/'physical.clean').read_text(encoding='ascii')
    v['verify'](b,w,prefix,trace)
    s = v['symbols'](b/'kcore.map')
    labels = re.findall(r'V1945_STAGE_(FOREIGN_[0-9]+)\n',trace)
    foreign = labels[-1]
    def data(l):
        return v['words'](trace.split('V1945_STAGE_'+l+'\n',1)[1].split('V1945_END_'+l+'\n',1)[0])
    d = data('MISSING')
    ext = v['extents'](d,s)
    raw = next(q for q in ext if q[2]==4 and q[4]==3)
    u = d[d[s['proc_table']]+9]>>18
    def change(l,addr,value):
        before, body = trace.split('V1945_STAGE_'+l+'\n',1)
        body, after = body.split('V1945_END_'+l+'\n',1)
        patt = r'(?m)^(0*%o:\s*)[0-7]{12}$'%addr
        body,n = re.subn(patt,lambda m:m.group(1)+('%012o'%value),body)
        assert n==1, (l,addr,n)
        return before+'V1945_STAGE_'+l+'\n'+body+'V1945_END_'+l+'\n'+after
    def reject(name,mutant):
        assert mutant!=trace
        try: v['verify'](b,w,prefix,mutant)
        except (AssertionError,KeyError,ValueError):
            print('PASS rejected altered physical trace:',name)
        else: raise AssertionError('accepted unsafe trace: '+name)
    reject('missing source accepted',change('MISSING',1,0))
    reject('foreign source accepted',change(foreign,1,0))
    reject('same-PC repeated stop',change(foreign,s['proc_timer_clock'],d[s['proc_timer_clock']]))
    reject('changed RAW suffix',change('MISSING',raw[0],d[raw[0]]^1))
    reject('changed foreign RAW suffix',change(foreign,raw[1]-1,data(foreign)[raw[1]-1]^1))
    reject('original backing lost',change(foreign,u+0o406,0))
    reject('rollback escrow left',change('MISSING',u+0o67,1))
    reject('read suspicion lost',change(foreign,data(foreign)[s['dtfs_media_base']]+1,0o100003))
    reject('foreign mount ID published',change(foreign,data(foreign)[s['tsfs_file_shape_base']]+1,0))
    reject('drive not detached',trace.replace('147KW, not attached','147KW, attached',1))
    reject('foreign drive path missing',trace.replace('/foreign.tap,','/dtc3.tap,',1))
    reject('failed final guest marker',trace.replace('ZV1945_STAGE_Z\n','!V1945_STAGE_Z\n',1))
    reject('no normal HALT',trace.replace('HALT instruction, PC: 000000','HALT instruction, PC: 004074',1))
    print('PASS v1945: 13 altered actual transcripts rejected (not executed guest faults)')

if __name__=='__main__':
    main()

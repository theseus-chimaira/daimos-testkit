#!/usr/bin/env python3
"""Read the actual written-stack maxima and independent canary snapshots."""
import json
from pathlib import Path
import runpy
import sys

HERE=Path(__file__).resolve().parent
old=runpy.run_path(str(HERE.parent/'pure-directory-dsh-v1997/direct-observe-v1997.py'))
g=old['main'].__globals__
cap=g['cap']
original=g['snap']
symbols=g['m']['pressure']['symbols']
report=[]

def sample(c,s,w,label,result=None):
    ex=cap['examine']
    private=ex(c,s['proc_stack_highwater'],1)[0]
    idle=ex(c,s['kernel_idle_stack_highwater'],1)[0]
    ptr=ex(c,s['mach_kernel_stack_base'],1)[0]&0o777777
    assert 0<ptr<49152-255
    words=ex(c,ptr+1,255)
    scan=lambda base,words:max((i for i,v in enumerate(words,1) if v!=base+i),default=0)
    idle_written=scan(ptr,words)
    rows=[]
    if result:
        for p in result['processes']:
            ua=p['uarea']
            words=ex(c,ua+0o71,0o315)
            written=scan(ua+0o70,words)
            rows.append(dict(slot=p['slot'],uarea=ua,written=written))
    assert 0<=private<=0o315 and 0<=idle<=0o377
    if report:
        assert private>=report[-1]['private'] and idle>=report[-1]['idle']
    # The scanner itself may execute after a snapshot boundary; report
    # both the persistent maximum and the independently read canaries.
    entry=dict(label=label,private=private,idle=idle,idle_written=idle_written,
               idle_base=ptr,processes=rows)
    report.append(entry)
    (w/'stack-v1999.json').write_text(json.dumps(report,indent=2)+'\n')
    print('STACK',entry,flush=True)

def snap(c,s,w,label):
    r=original(c,s,w,label)
    sample(c,s,w,label,r)
    return r

class Console(cap['Console']):
    def take(self,marker,timeout):
        out=super().take(marker,timeout)
        if marker=='HALT instruction':
            # Wait for the genuine halted monitor, not another Ctrl-E.
            super().take('sim> ',15)
            w=Path(sys.argv[3])
            s=symbols(Path(sys.argv[1])/'kcore.map')
            sample(self,s,w,'halt')
        return out

def main():
    g['snap']=snap
    cap['Console']=Console
    old['main']()
    assert [r['label'] for r in report]==['initial','held','restored','halt']
    assert report[-1]['private']>0 and report[-1]['idle']>0
    assert max(r['idle_written'] for r in report)<=report[-1]['idle']
    assert max(p['written'] for r in report for p in r['processes'])<=report[-1]['private']
    assert report[-1]['private']<0o315 and report[-1]['idle']<0o377
    print('PASS written-stack maxima and independent canary checks',flush=True)

if __name__=='__main__': main()

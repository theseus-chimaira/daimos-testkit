#!/usr/bin/env python3
"""Measure the actual outer DROP global PI hold, without stack instrumentation."""
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys

HERE=Path(__file__).resolve().parent
old=runpy.run_path(str(HERE.parent/'pure-directory-dsh-v1997/direct-observe-v1997.py'))
g=old['main'].__globals__
cap=g['cap']
original=g['snap']

def snap(c,s,w,label):
    result=original(c,s,w,label)
    if label!='initial':
        return result
    assert 'proc_stack_highwater' not in s
    b=Path(sys.argv[1])
    m=g['m']['pressure']['symbols'](b/'pure-mres-v1612.map')
    ex=cap['examine']
    service=ex(c,s['proc_swap_service_one'],1)[0]
    reclaim=ex(c,s['proc_swap_reclaim'],1)[0]
    base=(service&0o777777)-m['proc_pure_mres_service_v1612']
    assert (reclaim&0o777777)==base+m['proc_pure_mres_reclaim_v1612']
    # Bind local labels against the precise assembled object.
    prefix=Path(os.environ['PDP10_PREFIX'])/'bin'
    obj=w/'drop-v1999.dobj'
    labels=w/'drop-v1999.labels'
    subprocess.run([str(prefix/'das'),'-C','-F','-L',str(labels),'-O',str(obj),str(b/'kcore-asm/proc_pure_drop_v1611.s')],check=True)
    assert obj.read_bytes()==(b/'proc_pure_drop_v1611.dobj').read_bytes()
    source=(b/'kcore-asm/proc_pure_drop_v1611.s').read_text().split('proc_pure_bitmap_drop_v1979:\n',1)[1]
    assert source.count('pushj 17,mach_pi_disable')==source.count('pushj 17,mach_pi_restore')==1
    assert source.splitlines()[5].strip()=='pushj 17,mach_pi_disable'
    ret=re.search(r'(?m)^([^:\n]+):\n\s*move 1,013\n\s*pushj 17,mach_pi_restore',source).group(1)
    local={n:int(v,8) for n,v in re.findall(r'(?m)^([^\s]+)\s+([0-7]+)$',labels.read_text())}
    drop=base+m['proc_pure_bitmap_drop_v1979']
    restore=drop+local[ret]-local['proc_pure_bitmap_drop_v1979']+1
    events={'BEFORE':drop+5,'DISABLED':drop+6,'RESTORE':restore,'AFTER':restore+1}
    # PUSHJ 17,absolute symbol (before and restore), exact linked operands.
    assert ex(c,events['BEFORE'],1)[0]==(0o260740<<18)|s['mach_pi_disable']
    assert ex(c,events['RESTORE'],1)[0]==(0o260740<<18)|s['mach_pi_restore']
    rt=s['proc_rt_owner']
    ini=w/'pi-watch-v1999.ini'
    ini.write_text(''.join('break %o;echo V1999_PI_%s;show time;ex PIENB;ex 1;ex %o;go\n'%(pc,name,rt) for name,pc in events.items()))
    c.command('do '+str(ini))
    listing=c.command('show -C break')
    assert all(re.search(r'(?m)^SET BREAK (?:-E )?%o;'%pc,listing) for pc in events.values()),repr(listing)
    (w/'pi-binding-v1999.json').write_text(json.dumps(dict(events=events,rt=rt),indent=2)+'\n')
    print('PASS armed DROP PI boundary witnesses',events,flush=True)
    return result

def main():
    g['snap']=snap
    old['main']()
    w=Path(sys.argv[3])
    t=(w/'console-v1426.log').read_text()
    events=json.loads((w/'pi-binding-v1999.json').read_text())['events']
    # Only the actual breakpoint action, not the SHOW BREAK listing.
    chunks=re.findall(r'(?m)^V1999_PI_(BEFORE|DISABLED|RESTORE|AFTER)\s*\n(.*?)(?=\n\s*(?:Breakpoint, PC:|K15HELD|sim>))',t,re.S)
    print('PI raw',[(n,c[:250]) for n,c in chunks],flush=True)
    assert [n for n,_ in chunks]==list(events)
    results={}
    for n,chunk in chunks:
        stamp=int(re.search(r'Time:\s+(\d+)',chunk).group(1))
        pi=int(re.search(r'PIENB:\s+([0-7]+)',chunk).group(1),8)
        results[n]=dict(time=stamp,enabled=pi)
    assert [x['enabled'] for x in results.values()]==[1,0,0,1]
    assert all(a['time']<b['time'] for a,b in zip(results.values(),list(results.values())[1:]))
    (w/'pi-v1999.json').write_text(json.dumps(results,indent=2)+'\n')
    print('DROP outer bound',results['AFTER']['time']-results['BEFORE']['time'],'simulated time units',flush=True)

if __name__=='__main__': main()

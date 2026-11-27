#!/usr/bin/env python3
"""Independent replay of outer DROP PI boundary observations."""
import json
from pathlib import Path
import re
import sys

NAMES=('BEFORE','DISABLED','RESTORE','AFTER')

def verify(binding,trace):
    events=binding['events']
    assert tuple(events)==NAMES
    pat=(r'(?m)^Breakpoint, PC: ([0-7]+)[^\n]*\n'
         r'V1999_PI_(BEFORE|DISABLED|RESTORE|AFTER)\n'
         r'Time:[ \t]+(\d+)\nPIENB:[ \t]+([0-7]+)\n'
         r'1:[ \t]+([0-7]{12})\n([0-7]+):[ \t]+([0-7]{12})$')
    matches=list(re.finditer(pat,trace))
    assert tuple(m.group(2) for m in matches)==NAMES
    assert len(re.findall(r'(?m)^V1999_PI_',trace))==4
    states=[]
    for m in matches:
        pc,name,t,pi,ac,rt,owner=m.groups()
        assert int(pc,8)==events[name] and int(rt,8)==binding['rt']
        states.append(dict(name=name,time=int(t),enabled=int(pi,8),
                           ac1=int(ac,8),rt_owner=int(owner,8)))
    assert [s['enabled'] for s in states]==[1,0,0,1]
    assert all(not s['rt_owner'] for s in states)
    assert states[0]['ac1']==2
    assert states[1]['ac1']==states[2]['ac1']==states[3]['ac1']
    assert states[1]['ac1']&0o200
    assert all(a['time']<b['time'] for a,b in zip(states,states[1:]))
    assert trace.index('KEEP=DAIMOS-K15-STATE')<matches[0].start()
    assert matches[-1].end()<trace.index('K15HELD')
    return dict(boundaries=states,inner=states[2]['time']-states[1]['time'],
                outer=states[3]['time']-states[0]['time'])

def main():
    w=Path(sys.argv[1])
    binding=json.loads((w/'pi-binding-v1999.json').read_text())
    trace=(w/'console-v1426.log').read_text()
    report=verify(binding,trace)
    (w/'pi-replay-v1999.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS PI boundary replay: inner',report['inner'],'outer',report['outer'])
    for name,t in (
        ('missing disabled witness',trace.replace('V1999_PI_DISABLED\n','MISSING\n')),
        ('RT owner present',trace.replace('%o:\t000000000000'%binding['rt'],'%o:\t000000000002'%binding['rt'],1)),
        ('wrong global PI state',trace.replace('PIENB:\t000','PIENB:\t001',1)),
        ('changed saved CONI',trace.replace('1:\t000000000276','1:\t000000000076',1))):
        try: verify(binding,t)
        except (AssertionError,ValueError): print('PASS reject',name)
        else: raise SystemExit('FAIL accepted '+name)

if __name__=='__main__': main()

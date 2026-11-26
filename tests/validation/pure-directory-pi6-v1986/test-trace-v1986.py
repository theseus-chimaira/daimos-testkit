#!/usr/bin/env python3
"""Reject falsified versions of the actual v1986 physical witness."""
import argparse
from pathlib import Path
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE/'verify-v1986.py'))
# Reuse the exact monitored-word replacement helper used for v1985.
change=runpy.run_path(str(HERE.parent/'pure-bitmap-placement-v1985/verify-physical-v1985.py'))['changed_word']

def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','prefix'): p.add_argument(name,type=Path)
    p.add_argument('--scoped',action='store_true')
    args=p.parse_args()
    trace=(args.work/'physical.clean').read_text()
    result=v['verify'](args.build,args.work,args.prefix,trace,scoped=args.scoped)
    s=v['symbols'](args.build/'kcore.map')
    slot=result['slot']; source=result['source']
    meta=v['words'](v['between'](trace,'V1941_END_B','V1983_META'))
    proc=meta[s['proc_table']]+3*slot
    irq=v['words'](v['section'](trace,'PI6'))
    cell=next(s['mm_extents']+2*i+1 for i in range(irq[s['mm_extent_count']])
              if irq[s['mm_extents']+2*i]&v['MASK']==source)
    cases=[
        ('pi6-user-return',change(trace,'V1983_MAP_PI6','V1986_SCALARS_PI6',
                                  s['pdp10_pi_level6'],lambda x:x|(0o10000<<18))),
        ('pi6-idle-return',change(trace,'V1983_MAP_PI6','V1986_SCALARS_PI6',
                                  s['pdp10_pi_level6'],lambda x:(x&~v['MASK'])|s['proc_idle_loop'])),
        ('pi6-current-child',change(trace,'V1941_STAGE_PI6','V1941_END_PI6',
                                  s['proc_current_slot'],lambda x:slot)),
        ('pi6-source-unpinned',change(trace,'V1941_STAGE_PI6','V1941_END_PI6',
                                  cell,lambda x:x&~(255<<21))),
        ('pi6-payload-corrupt',change(trace,'V1986_ID_PI6','V1986_PAYLOAD_PI6',
                                  source,lambda x:x^1)),
        ('missing-ready',change(trace,'V1983_MAP_READY','V1986_SCALARS_READY',
                                  s['proc_sched_cursor'],lambda x:slot)),
        ('ready-transition',change(trace,'V1941_END_READY','V1983_MAP_READY',
                                  proc,lambda x:x|0o200000)),
    ]
    if not args.scoped:
        cases += [
        ('wrong-dispatch',change(trace,'V1983_MAP_DISPATCH','V1986_SCALARS_DISPATCH',
                                  1,lambda x:slot+1)),
        ('stale-ready',change(trace,'V1983_MAP_DISPATCH','V1986_SCALARS_DISPATCH',
                                  s['proc_sched_cursor'],lambda x:x|0o1000)),
        ('wrong-guest',change(trace,'V1941_STAGE_GUEST','V1941_END_GUEST',
                                  s['proc_current_slot'],lambda x:slot+1)),
    ]
    for name,bad in cases:
        assert bad!=trace,name
        try:v['verify'](args.build,args.work,args.prefix,bad,scoped=args.scoped)
        except (AssertionError,KeyError,StopIteration,ValueError):print('PASS: rejected '+name)
        else:raise SystemExit('FAIL: accepted '+name)

if __name__=='__main__':
    main()

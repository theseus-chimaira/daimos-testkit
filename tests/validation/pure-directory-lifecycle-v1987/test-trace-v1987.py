#!/usr/bin/env python3
"""Reject falsified versions of the actual lifecycle witnesses."""
import argparse
from pathlib import Path
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE/'verify-v1987.py'))
change=runpy.run_path(str(HERE.parent/'pure-bitmap-placement-v1985/verify-physical-v1985.py'))['changed_word']

def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','baseline'): p.add_argument(name,type=Path)
    p.add_argument("--core",type=int,choices=(48,64),default=64)
    args=p.parse_args()
    trace=(args.work/'physical.clean').read_text()
    result=v['verify'](args.build,args.work,args.baseline,trace,core=args.core)
    s=v['symbols'](args.build/'kcore.map')
    slot=result['compressed_terminal'][0]
    label='TERM_%d'%slot
    meta=v['words'](v['between'](trace,'V1941_END_B','V1983_META'))
    modebase=meta[s['proc_storage_runtime_v29']]
    proc=meta[s['proc_table']]+3*slot
    d=v['words'](v['between'](trace,'V1941_END_'+label,'V1983_MAP_'+label))
    ua=d[proc]>>18
    mm=v['words'](v['section'](trace,label))
    owner=next(s['mm_extents']+2*i+1 for i in range(mm[s['mm_extent_count']])
               if mm[s['mm_extents']+2*i+1]&0o777777==slot and
               (mm[s['mm_extents']+2*i+1]>>18)&7==4)
    d=v['words'](v['between'](trace,'V1941_END_ENTER','V1983_MAP_ENTER'))
    exec_proc=meta[s['proc_table']]+9
    exec_ua=d[exec_proc]>>18
    cases=[
        ('term-executive-pc',change(trace,'V1987_RECORD_PTR_'+label,'V1987_ID_'+label,
                                   ua+0o20,lambda x:x&~(0o10000<<18))),
        ('term-live-file',change(trace,'V1987_ID_'+label,'V1987_FILES_%d'%slot,
                                ua+0o26,lambda x:1)),
        ('term-pinned-bitmap',change(trace,'V1941_STAGE_'+label,'V1941_END_'+label,
                                    owner,lambda x:x|(1<<21))),
        ('term-wrong-current',change(trace,'V1941_STAGE_'+label,'V1941_END_'+label,
                                     s['proc_current_slot'],lambda x:slot)),
        ('term-missing-wait',trace.replace('kV1987_K_%d\n'%slot,'!WV1987_K_%d\n'%slot,1)),
        ('term-stale-mode',change(trace,'V1941_END_K_%d'%slot,'V1983_MAP_K_%d'%slot,
                                  modebase+slot//18,lambda x:x|(3<<(2*(slot%18))))),
        ('exec-retained-marker',change(trace,'V1987_RECORD_PTR_ENTER','V1987_ID_ENTER',
                                        exec_ua+0o66,lambda x:x|(1<<31))),
        ('exec-wrong-slot',change(trace,'V1941_STAGE_ENTER','V1941_END_ENTER',
                                  s['proc_current_slot'],lambda x:2)),
        ('exec-reservation-leak',change(trace,'V1941_STAGE_ENTER','V1941_END_ENTER',
                                        s['proc_exec_resv_head_v1933'],lambda x:exec_ua+0o70)),
        ('exec-wrong-image',trace.replace('XV1987_X','!eV1987_X',1)),
        ('missing-halt',trace.replace('HALT instruction, PC: 000000','unexpected stop',1)),
    ]
    for name,bad in cases:
        assert bad!=trace,name
        try:v['verify'](args.build,args.work,args.baseline,bad,core=args.core)
        except (AssertionError,KeyError,StopIteration,ValueError): print('PASS: rejected '+name)
        else: raise SystemExit('FAIL: accepted '+name)

if __name__=='__main__':
    main()

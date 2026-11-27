#!/usr/bin/env python3
"""Reject falsified physical PREVM witnesses, not synthetic successes."""
import argparse
from pathlib import Path
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE/'verify-v1988.py'))
change=runpy.run_path(str(HERE.parent/'pure-bitmap-placement-v1985/verify-physical-v1985.py'))['changed_word']

def main():
    p=argparse.ArgumentParser()
    for name in ('build','work','baseline'):
        p.add_argument(name,type=Path)
    a=p.parse_args()
    trace=(a.work/'physical.clean').read_text()
    result=v['verify'](a.build,a.work,a.baseline,trace)
    s=v['symbols'](a.build/'kcore.map')
    slot=result['fault_slot']
    source=result['source']
    meta=v['words'](v['between'](trace,'V1941_END_B','V1983_META'))
    proc=meta[s['proc_table']]+3*slot
    cells=v['words'](v['between'](trace,'V1941_END_RETRY1','V1983_MAP_RETRY1'))
    ua=cells[proc]>>18
    code=v['words'](v['between'](trace,'V1987_FILES_%d'%slot,'V1988_BACKOFF_CODE'))
    retry=code[s['proc_finish_backoff_advance_v885']]&v['MASK']
    mm=v['words'](v['section'](trace,'RETRY1'))
    owner=next(s['mm_extents']+2*i+1 for i in range(mm[s['mm_extent_count']])
               if mm[s['mm_extents']+2*i]&v['MASK']==source)
    cases=[
        ('missing-external-pin',change(trace,'V1988_EXTRA_BEFORE','V1988_PIN',owner,lambda x:x&~v['PIN'])),
        ('early-unpin',change(trace,'V1941_STAGE_RETRY1','V1941_END_RETRY1',owner,lambda x:x&~v['PIN'])),
        ('wrong-current',change(trace,'V1941_STAGE_RETRY1','V1941_END_RETRY1',s['proc_current_slot'],lambda x:slot)),
        ('lost-prevm',change(trace,'V1987_RECORD_PTR_RETRY1','V1987_ID_RETRY1',ua+0o67,lambda x:x&~(1<<33))),
        ('wrong-status',change(trace,'V1987_RECORD_PTR_RETRY1','V1987_ID_RETRY1',ua+0o67,lambda x:x^1)),
        ('wrong-span',change(trace,'V1987_ID_RETRY1','V1988_EXTRA_RETRY1',ua+0o407,lambda x:x+(1<<18))),
        ('bitmap-corruption',change(trace,'V1987_ID_RETRY1','V1988_EXTRA_RETRY1',source,lambda x:x^1)),
        ('no-backoff',change(trace,'V1987_ID_RETRY1','V1988_EXTRA_RETRY1',retry,lambda x:x-(0o20<<18))),
        ('premature-retry',change(trace,'V1941_STAGE_BACKOFF2','V1941_END_BACKOFF2',s['proc_timer_clock'],lambda x:x-0o40)),
        ('premature-wait',trace.replace('V1988_PIN\n','V1988_PIN\nk',1)),
        ('pin-not-released',change(trace,'V1988_EXTRA_RETRY2','V1988_RELEASE',owner,lambda x:x|v['PIN'])),
    ]
    for name,bad in cases:
        assert bad!=trace,name
        try:v['verify'](a.build,a.work,a.baseline,bad)
        except (AssertionError,KeyError,StopIteration,ValueError): print('PASS: rejected '+name)
        else: raise SystemExit('FAIL: accepted '+name)

if __name__=='__main__':
    main()

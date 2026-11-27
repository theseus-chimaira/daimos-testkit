#!/usr/bin/env python3
"""Reject falsified physical dirty DROP transcripts."""
import argparse
from pathlib import Path
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE/'verify-v1994.py'))
old=runpy.run_path(str(HERE.parent/'pure-directory-physical-v1992/test-trace-v1992.py'))
words,symbols,between=(v[k] for k in ('words','symbols','between'))
change_read=old['change_read']
change=old['old']['change']


def main():
    p=argparse.ArgumentParser()
    p.add_argument('build',type=Path);p.add_argument('work',type=Path)
    a=p.parse_args()
    t=(a.work/'physical.clean').read_text()
    result=v['verify'](a.build,a.work,t)
    s=symbols(a.build/'kcore.map')
    meta=words(between(t,'V1941_END_B','V1983_META'))
    proc=meta[s['proc_table']]+9
    ua=words(between(t,'V1941_END_ENCODE','V1983_MAP_ENCODE'))[proc]>>18
    code=words(between(t,'V1987_ID_ENCODE','V1991_BACKOFF_CODE'))
    retry=code[s['proc_finish_backoff_advance_v885']]&0o777777
    mm=words(between(t,'V1941_STAGE_RECOVER3','V1941_END_RECOVER3'))
    source=result['source']
    owner=next(s['mm_extents']+2*i+1 for i in range(mm[s['mm_extent_count']])
               if mm[s['mm_extents']+2*i]&0o777777==source)
    cases=[
        ('wrong-codec-result',change(t,'V1987_HIT_ENCODE_FAILED','V1987_AC_ENCODE_FAILED',1,lambda x:0)),
        ('extra-prefix-write',change_read(t,'PREFIX_DIRTY',result['apr'],lambda x:x^1)),
        ('mutable-word-change',change_read(t,'RAW_RECOVER2',source,lambda x:x^1)),
        ('wrong-phase',change(t,'V1987_RECORD_PTR_RECOVER1','V1987_ID_RECOVER1',ua+0o67,lambda x:x^3)),
        ('changed-length',change(t,'V1987_RECORD_PTR_RECOVER2','V1987_ID_RECOVER2',ua+0o67,lambda x:x^(1<<7))),
        ('changed-credential',change(t,'V1987_RECORD_PTR_RECOVER3','V1987_ID_RECOVER3',ua+0o66,lambda x:x^(1<<27))),
        ('lost-pin',change(t,'V1941_STAGE_RECOVER3','V1941_END_RECOVER3',owner,lambda x:x^(1<<21))),
        ('bad-unpin-argument',change(t,'V1987_HIT_UNPIN_INITIAL','V1987_AC_UNPIN_INITIAL',1,lambda x:x+1)),
        ('unrestored-unpin',change_read(t,'RESTORED_UNPIN_RETRY',s['mm_unpin'],lambda x:x^1)),
        ('wrong-heap',change_read(t,'EXTRA_RECOVERED',ua+0o407,lambda x:x^1)),
        ('ready-while-held',change_read(t,'EXTRA_RECOVER2',s['proc_sched_cursor'],lambda x:x|0o1000)),
        ('reset-backoff',change_read(t,'EXTRA_RECOVER2',retry,lambda x:(x&0o777777)|(0o400020<<18))),
        ('missing-halt',t.replace('HALT instruction, PC: 000000','unexpected stop',1)),
    ]
    for name,bad in cases:
        assert bad!=t,name
        try:
            v['verify'](a.build,a.work,bad)
        except (AssertionError,KeyError,StopIteration,ValueError):
            print('PASS: rejected '+name,flush=True)
        else:
            raise SystemExit('FAIL: accepted '+name)


if __name__=='__main__':
    main()

#!/usr/bin/env python3
"""Reject falsified physical refusal, recovery and lifecycle witnesses."""
import argparse
from pathlib import Path
import re
import runpy

HERE=Path(__file__).resolve().parent
v=runpy.run_path(str(HERE/'verify-v1992.py'))
old=runpy.run_path(str(HERE.parent/'pure-directory-lifecycle-v1987/test-trace-v1987.py'))
words,section,symbols,between=(v[k] for k in ('words','section','symbols','between'))

def change_read(t,label,address,f):
    end=t.index('V1991_'+label+'\n')
    pat=re.compile(r'(?m)^\s*%o:\s*([0-7]{12})\s*$'%address)
    # Use the last exact address before this unique terminating label.
    matches=list(pat.finditer(t[:end]))
    assert matches,(label,address)
    m=matches[-1]
    return t[:m.start(1)]+('%012o'%f(int(m[1],8)))+t[m.end(1):]

def main():
    p=argparse.ArgumentParser()
    for name in ('build','work'):
        p.add_argument(name,type=Path)
    a=p.parse_args()
    t=(a.work/'physical.clean').read_text()
    result=v['verify'](a.build,a.work,t)
    s=symbols(a.build/'kcore.map')
    meta=words(between(t,'V1941_END_B','V1983_META'))
    proc=meta[s['proc_table']]+9
    d=words(between(t,'V1941_END_FINISH','V1983_MAP_FINISH'))
    ua=d[proc]>>18
    code=words(between(t,'V1987_ID_ORIGINAL','V1991_BACKOFF_CODE'))
    retry=code[s['proc_finish_backoff_advance_v885']]&0o777777
    mm=words(section(t,'FINISH'))
    source=result['source']
    owner=next(s['mm_extents']+2*i+1 for i in range(mm[s['mm_extent_count']])
               if mm[s['mm_extents']+2*i]&0o777777==source)
    target=result['first_target']
    # Before FREE succeeds both extents exist; after it only the
    # source exists. Corrupt the retained phase and target field as
    # independent checks, as well as an unexpected pin on the target.
    free_mm=words(section(t,'RECOVER2'))
    target_owner=next(s['mm_extents']+2*i+1 for i in range(free_mm[s['mm_extent_count']])
                      if free_mm[s['mm_extents']+2*i]&0o777777==target)
    change=old['change']
    cases=[
        ('wrong-refusal-opcode',change_read(t,'PATCH_FREE_INITIAL',s['mm_free'],lambda x:x^1)),
        ('unrestored-instruction',change_read(t,'RESTORED_SOURCE_RETRY',s['mm_unpin'],lambda x:x^1)),
        ('wrong-refusal-result',change(t,'V1987_HIT_REFUSED_FINISH','V1987_AC_REFUSED_FINISH',1,lambda x:0)),
        ('wrong-source-length',change(t,'V1987_RECORD_PTR_RECOVER1','V1987_ID_RECOVER1',ua+0o67,lambda x:x+1)),
        ('quarantined-source-pin-loss',change(t,'V1941_STAGE_RECOVER2','V1941_END_RECOVER2',owner,lambda x:x^(1<<21))),
        ('wrong-free-phase',change(t,'V1987_RECORD_PTR_RECOVER2','V1987_ID_RECOVER2',ua+0o67,lambda x:x^(1<<15))),
        ('wrong-target-pin',change(t,'V1941_STAGE_RECOVER2','V1941_END_RECOVER2',target_owner,lambda x:x^(1<<21))),
        ('stale-target-escrow',change_read(t,'EXTRA_RECOVER3',ua+0o407,lambda x:x|((target>>10)<<18))),
        ('wrong-source-unpin-argument',change(t,'V1987_HIT_SOURCE_INITIAL','V1987_AC_SOURCE_INITIAL',1,lambda x:target)),
        ('wrong-heap',change_read(t,'EXTRA_RECOVERED',ua+0o407,lambda x:x^1)),
        ('source-byte-change',change_read(t,'EXTRA_RECOVER2',source,lambda x:x^1)),
        ('backoff-reset',change_read(t,'EXTRA_RECOVER2',retry,lambda x:(x&0o777777)|(0o400020<<18))),
        ('stale-ready',change_read(t,'EXTRA_RECOVERED',s['proc_sched_cursor'],lambda x:x|0o1000)),
        ('stale-pending',change_read(t,'EXTRA_RESTORE_RETRY',retry,lambda x:x|(0o400020<<18))),
        ('missing-halt',t.replace('HALT instruction, PC: 000000','unexpected stop',1)),
    ]
    for name,bad in cases:
        assert bad!=t,name
        try:
            v['verify'](a.build,a.work,bad)
        except (AssertionError,KeyError,StopIteration,ValueError):
            print('PASS: rejected '+name)
        else:
            raise SystemExit('FAIL: accepted '+name)

if __name__=='__main__':
    main()

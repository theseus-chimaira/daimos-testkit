#!/usr/bin/env python3
"""Observe real PI6 and dispatch on the unchanged v1945 physical guest."""
from pathlib import Path
import re
import runpy

HERE = Path(__file__).resolve().parent
prior = runpy.run_path(str(HERE.parent / 'pure-k07-loss-v1945/replay-v1945.py'))
words = prior['words']
MASK = 0o777777
TRANSITION = 0o200000
READY = 0o1000


class Observer:
    """Additional read-only checkpoints, never simulated scheduler replies."""

    names = ('proc_sched_pi_tick', 'pdp10_pi_level6',
             'proc_swap_pressure_ticks', 'proc_timer_next', 'proc_sched_kick',
             'proc_storage_runtime_v29', 'proc_runq_head')

    def __call__(self, stage, *, sym, mres, base, full, pr, fr, source,
                 target, suffix, send, wait, scalar, capture, snapshot,
                 owners=None, reattach=None):
        def inspect(label, command, raw=True):
            return capture(label, send(command+scalar(label, 'V1946')),
                           raw, 'V1946')

        def hit(trace, pc):
            assert re.search(r'Breakpoint, PC: %06o\b' % pc, trace), (
                'unexpected stop before original %06o' % pc)

        def slot3(d):
            p = d[sym['proc_table']]+9
            return d[p], d[p+1], d[p+2]

        def raw_intact(d, e, pin):
            assert (source[0],source[1],4,pin,3) in e
            assert tuple(d[i] for i in range(source[0],source[1])) == suffix

        tick = sym['proc_sched_pi_tick']
        dispatch = sym['proc_sched_restore_selected']
        if stage == 'FULL':
            # A service return or dispatch instead of a real clock
            # interrupt is a failed test, not an accepted checkpoint.
            t,d,e = inspect('MIDFULL', 'nobreak all\nbreak %06o\nbreak %06o\nbreak %06o\ncont\n' %
                            (tick,fr,dispatch))
            hit(t,tick)
            saved = d[sym['pdp10_pi_level6']]
            pc = saved & MASK
            assert not saved & (0o10000<<18) and pc
            assert base <= pc < base+max(mres.values()), 'not original PURE code'
            assert d[tick] == 0o350040000000 | sym['proc_timer_clock']
            assert d[sym['proc_current_slot']] == 0
            assert d[sym['proc_sched_cursor']] == 3 and e == owners
            assert slot3(d)[0] & TRANSITION
            raw_intact(d,e,1)
            print('v1946 real PI6 interrupted pinned FULL at %06o'%pc,flush=True)
        elif stage == 'MISSING':
            t,d,e = inspect('POSTFAIL', 'nobreak all\nbreak %06o\ncont\n'%tick)
            hit(t,tick)
            assert d[tick] == 0o350040000000 | sym['proc_timer_clock']
            assert d[sym['proc_timer_clock']] >= snapshot[sym['proc_timer_clock']]
            raw_intact(d,e,0)
            assert not any(q[2]==1 and q[4]==3 for q in e)
            assert slot3(d)[1]&MASK == 0
            # Keep DTC3 physically absent until an unrelated child
            # really executes its user-mode suffix check and writes w.
            t,d,e = inspect('PEER', 'nobreak all\nexpect "w"\ncont\n')
            assert t.split('V1946_STAGE_PEER\n',1)[0].endswith('w')
            peer = d[sym['proc_current_slot']]
            assert peer in (4,5,6)
            raw_intact(d,e,0)
            assert not slot3(d)[0]&TRANSITION and slot3(d)[1]&MASK==0
            assert d[d[sym['dtfs_media_base']]+1]&0o200000
            assert d[sym['proc_timer_clock']] > snapshot[sym['proc_timer_clock']]
            print('v1946 unrelated child %o runs with DTC3 absent'%peer,flush=True)
        elif stage == 'RECOVER':
            # Resolve the actual idle-loop service call from installed
            # instructions, not the earlier build's absolute return PC.
            lo,hi=sym['proc_idle_loop'],sym['proc_finish_backoff_advance_v885']
            start=send('examine %06o-%06o\necho V1946_IDLE_CODE\n'%(lo,hi-1))
            code=words(wait('V1946_IDLE_CODE',start))
            hits=[i+1 for i,v in code.items()
                  if lo<=i<hi and v==0o260740000000|sym['proc_swap_service_one']]
            assert len(hits)==1, 'unique original idle service call'
            ret=hits[0]
            command=reattach+'break %06o\ncont\n'%ret
            for i in range(16):
                t,d,e=inspect('READY_%d'%i,command,False)
                hit(t,ret)
                if d[sym['proc_sched_cursor']]==READY|3:
                    meta,vm,sched=slot3(d)
                    assert d[sym['proc_current_slot']]==0
                    assert not meta&TRANSITION and sched>>33==2
                    assert vm&MASK and any(q[0]==vm&MASK and q[2:]==(1,0,3) for q in e)
                    assert not any(q[2]==4 and q[4]==3 for q in e)
                    assert (d[d[sym['proc_storage_runtime_v29']]]>>6)&3==0
                    break
                command='cont\n'
            else:
                raise AssertionError('no actual slot3 READY_ONCE publication')
            t,d,e=inspect('DISPATCH','nobreak all\nbreak %06o\ncont\n'%dispatch,False)
            hit(t,dispatch)
            assert d[1]==3 and d[sym['proc_current_slot']]==0
            assert d[sym['proc_sched_cursor']]==3
            assert not slot3(d)[0]&TRANSITION and slot3(d)[1]&MASK
            print('v1946 actual READY_ONCE consumed by first dispatch to slot3',flush=True)


if __name__=='__main__':
    prior['main'](Observer())

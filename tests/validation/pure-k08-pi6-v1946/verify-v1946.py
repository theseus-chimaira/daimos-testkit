#!/usr/bin/env python3
"""Independent K08 scheduler evidence, plus the original K07 oracle."""
import argparse
from pathlib import Path
import re
import runpy

HERE = Path(__file__).resolve().parent
prior = runpy.run_path(str(HERE.parent / 'pure-k07-loss-v1945/verify-v1945.py'))
symbols, words, extents = (prior[n] for n in ('symbols','words','extents'))
MASK = 0o777777
TRANSITION = 0o200000


def verify(b,w,prefix,trace=None):
    if trace is None:
        trace=(w/'physical.clean').read_text(encoding='ascii')
    s,m = symbols(b/'kcore.map'),symbols(b/'pure-mres-v1612.map')
    labels = re.findall(r'V1946_STAGE_([A-Z0-9_]+)\n',trace)
    assert labels[:3]==['MIDFULL','POSTFAIL','PEER'], 'missing real PI6/peer stages'
    assert labels[-1:] == ['DISPATCH']
    assert len(labels)>=5
    assert labels[3:-1]==['READY_%d'%i for i in range(len(labels)-4)]
    assert len(set(labels))==len(labels)
    def range_of(namespace,label):
        start=namespace+'_STAGE_'+label+'\n'
        end=namespace+'_END_'+label+'\n'
        assert trace.count(start)==trace.count(end)==1, label
        i,j=trace.index(start),trace.index(end)
        assert i<j
        return i,j+len(end)
    def snapshot(namespace,label):
        i,j=range_of(namespace,label)
        d=words(trace[i:j])
        assert not d[s['proc_exec_resv_head_v1933']]
        return d,extents(d,s)
    def begin(namespace,label):
        return range_of(namespace,label)[0]
    def end(namespace,label):
        return range_of(namespace,label)[1]
    def before(namespace,label,previous_namespace,previous_label):
        return trace[end(previous_namespace,previous_label):begin(namespace,label)]
    F,FE=snapshot('V1945','FULL')
    M,ME=snapshot('V1945','MISSING')
    I,IE=snapshot('V1946','MIDFULL')
    P,PE=snapshot('V1946','POSTFAIL')
    Q,QE=snapshot('V1946','PEER')
    ready_label=labels[-2]
    R,RE=snapshot('V1946',ready_label)
    D,DE=snapshot('V1946','DISPATCH')
    Z,ZE=snapshot('V1945','Z')
    B,BE=snapshot('V1945','B')
    foreign_labels=re.findall(r'V1945_STAGE_(FOREIGN_[0-9]+)\n',trace)
    assert foreign_labels
    foreign_last=foreign_labels[-1]
    order=[end('V1945','FULL'),begin('V1946','MIDFULL'),
           end('V1946','MIDFULL'),begin('V1945','MISSING'),
           end('V1945','MISSING'),begin('V1946','POSTFAIL'),
           end('V1946','POSTFAIL'),begin('V1946','PEER'),
           end('V1946','PEER'),begin('V1945',foreign_labels[0]),
           end('V1945',foreign_last)]
    for label in labels[3:]:
        order.extend((begin('V1946',label),end('V1946',label)))
    order.append(begin('V1945','Z'))
    assert order==sorted(set(order)), 'out-of-order scheduler evidence'
    tick=s['proc_sched_pi_tick']
    opcode=0o350040000000|s['proc_timer_clock']
    def check_tick(d,pre):
        assert re.search(r'Breakpoint, PC: %06o\b'%tick,pre), 'not original PI6 entry'
        assert d[tick]==opcode, 'PI6 instruction differs'
        saved=d[s['pdp10_pi_level6']]
        assert saved&MASK and saved&MASK!=tick
        return saved
    mid_pc=check_tick(I,before('V1946','MIDFULL','V1945','FULL'))
    post_pc=check_tick(P,before('V1946','POSTFAIL','V1945','MISSING'))
    base=(B[s['proc_swap_service_one']]&MASK)-m['proc_pure_mres_service_v1612']
    assert B[s['proc_swap_service_one']]>>18==0o254000
    assert B[s['proc_swap_reclaim']]==0o254000000000|(base+m['proc_pure_mres_reclaim_v1612'])
    assert not mid_pc&(0o10000<<18) and base<=mid_pc&MASK<base+max(m.values()), 'PI6 not in PURE executive'
    assert I[s['proc_current_slot']]==0 and I[s['proc_sched_cursor']]==3
    assert FE==IE, 'MM changed while both FULL pins held'
    source=next(q for q in FE if q[2:]==(4,1,3))
    dest=next(q for q in FE if q[2:]==(1,1,3))
    u=F[3]
    assert dest[0]==F[2] and dest[1]-dest[0]==F[4]
    assert source[1]<=dest[0] or dest[1]<=source[0]
    suffix=tuple(F[i] for i in range(source[0],source[1]))
    def slot(d,n):
        a=d[s['proc_table']]+3*n
        return d[a],d[a+1],d[a+2]
    def raw(d,e,pin):
        assert (source[0],source[1],4,pin,3) in e
        assert tuple(d[i] for i in range(source[0],source[1]))==suffix
        assert slot(d,3)[0]>>18==u
        assert slot(d,3)[1]&MASK==0
        assert d[u+0o406]==F[1]
        assert (d[d[s['proc_storage_runtime_v29']]]>>6)&3==2
    raw(I,IE,1)
    assert slot(I,3)[0]&TRANSITION
    assert I[u+0o67]==F[u+0o67]
    assert I[s['proc_timer_clock']]>=F[s['proc_timer_clock']]
    for d,e in ((M,ME),(P,PE),(Q,QE)):
        raw(d,e,0)
        assert not any(x[2]==1 and x[4]==3 for x in e)
        assert d[u+0o67]==0
        assert d[d[s['dtfs_media_base']]+1]&0o200000
    assert P[s['proc_timer_clock']]>=M[s['proc_timer_clock']]
    assert Q[s['proc_timer_clock']]>P[s['proc_timer_clock']]
    assert Q[s['proc_timer_clock']]>M[s['proc_timer_clock']]
    assert not slot(Q,3)[0]&TRANSITION
    peer=Q[s['proc_current_slot']]
    assert peer in (4,5,6)
    peer_vm=slot(Q,peer)[1]&MASK
    assert peer_vm and any(q[0]==peer_vm and q[2:]==(1,0,peer) for q in QE)
    assert before('V1946','PEER','V1946','POSTFAIL').endswith('w')
    # No medium may have been attached during the peer witness.
    gap=trace[end('V1945','MISSING'):begin('V1945',foreign_labels[0])]
    assert 'not attached' in before('V1945','MISSING','V1946','MIDFULL')
    foreign_at=gap.index('foreign.tap')
    assert gap.index('V1946_END_PEER')<foreign_at
    assert 'attached to' not in gap[:gap.index('V1946_END_PEER')]
    # Independently resolve the original installed idle-loop call site.
    lo,hi=s['proc_idle_loop'],s['proc_finish_backoff_advance_v885']
    code=words(trace[end('V1945',foreign_last):trace.index('V1946_IDLE_CODE\n')])
    hits=[i+1 for i,v in code.items() if lo<=i<hi and v==0o260740000000|s['proc_swap_service_one']]
    assert len(hits)==1
    ret=hits[0]
    prev_ns,prev_label='V1945',foreign_last
    for l in labels[3:-1]:
        pre=before('V1946',l,prev_ns,prev_label)
        assert re.search(r'Breakpoint, PC: %06o\b'%ret,pre)
        d,e=snapshot('V1946',l)
        assert d[s['proc_current_slot']]==0
        if l!=ready_label:
            assert d[s['proc_sched_cursor']]!=0o1003
        prev_ns,prev_label='V1946',l
    assert R[s['proc_sched_cursor']]==0o1003
    assert R[s['proc_current_slot']]==0
    meta,vm,sched=slot(R,3)
    assert not meta&TRANSITION and meta>>18==u and sched>>33==2
    assert R[u+0o406]==R[u+0o67]==0
    assert (R[R[s['proc_storage_runtime_v29']]]>>6)&3==0
    assert vm&MASK and any(q[0]==vm&MASK and q[2:]==(1,0,3) for q in RE)
    assert not any(q[2]==4 and q[4]==3 for q in RE)
    dispatch=s['proc_sched_restore_selected']
    assert re.search(r'Breakpoint, PC: %06o\b'%dispatch,
                     before('V1946','DISPATCH','V1946',ready_label))
    assert D[1]==3 and D[s['proc_current_slot']]==0
    assert D[s['proc_sched_cursor']]==3
    assert not slot(D,3)[0]&TRANSITION and slot(D,3)[1]==vm
    assert DE==RE, 'dispatch changed MM ownership'
    assert D[s['proc_timer_clock']]>=R[s['proc_timer_clock']]
    assert Z[s['mm_extent_count']]==8
    assert Z[s['proc_timer_clock']]>Q[s['proc_timer_clock']]
    # Remove only added table observations for the unchanged v1945
    # oracle. Genuine guest characters and attachment/stop records stay.
    projected=re.sub(r'V1946_STAGE_([A-Z0-9_]+)\n.*?V1946_END_\1\n','\n',
                     trace,flags=re.S)
    assert 'V1946_STAGE_' not in projected
    prior['verify'](b,w,prefix,projected)
    print('PASS v1946: actual PI6 pinned FULL, post-failure tick, independent peer %o, READY_ONCE dispatch'%peer)
    print('v1946 saved PCs %012o/%012o; ticks FULL %d, PI6 %d, postfail %d, peer %d, ready %d, dispatch %d, final %d' %
          (mid_pc,post_pc,F[s['proc_timer_clock']],I[s['proc_timer_clock']],
           P[s['proc_timer_clock']],Q[s['proc_timer_clock']],R[s['proc_timer_clock']],
           D[s['proc_timer_clock']],Z[s['proc_timer_clock']]))


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    a=p.parse_args()
    try:
        verify(a.build,a.work,a.prefix)
    except (AssertionError,KeyError,ValueError,OSError) as e:
        p.exit(1,'FAIL v1946 K08 physical scheduler: %s\n'%e)

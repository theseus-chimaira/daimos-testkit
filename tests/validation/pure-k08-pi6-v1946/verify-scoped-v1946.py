#!/usr/bin/env python3
"""Verify real pinned FULL/PI6 and refusal/peer checkpoints, not recovery."""
import argparse
from pathlib import Path
import re
import runpy

HERE = Path(__file__).resolve().parent
v = runpy.run_path(str(HERE/'verify-v1946.py'))
symbols, words, extents = (v[n] for n in ('symbols','words','extents'))
MASK = 0o777777


def verify(b,w,prefix):
    trace = (w/'physical.clean').read_text(encoding='ascii')
    s = symbols(b/'kcore.map')
    m = symbols(b/'pure-mres-v1612.map')
    def stage(ns,label):
        start = ns+'_STAGE_'+label+'\n'
        end = ns+'_END_'+label+'\n'
        assert trace.count(start)==trace.count(end)==1
        i,j = trace.index(start),trace.index(end)
        assert i<j
        d = words(trace[i:j])
        assert not d[s['proc_exec_resv_head_v1933']]
        return i,j+len(end),d,extents(d,s)
    _,be,B,BE = stage('V1945','B')
    ai,ae,A,AE = stage('V1945','A')
    fi,fe,F,FE = stage('V1945','FULL')
    ii,ie,I,IE = stage('V1946','MIDFULL')
    assert be<ai<ae<fi<fe<ii<ie and BE==AE
    assert len(FE)==18 and FE==IE
    base=(B[s['proc_swap_service_one']]&MASK)-m['proc_pure_mres_service_v1612']
    assert B[s['proc_swap_service_one']]>>18==0o254000
    assert B[s['proc_swap_reclaim']]==0o254000000000|(base+m['proc_pure_mres_reclaim_v1612'])
    tick=s['proc_sched_pi_tick']
    assert re.search(r'Breakpoint, PC: %06o\b'%tick,trace[fe:ii])
    assert I[tick]==0o350040000000|s['proc_timer_clock']
    saved=I[s['pdp10_pi_level6']]
    assert not saved&(0o10000<<18)
    region=v['binding']['classify'](saved&MASK,I,s,base,v['binding']['read'](b,w,prefix))
    assert F[s['proc_current_slot']]==I[s['proc_current_slot']]==0
    assert F[s['proc_sched_cursor']]==I[s['proc_sched_cursor']]==3
    src=next(q for q in FE if q[2:]==(4,1,3))
    dst=next(q for q in FE if q[2:]==(1,1,3))
    assert dst[0]==F[2] and dst[1]-dst[0]==F[4]
    assert src[1]<=dst[0] or dst[1]<=src[0]
    assert all(F[i]==I[i] for i in range(src[0],src[1]))
    u=F[3]
    p=I[s['proc_table']]+9
    assert I[p]>>18==u and I[p]&0o200000 and not I[p+1]&MASK
    assert I[u+0o406]==F[1] and I[u+0o67]==F[u+0o67]
    assert (I[I[s['proc_storage_runtime_v29']]]>>6)&3==2
    assert I[s['proc_timer_clock']]>=F[s['proc_timer_clock']]
    print('PASS scoped real PI6 pinned FULL: %s PC %06o, slot0/cursor3, MM18, %d unchanged RAW words' %
          (region,saved&MASK,src[1]-src[0]))
    print('FULL tick %d; PI6 entry tick %d; recovery NOT verified' %
          (F[s['proc_timer_clock']],I[s['proc_timer_clock']]))
    mi,me,M,ME=stage('V1945','MISSING')
    pi,pe,P,PE=stage('V1946','POSTFAIL')
    qi,qe,Q,QE=stage('V1946','PEER')
    ri,re_,R,RE=stage('V1945','FOREIGN_0')
    assert ie<mi<me<pi<pe<qi<qe<ri<re_
    assert re.search(r'Breakpoint, PC: %06o\b'%tick,trace[me:pi])
    assert P[tick]==0o350040000000|s['proc_timer_clock']
    assert P[s['pdp10_pi_level6']]&MASK
    for d,e in ((M,ME),(P,PE),(Q,QE),(R,RE)):
        assert (src[0],src[1],4,0,3) in e
        assert not any(x[2]==1 and x[4]==3 for x in e)
        assert all(d[j]==F[j] for j in range(src[0],src[1]))
        assert d[u+0o406]==F[1] and d[u+0o67]==0
        assert d[d[s['dtfs_media_base']]+1]&0o200000
    peer=Q[s['proc_current_slot']]
    assert peer in (4,5,6) and trace[pe:qi].endswith('w')
    p=Q[s['proc_table']]+9
    assert not Q[p]&0o200000 and not Q[p+1]&MASK
    vm=Q[Q[s['proc_table']]+3*peer+1]&MASK
    assert vm and any(x[0]==vm and x[2:]==(1,0,peer) for x in QE)
    assert 'not attached' in trace[ie:mi]
    assert 'attached to' not in trace[me:qe]
    assert 'foreign.tap' in trace[qe:ri]
    assert M[s['proc_timer_clock']]<=P[s['proc_timer_clock']]<Q[s['proc_timer_clock']]<R[s['proc_timer_clock']]
    projected=re.sub(r'V1946_STAGE_([A-Z0-9_]+)\n.*?V1946_END_\1\n','\n',trace[:re_],flags=re.S)
    v['prior']['verify'](b,w,prefix,projected,refusal_only=True)
    print('PASS scoped postfailure PI6 and absent-media peer %o: ticks missing %d, PI6 %d, peer %d, foreign %d' %
          (peer,M[s['proc_timer_clock']],P[s['proc_timer_clock']],Q[s['proc_timer_clock']],R[s['proc_timer_clock']]))


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ('build','work','prefix'):
        p.add_argument(n,type=Path)
    a=p.parse_args()
    verify(a.build,a.work,a.prefix)

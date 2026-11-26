#!/usr/bin/env python3
"""Verify both admission orderings using live physical owner tables."""
import argparse
import hashlib
from pathlib import Path
import runpy

here=Path(__file__).resolve().parent
replay=runpy.run_path(str(here/"replay-v1943.py"))
v=runpy.run_path(str(here.parent/"pure-k07-full-v1941/verify-v1941.py"))
symbols,words=replay["symbols"],replay["words"]
MASK=0o777777
BARRIER=0o20000
V2=0o100000
FAULT=0o600000

def inspect(s,d):
    def scalar(n): return d[s[n]]
    high=scalar("proc_high_slot")
    p=scalar("proc_table")
    records=scalar("proc_swap_records")
    roots=scalar("vfs_mount_root_base")
    media=scalar("dtfs_media_base")
    head=scalar("proc_exec_resv_head_v1933")
    procs=[tuple(d[p+3*i+j] for j in range(3)) for i in range(high)]
    packed=[d[records+i] for i in range(high)]
    assert scalar("vfs_namespace_root")==d[roots]
    assert d[roots]>>24==(7<<6)|1
    assert not scalar("vfs_mount_policy")&2
    # This small fixture intentionally excludes PACKED owners, so all
    # stable backing records are directly represented in this table.
    ext=v["extents"](d,s)
    assert not any(e[2]==4 for e in ext), "unexpected pressure"
    return {"slot":scalar("proc_current_slot"),"clock":scalar("proc_timer_clock"),
            "tick":scalar("clk_tick_count"),"epoch":scalar("fs_namespace_epoch_v1936"),
            "lease":scalar("fs_provider_ready"),"procs":procs,"records":packed,
            "root":d[roots+1],"media":d[media+1],"ext":ext,"head":head,
            "hold":(d[head],d[head+1]) if head else None}

def secondary(q):
    assert q["root"]>>24==(5<<6)|2
    assert q["media"]&V2
    assert not q["media"]&FAULT

def backing2(q):
    return [i for i,r in enumerate(q["records"])
            if r>>22 and (r>>18)&15==1]

def child_ext(q):
    return [e for e in q["ext"] if
            (e[2]==1 and e[4]>=2) or (e[2]==3 and e[4]>=0o1002)]

def verify(b,w):
    s=symbols(b/"kcore.map")
    trace=(w/"physical.clean").read_text(encoding="ascii")
    for line in (w/"images.sha256").read_text().splitlines():
        digest,n=line.split()
        assert hashlib.sha256((b/n).read_bytes()).hexdigest()==digest
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "DTFS                              LOADED" in trace
    assert "!" not in trace
    assert trace.count("HALT instruction")==1
    assert "HALT instruction, PC: 000000" in trace
    allq={}
    last=-1
    for marker,label in replay["stages"]:
        begin="V1943_STAGE_"+label+"\n"; end="V1943_END_"+label+"\n"
        assert trace.count(begin)==trace.count(end)==1
        assert replay["guest_marker"](trace, marker, label)
        assert last<trace.index(begin)<trace.index(end)
        last=trace.index(end)
        allq[label]=inspect(s,words(trace.split(begin,1)[1].split(end,1)[0]))
    E,D,F,G,S,Q,R,V,M,A,U,Z=(allq[k] for k in "EDFGSQRVMAUZ")
    for k,q in allq.items():
        assert q["slot"]==(2 if k in ("D","V") else 1), k
        if k!="D": assert not q["head"], "reservation leak "+k
    for q in (E,D,F,G,S,Q,R,M,A):
        secondary(q)
    # Reverse race: actual in-flight stack reservation is the only
    # executable dependency on secondary DTFS. No permanent owner yet.
    assert D["head"] and D["hold"][0]==0
    vnode=D["hold"][1]
    assert vnode>>24==(5<<6)|2
    u=D["procs"][1][0]>>18
    assert D["procs"][1][0]&0o400000
    assert u+0o70<=D["head"] and D["head"]+1<u+0o406
    assert D["procs"][1][2]>>33==3
    assert (u,u+0o410,3,0,0o1001) in D["ext"]
    assert not backing2(E) and not backing2(D)
    assert E["root"]==D["root"] and E["media"]==D["media"]
    assert E["epoch"]==D["epoch"] and not D["media"]&BARRIER
    # fs_provider_unlock writes -1; only the RH is the free flag.
    assert D["lease"]&MASK, "provider lease still held"
    assert D["tick"]-E["tick"]>=0o1000
    assert backing2(F) and not F["head"]
    assert F["root"]==D["root"]
    assert not backing2(G) and not child_ext(G)
    # Forward race: barrier remains set through real refused RUN.
    assert not S["media"]&BARRIER
    assert Q["media"]&BARRIER and R["media"]&BARRIER
    assert Q["root"]==R["root"]==S["root"]
    assert Q["media"]==R["media"]
    assert Q["records"]==R["records"]
    assert Q["ext"]==R["ext"]
    assert Q["epoch"]==R["epoch"]
    assert not backing2(Q) and not backing2(R)
    assert Q["procs"][2][2]>>33==3 and R["procs"][2][2]>>33==3
    assert V["tick"]-S["tick"]>=0o2000
    assert not V["root"] and not V["media"]
    assert M["root"]==S["root"] and not M["media"]&BARRIER
    assert not backing2(A) and not child_ext(A)
    for q in (U,Z):
        assert not q["root"] and not q["media"]
        assert not backing2(q) and not child_ext(q)
    print("PASS v1943: live DTFS reservation %06o vnode %012o in parent u-area %06o" %
          (D["head"],vnode,u))
    print("PASS v1943: foreign UNMOUNT refused before permanent owner; RUN/WAIT succeeded")
    print("PASS v1943: quiescing live mount refuses RUN; unchanged MM/backing")
    print("PASS v1943: same-medium remount/RUN/WAIT and final retirement")
    print("PI6 ticks: reserve race %d, retirement race %d" %
          (D["tick"]-E["tick"],V["tick"]-S["tick"]))

if __name__=="__main__":
    p=argparse.ArgumentParser()
    for n in ("build","work"): p.add_argument(n,type=Path)
    a=p.parse_args()
    try: verify(a.build,a.work)
    except (AssertionError,KeyError,ValueError) as e:
        p.exit(1,"FAIL v1943 physical race: %s\n"%e)

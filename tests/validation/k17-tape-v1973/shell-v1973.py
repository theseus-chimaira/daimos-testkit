#!/usr/bin/env python3
"""Native TSFS shell proof, with exact live backing ownership."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import runpy
import sys

HERE=Path(__file__).resolve().parent
V=runpy.run_path(str(HERE.parent/"k17-dcs-v1972/run-v1972.py"))
C=V["C"]
send,login,command=V["send"],V["login"],V["command"]
MASK=(1<<18)-1

def sessions(c,d,root,drum):
    assert root==7
    login(c)
    command(c,"ECHO CTY1973","CTY1973")
    d.take("simulator DCS device, line 0",600)
    if not drum:
        # Without backing, do not require two full-size DSH APRs.
        # Exit CTY DSH while retaining its normal respawned LOGIN.
        send(c,"EXIT")
        c.take("LOGIN: ",600)
    send(d,"")
    login(d)
    command(d,"ECHO DCS1973","DCS1973")
    command(d,"PWD","/")
    if drum:
        command(c,"ECHO CTYALIVE1973","CTYALIVE1973")
    print("PASS TSFS shell commands; RM10",drum,flush=True)

def snapshot(c,s,vals):
    def read(n):
        return C["examine"](c,s[n],1)[0]
    def mem(p,n):
        return C["examine"](c,p,n)
    high=vals["proc_high_slot"]
    assert high==4
    table=mem(vals["proc_table"],3*high)
    mode=mem(read("proc_storage_runtime_v29"),1)[0]
    rec=mem(read("proc_swap_records"),high)
    used=vals["backstore_blocks_used"]
    capacity=vals["backstore_blocks"]
    records=[]
    blocks=set()
    mm=mem(s["mm_extents"],2*read("mm_extent_count"))
    owners={}
    for i in range(0,len(mm),2):
        a,b=mm[i:i+2]
        if (b>>18)&7==1:
            slot=b&MASK
            assert slot not in owners
            owners[slot]=(a&MASK,a>>18)
    for slot in range(1,high):
        meta,vm,sched=table[3*slot:3*slot+3]
        assert meta&0o400000 and sched>>33 in (2,3)
        size,base=vm>>18,vm&MASK
        m=(mode>>(2*slot))&3
        assert size>0
        if m==0:
            assert owners.pop(slot)==(base,size)
        else:
            assert m==1 and not base and slot not in owners
            first,count=rec[slot]>>18,rec[slot]&MASK
            assert count==size//128 and first+count<=capacity
            assert not blocks.intersection(range(first,first+count))
            blocks.update(range(first,first+count))
            records.append(dict(slot=slot,first=first,count=count))
    assert not owners
    if capacity:
        bits=mem(read("backstore_bitmap"),(capacity+35)//36)
        actual={i for i in range(capacity) if bits[i//36]&(1<<(i%36))}
        assert actual==blocks
    assert used==read("proc_swap_blocks_used")==len(blocks)
    print("PASS exact live APR/backstore ownership",records,flush=True)
    return dict(live_runs=records)

if __name__=="__main__":
    assert len(sys.argv)==5
    build,prefix,w=map(lambda x:Path(x).resolve(),sys.argv[1:4])
    port=int(sys.argv[4])
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs=[pool.submit(V["boot"],build,prefix,w/("shell-rm10" if drum else "shell-none"),
                          7,drum,port+i,sessions,snapshot)
              for i,drum in enumerate((False,True))]
        for j in jobs:
            j.result()

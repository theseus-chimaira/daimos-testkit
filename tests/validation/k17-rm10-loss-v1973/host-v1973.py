#!/usr/bin/env python3
"""Actual RM10 loss at native DATAO, with exact MM fail-stop conservation."""
import hashlib
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys

HERE=Path(__file__).resolve().parent
S=runpy.run_path(str(HERE.parent/"disk-swap-k09-v1955/host-v1955.py"))
H=S["V"]
MASK=(1<<18)-1
WORD=(1<<36)-1
op=os.environ["V1973_OPERATION"]
assert op in ("read","write")
gate="B" if op=="read" else "A"
state={}
work=Path(sys.argv[5]).resolve().parent

def before(token,coremap,examine,read):
    if token!=gate:
        return
    sym=lambda n:H["source_symbol"](coremap,n)
    b=Path(coremap).parent
    prefix=Path(os.environ.get("PDP10_PREFIX",str(Path.home()/"cross")))
    # Resolve the actual relocated entry and DATAO instruction.
    patch=read(sym("drm236_read_call"))
    off=H["source_symbol"](b/"drm-mres.map","drm236_read_block_service")
    base=(patch&MASK)-off
    image=subprocess.check_output([str(prefix/"bin/dxrcheck"),"-d",
                                   str(b/"drm-mres.dxr")],text=True)
    datao,=[int(a,8) for a in re.findall(r"(?m)^IMAGE\s+([0-7]+) 717140000001$",image)]
    assert read(base+datao)==0o717140000001
    halt=sym("kcore_critical_device_lost_v1515")+7
    assert read(halt)==(0o254200<<18)|halt
    state.update(pc=base+datao+1,halt=halt)
    examine("break %06o\n"%state["pc"])

def after(token,coremap,examine,read,read_range,send,wait,output):
    if token!=gate:
        return False
    sym=lambda n:H["source_symbol"](coremap,n)
    val=lambda n:read(sym(n))
    wait("Breakpoint, PC: %06o"%state["pc"],0,180)
    wait("sim> ",output.rfind(b"Breakpoint, PC:"),20)
    ptr=val("proc_table")
    rec=val("proc_swap_records")
    mode=val("proc_storage_runtime_v29")
    meta,vm,record=read(ptr+6),read(ptr+7),read(rec+2)
    assert meta&0o200000 and vm>>18==8192
    assert (read(mode)>>4)&3==int(op=="read")
    assert (vm&MASK==0)==(op=="read")
    if op=="read":
        assert record==64
    assert val("proc_swap_blocks_used")== (64 if op=="read" else 0)
    assert val("backstore_blocks_used")==64
    active=val("drm236_active_request")
    assert 0<active>>18<=300
    req=active&MASK
    raw=read(req)>>18
    buf=read(req)&MASK
    assert raw==0o4214*8 and read(req+1)==(0 if op=="read" else 0o1000)
    assert read(req+2)==0
    assert read(0o150)==(0o777600<<18)|(buf-1)
    assert read(0o151)==0 and read(0o152)==read(0o153)==0
    count=val("mm_extent_count")
    mm=sym("mm_extents")
    def table():
        start=len(output)
        read_range(mm,2*count,65536)
        return {int(a,8):int(w,8) for a,w in re.findall(
            r"(?m)^(?:sim> )?([0-7]+):\s+([0-7]{12})\s*$",
            output[start:].decode("ascii","ignore"))}
    orig=table()
    assert len(orig)==2*count
    ext=[(orig[mm+2*i],orig[mm+2*i+1]) for i in range(count)]
    dest=[(a,m) for a,m in ext if m&MASK==2 and (m>>18)&7==1]
    assert len(dest)==1 and dest[0][0]>>18==8192 and (dest[0][1]>>21)&255==1
    assert dest[0][0]&MASK==buf
    bitmap=val("backstore_bitmap")
    assert read(bitmap)==WORD and read(bitmap+1)==(1<<28)-1
    error=read(sym("mfsdev_storage_errors")+5)
    tick=val("wall_clock_ticks")
    examine("detach fha0\n")
    original=work/"rm10.drm"
    before_hash=hashlib.sha256(original.read_bytes()).hexdigest()
    examine("nobreak all\n")
    start=len(output)
    send(b"go\n")
    wait("HALT instruction, PC: %06o"%state["halt"],start,180)
    wait("sim> ",start,20)
    assert read(1)==2
    assert val("drm236_active_request")==0 and read(req+2)==WORD
    assert read(sym("mfsdev_storage_errors")+5)==error+1
    assert val("wall_clock_ticks")-tick==active>>18
    assert read(ptr+6)==meta and read(ptr+7)==vm and read(rec+2)==record
    assert (read(mode)>>4)&3==int(op=="read")
    assert val("proc_swap_blocks_used")== (64 if op=="read" else 0)
    assert val("backstore_blocks_used")==64
    assert read(bitmap)==WORD and read(bitmap+1)==(1<<28)-1
    assert val("mm_extent_count")==count and table()==orig
    assert read(0o152)==read(0o153)==0
    assert hashlib.sha256(original.read_bytes()).hexdigest()==before_hash
    print("PASS RM10",op,"reason2 HALT, bounded STOP, exact MM/backing/pins retained",
          "request %06o"%req,"ticks",active>>18,flush=True)
    return True

H["run"](sys.argv,extra_snapshot=S["extra_snapshot"],
         before_release=before,after_release=after)

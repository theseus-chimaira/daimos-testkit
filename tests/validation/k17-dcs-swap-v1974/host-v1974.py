#!/usr/bin/env python3
"""Real TCP input wakes an RM10-swapped process on the full KA10 kernel."""
import json
import os
from pathlib import Path
import re
import runpy
import socket
import struct
import subprocess
import sys

HERE=Path(__file__).resolve().parent
S=runpy.run_path(str(HERE.parent/"k17-rm10-v1970/host-swap-v1970.py"))
H=S["S"]["V"]
MASK=(1<<18)-1
WORD=(1<<36)-1
state={}
sock=None

def sym(coremap,n):
    return H["source_symbol"](coremap,n)

def settle(token,coremap,examine,read,send,wait,output):
    S["settle"](token,coremap,examine,read,send,wait,output)
    b=Path(coremap).parent
    patch=read(sym(coremap,"pdp10_pi_level2_dispatch_jump"))
    assert patch>>18==0o254000
    base=patch&MASK
    h=struct.unpack("<2Q",(b/"dcs-mres.dxr").read_bytes()[:16])
    assert h[0]>>18==0o447062 and h[1]&MASK==2
    state["mail"]=base+(h[1]>>18)
    state["event"]=state["mail"]+1
    assert read(base)==0o730240000001
    assert read(state["mail"])==0
    if token in ("A","B"):
        assert read(state["event"])==0
    if token=="B":
        ptr=read(sym(coremap,"proc_table"))
        vm=read(ptr+7)
        sched=read(ptr+8)
        mode=read(sym(coremap,"proc_storage_runtime_v29"))
        assert vm==8192<<18
        assert (read(mode)>>4)&3==1
        assert sched>>33==3 and sched&MASK==state["event"]
        state["ptr"]=ptr
        print("PASS B: slot2 DISK with original native DCS wait event",flush=True)
    if token=="C":
        print("PASS C: consumed DCS mailbox, final ownership",flush=True)

def before(token,coremap,examine,read):
    global sock
    if token=="A":
        sock=socket.create_connection(("127.0.0.1",int(os.environ["V1973_DCS_PORT"])),timeout=15)
    if token!="B":
        return
    assert sock is not None
    banner=b""
    while b"simulator DCS device, line 0" not in banner:
        data=sock.recv(4096)
        assert data
        banner+=data
    b=Path(coremap).parent
    patch=read(sym(coremap,"drm236_read_call"))
    base=(patch&MASK)-sym(b/"drm-mres.map","drm236_read_block_service")
    prefix=Path(os.environ.get("PDP10_PREFIX",str(Path.home()/"cross")))
    img=subprocess.check_output([str(prefix/"bin/dxrcheck"),"-d",str(b/"drm-mres.dxr")],text=True)
    off,=[int(a,8) for a in re.findall(r"(?m)^IMAGE\s+([0-7]+) 717140000001$",img)]
    assert read(base+off)==0o717140000001
    state["pc"]=base+off+1
    examine("break %06o\n"%state["pc"])

def after(token,coremap,examine,read,read_range,send,wait,output):
    if token!="B":
        return False
    assert sock is not None
    sock.sendall(b"Z")
    wait("Breakpoint, PC: %06o"%state["pc"],0,180)
    wait("sim> ",output.rfind(b"Breakpoint, PC:"),20)
    val=lambda n:read(sym(coremap,n))
    # A real receive wake has made the swapped owner runnable.
    # Its original kernel continuation cannot consume the mailbox until
    # the slot0 restoration has finished, so the byte must remain here.
    assert read(state["mail"])==0o133 and read(state["event"])==WORD
    assert val("proc_current_slot")==0
    ptr=state["ptr"]
    assert read(ptr+6)&0o200000 and read(ptr+7)==8192<<18
    req=val("drm236_active_request")&MASK
    assert req and read(req)>>18==0o4214*8 and read(req+1)==0
    assert read(req+2)==0
    assert val("proc_swap_blocks_used")==64 and val("backstore_blocks_used")==64
    print("PASS real TCP wake retained byte in mailbox during native RM10 READ",flush=True)
    examine("nobreak all\n")
    send(b"go\n")
    return False

try:
    H["run"](sys.argv,extra_snapshot=S["snapshot"],before_release=before,
             after_release=after,settle_snapshot=settle)
    coremap=Path(sys.argv[4])
    report=S["V"]["verify"](coremap,Path(sys.argv[5]).with_suffix(".clean").read_text(),
                            provider="drum",root="disk")
    assert all(r["errors"]==0 for r in report.values())
    assert report["B"]["writes"]-report["A"]["writes"]==64
    assert report["C"]["reads"]-report["B"]["reads"]==64
    Path(sys.argv[5]).with_name("report.json").write_text(json.dumps(report,indent=2)+"\n")
    print("PASS full native DCS-swapped reader, RM10 restore and six WAIT/canaries")
    for p,r in report.items():
        print(p,"MM",r["extents"],"free",r["free"],"bitmap",r["bitmap_used"],
              "reads/writes",r["reads"],r["writes"])
finally:
    if sock is not None:
        sock.close()

#!/usr/bin/env python3
"""Real KA10 RM10-backed swap, original six-child v1955 oracle."""
import json
import os
import struct
from pathlib import Path
import runpy
import sys

HERE = Path(__file__).resolve().parent
S = runpy.run_path(str(HERE.parent/"disk-swap-k09-v1955/host-v1955.py"))
V = runpy.run_path(str(HERE.parent/"disk-swap-k09-v1955/verify-v1955.py"))


def snapshot(token, coremap, core, read, read_range):
    S["extra_snapshot"](token, coremap, core, read, read_range)
    for n in ("mfsdev_drm_reads", "mfsdev_drm_writes", "drm236_active_request",
              "device_region_map", "backing_region_count"):
        read(S["V"]["source_symbol"](coremap,n))
    read(S["V"]["source_symbol"](coremap,"mfsdev_storage_errors")+5)
    read_range(0o152,2,core)
    if os.environ.get("V1972_DCS_IDLE") == "1":
        # DCS shares PI2 with RM10. No reader or connection is
        # active in this fixture. Every RM10 completion must bypass
        # DCS without creating a fictitious receive byte/event.
        dcs = Path(coremap).parent/"dcs-mres.dxr"
        header = struct.unpack("<2Q",dcs.read_bytes()[:16])
        assert header[0]>>18==0o447062 and header[1]&0o777777==2
        image = header[1]>>18
        patch = read(S["V"]["source_symbol"](coremap,"pdp10_pi_level2_dispatch_jump"))
        assert patch>>18==0o254000
        base = patch&0o777777
        assert read(base)==0o730240000001
        assert read(base+image)==0 and read(base+image+1)==0
        print("DCS idle mailbox/event zero at "+token,flush=True)



def settle(token, coremap, examine, read, send, wait, output):
    # A CTY marker can precede the final child BRK or the parent's
    # readchar sleep. Require native scheduler/VM states, not a delay.
    import re
    import time
    sym=lambda n:S["V"]["source_symbol"](coremap,n)
    high=8 if token=="B" else 2
    for attempt in range(24):
        ptr=read(sym("proc_table"))
        actual=read(sym("proc_high_slot"))
        if actual==high:
            text=examine("ex %o-%o\n"%(ptr,ptr+3*high-1))
            d={int(a,8):int(w,8) for a,w in re.findall(
                r"(?m)^(?:sim> )?([0-7]+):\s+([0-7]{12})\s*$",text)}
            assert len(d)==3*high
            if (all(d[ptr+3*i+2]>>33==3 for i in range(1,high))
                and all(d[ptr+3*i+1]>>18==8192 for i in range(2,high))
                and read(sym("storage_state"))==0
                and read(sym("drm236_active_request"))==0):
                print("Native quiescent barrier",token,"attempt",attempt+1,flush=True)
                return
        send(b"go\n")
        time.sleep(1.0)
        start=len(output)
        send(b"\x05")
        wait("sim> ",start,20)
    raise RuntimeError("native quiescent barrier not reached: "+token)

S["V"]["run"](sys.argv,extra_snapshot=snapshot,
             settle_snapshot=settle if os.environ.get("V1973_SETTLE")=="1" else None)
report=V["verify"](Path(sys.argv[4]),Path(sys.argv[5]).with_suffix(".clean").read_text(),
                   provider="drum",root=os.environ.get("V1971_ROOT","disk"))
assert all(r["errors"]==0 for r in report.values())
assert report["A"]["writes"]==0
assert report["B"]["writes"]-report["A"]["writes"]==report["B"]["bitmap_used"]
assert report["C"]["reads"]-report["B"]["reads"]==report["B"]["bitmap_used"]
assert report["C"]["writes"]==report["B"]["writes"]
Path(sys.argv[5]).with_name("report.json").write_text(json.dumps(report,indent=2)+"\n")
print("PASS native KA10 RM10 backing, exact canaries/WAIT and MM cleanup")
for p,r in report.items():
    print(p,"MM",r["extents"],"free",r["free"],"bitmap",r["bitmap_used"],
          "drum reads/writes",r["reads"],r["writes"])

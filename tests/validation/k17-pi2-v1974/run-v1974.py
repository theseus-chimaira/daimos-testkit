#!/usr/bin/env python3
"""Real TCP receive and native RM10 overlap; source-linked PI handlers."""
import os
from pathlib import Path
import re
import runpy
import socket
import struct
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
C=runpy.run_path(str(HERE.parent/"d6codec-shell-live-v1426/capture-v1426.py"))
root,prefix,w=map(lambda x:Path(x).resolve(),sys.argv[1:4])
port=int(sys.argv[4])
mode=int(sys.argv[5]) if len(sys.argv)>5 else 0
assert mode in (0,1,2)
w.mkdir()
dcs=w/"dcs-ka10.s"
source=(root/"system/kernel/drivers/dcs_io.s").read_text()
tail="dcs_pi_tail:\n        jrst pdp10_pi_handler_return"
assert source.count(tail)==1
source=source.replace(tail,"dcs_pi_tail:\n        jrst drm236_pi_handler")
dcs.write_text(".set DAIMOS_KA10,1\n        .globl drm236_pi_handler\n"+source)
src=[HERE/"probe-v1974.s",dcs,root/"system/kernel/drivers/rm10_io_v1970.s",
     root/"system/kernel/drivers/device_state.s",root/"system/kernel/core/ret.s"]
def run(*a):
    subprocess.run([str(x) for x in a],check=True)
objs=[]
for i,p in enumerate(src):
    obj=w/("part%d.dobj"%i)
    run(prefix/"bin/das","-F","-C","-O",obj,p)
    objs.append(obj)
absolute=w/"fixed.map"
absolute.write_text("ka10_df10_cia                    000150\nka10_df10_completion             000151\n")
run(prefix/"bin/dlink","-b","01000","-A",absolute,"-o",w/"probe.dxr","-M",w/"probe.map",*objs)
run(prefix/"bin/dxrconvert","--simh","-b","01000",w/"probe.dxr",w/"probe.rim")
rim=(w/"probe.rim").read_text().splitlines()
assert rim[-1]=="go 001000"
s={k:int(v,8) for k,v in re.findall(r"(?m)^(\w+)\s+([0-7]{6})$",(w/"probe.map").read_text())}
expected=[(0o123456701234+i*0o1030405)&((1<<36)-1) for i in range(128)]
media=w/"rm10.drm"
with media.open("wb") as f:
    f.truncate(345600*8)
    f.seek(0)
    f.write(struct.pack("<128Q",*expected))
before=media.read_bytes()
ini=w/"test.ini"
ini.write_text("\n".join(["set cpu 64k","set cpu oneseg","set cpu nomaoff",
    "set fha enabled","set fha0 rm10","attach -q fha0 "+str(media),
    "set dcs enabled","set dcs lines=8","attach -q dcs0 "+str(port),
    *rim[:-1],"deposit 152 123456701234","deposit 153 765432107654",
    "deposit %o %o"%(s["mode"],mode),
    "go 001000"])+"\n")
c=C["Console"](prefix/"bin/pdp10-ka",ini,w)
sock=None
try:
    c.take("sim> ",15)
    sock=socket.create_connection(("127.0.0.1",port),timeout=10)
    c.send("go %o\r"%(s["ready"]+1))
    banner=b""
    while b"simulator DCS device, line 0" not in banner:
        data=sock.recv(4096)
        assert data
        banner+=data
    if mode==2:
        # A physical breakpoint immediately after genuine RM10 wake.
        # Let DMA finish while the scanner is armed, but no TCP byte.
        # A separate monitor inspection proves it did not fabricate RX.
        c.stop()
        assert C["examine"](c,s["request"]+2,1)==[1]
        assert C["examine"](c,s["rx_count"],1)==[0]
        c.send("go\r")
    sock.sendall(b"Z")
    t=c.take("sim> ",30)
    assert "HALT instruction, PC: %06o"%s["passed"] in t,t
    def read(n,count=1):
        return C["examine"](c,s[n],count)
    assert read("received")==[0o132]
    assert read("overlap")==[int(mode!=2)]
    assert read("rx_first")==[int(mode==0)]
    assert read("dma_first")==[int(mode==2)]
    assert read("rx_count")==[1]
    assert read("wakes")==[2]
    assert read("request",3)[2]==1
    assert read("drm236_active_request")==[0]
    assert read("mfsdev_drm_reads")==[1]
    assert read("buffer",128)==expected
    assert C["examine"](c,s["buffer"]-1,1)==[0]
    assert C["examine"](c,s["buffer"]+128,1)==[0]
    assert C["examine"](c,0o150,4)==[
        (0o777600<<18)|(s["buffer"]-1),
        (0o151<<18)|(s["buffer"]+127),0o123456701234,0o765432107654]
    assert media.read_bytes()==before
    print("PASS shared PI2 mode",mode,"exact byte, 128 DMA words, two wakes, independent pair",flush=True)
finally:
    if sock is not None:
        sock.close()
    c.close()

#!/usr/bin/env python3
"""Source-linked native RM10 tests with the approved DF10 pair."""
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

MASK = (1 << 36) - 1
root, work = map(Path, sys.argv[1:])
work.mkdir()
prefix = Path(os.environ.get("PDP10_PREFIX", str(Path.home() / "cross")))
sources = [
    Path(__file__).with_name("probe-v1970.s"),
    root / "system/kernel/drivers/rm10_io_v1970.s",
    root / "system/kernel/drivers/device_state.s",
    root / "system/kernel/storage/storage_router.s",
    root / "system/kernel/core/ret.s",
]
def run(*args):
    subprocess.run([str(x) for x in args], check=True)

objs = []
for i, src in enumerate(sources):
    obj = work / ("part%d.dobj" % i)
    run(prefix/"bin/das", "-F", "-C", "-O", obj, src)
    objs.append(obj)
absolute = work/"fixed.map"
absolute.write_text("ka10_df10_cia                    000150\nka10_df10_completion             000151\n")
run(prefix/"bin/dlink", "-b", "01000", "-A", absolute, "-o", work/"probe.dxr",
    "-M", work/"probe.map", *objs)
run(prefix/"bin/dxrconvert", "--simh", "-b", "01000", work/"probe.dxr", work/"probe.rim")
rim = (work/"probe.rim").read_text().splitlines()
assert rim[-1] == "go 001000"
(work/"deposits.ini").write_text("\n".join(rim[:-1])+"\n")
sym = {k:int(v,8) for k,v in re.findall(r"(?m)^(\w+)\s+([0-7]{6})$", (work/"probe.map").read_text())}
for mode, block, unit, runtime in [
    ("read",0,0,0), ("write",29,0,1), ("read",30,1,1),
    ("write",2699,1,1), ("absent",0,2,1), ("locked",0,0,1),
    ("invalid",2700,0,1), ("nxm",0,0,1), ("timeout",0,0,1),
]:
    p = work / ("%s-%d-%d" % (mode,unit,block))
    p.mkdir()
    media = p/"media.drm"
    expected = [(0o123456701234 + (i + block*128)*0o1030405 + unit) & MASK for i in range(128)]
    with media.open("wb") as f:
        f.truncate(345600*8)
        if mode in ("read","nxm","timeout"):
            f.seek(block*128*8)
            f.write(struct.pack("<128Q",*expected))
    before = media.read_bytes()
    lines = ["set cpu 64k","set cpu oneseg","set cpu nomaoff","set fha enabled",
             "set fha0 rm10","set fha1 rm10"]
    if mode != "absent":
        lines.append("attach -q fha%d %s"%(unit,media))
    if mode == "locked":
        lines.append("set fha0 locked")
    lines += ["do "+str(work/"deposits.ini"),"deposit 152 123456701234","deposit 153 765432107654"]
    target = 0o177700 if mode=="nxm" else sym["buffer"]
    for k,v in (("raw",(unit<<16)|(block<<3)),("op",int(mode in ("write","locked"))),
                ("runtime",runtime),("target",target)):
        lines.append("deposit %o %012o"%(sym[k],v))
    if mode in ("write","locked"):
        lines += ["deposit %o %012o"%(target+i,w) for i,w in enumerate(expected)]
    if mode=="timeout":
        image=subprocess.check_output([str(prefix/"bin/dxrcheck"),"-d",str(work/"probe.dxr")],text=True)
        pc,=[int(a,8)+0o1001 for a in re.findall(r"(?m)^IMAGE\s+([0-7]+) 717140000001$",image)]
        lines += ["break %o"%pc]
    lines += ["go %o"%sym["start"]]
    if mode=="timeout":
        lines += ["detach fha0","nobreak all","go"]
    for n in ("result","elapsed","wakes","pi_count","drm236_active_request","mfsdev_drm_reads","mfsdev_drm_writes","mfsdev_storage_errors"):
        lines.append("ex %o"%(sym[n]+(5 if n=="mfsdev_storage_errors" else 0)))
    lines += ["ex 150-153","ex %o-%o"%(sym["buffer"]-1,sym["buffer"]+128)]
    # On error continue on the same controller, without resetting
    # PI or depositing any driver/DF10 state. The peer sector differs.
    recover = mode in ("absent","locked","nxm","timeout")
    if recover:
        peer = p/"peer.drm"
        peer_words = [(0o765432107654 + i*0o70103)&MASK for i in range(128)]
        with peer.open("wb") as f:
            f.truncate(345600*8)
            f.seek(30*128*8)
            f.write(struct.pack("<128Q",*peer_words))
        peer_before = peer.read_bytes()
        lines += ["echo V1970_RECOVER", "attach -q fha1 "+str(peer)]
        for k,v in (("raw",(1<<16)|(30<<3)),("op",0),("target",sym["buffer"])):
            lines.append("deposit %o %012o"%(sym[k],v))
        lines += ["go %o"%sym["recover"]]
        for n in ("result","elapsed","wakes","pi_count","drm236_active_request",
                  "mfsdev_drm_reads","mfsdev_drm_writes","mfsdev_storage_errors"):
            lines.append("ex %o"%(sym[n]+(5 if n=="mfsdev_storage_errors" else 0)))
        lines += ["ex 150-153","ex %o-%o"%(sym["buffer"]-1,sym["buffer"]+128)]
    lines.append("exit")
    ini=p/"test.ini"
    ini.write_text("\n".join(lines)+"\n")
    r=subprocess.run([str(prefix/"bin/pdp10-ka"),str(ini)],capture_output=True,text=True,timeout=30)
    log=r.stdout+r.stderr
    (p/"console.log").write_text(log)
    assert r.returncode==0 and "HALT instruction, PC: %06o"%sym["passed"] in log, log
    def words(t):
        return {int(k,8):int(v,8) for k,v in re.findall(r"(?m)^([0-7]+):\s+([0-7]+)",t)}
    first,_,second=log.partition("V1970_RECOVER")
    d=words(first)
    val=lambda n:d[sym[n]]
    success=mode in ("read","write")
    assert val("result")== (0 if success else MASK),log
    assert val("drm236_active_request")==0
    assert d[0o152]==0o123456701234 and d[0o153]==0o765432107654
    assert d[sym["buffer"]-1]==d[sym["buffer"]+128]==0
    assert val("wakes")==int(runtime and mode!="invalid")
    assert val("mfsdev_drm_reads")==int(mode=="read")
    assert val("mfsdev_drm_writes")==int(mode=="write")
    assert d[sym["mfsdev_storage_errors"]+5]==int(not success and mode!="invalid")
    if mode=="timeout":
        assert val("elapsed")==300,log
    if mode=="read":
        assert [d[target+i] for i in range(128)]==expected
    if success:
        assert d[0o151]==(0o151<<18)|(target+127)
    after=media.read_bytes()
    if mode=="write":
        start=block*128*8
        assert after[:start]==before[:start] and after[start+1024:]==before[start+1024:]
        assert list(struct.unpack("<128Q",after[start:start+1024]))==expected
    else:
        assert before==after
    print("PASS",mode,unit,block,"PI2",val("pi_count"),"ticks",val("elapsed"),flush=True)
    if recover:
        assert second.count("HALT instruction, PC: %06o"%sym["passed"])==1
        e=words(second)
        assert e[sym["result"]]==e[sym["drm236_active_request"]]==0
        assert e[sym["mfsdev_drm_reads"]]==1
        assert e[sym["mfsdev_drm_writes"]]==0
        assert e[sym["mfsdev_storage_errors"]+5]==1
        assert e[sym["wakes"]]==2
        assert e[sym["pi_count"]]==val("pi_count")+1
        assert e[0o151]==(0o151<<18)|(sym["buffer"]+127)
        assert e[0o152]==d[0o152] and e[0o153]==d[0o153]
        assert [e[sym["buffer"]+i] for i in range(128)]==peer_words
        assert peer.read_bytes()==peer_before
        print("PASS peer read after",mode,"without controller reset",flush=True)

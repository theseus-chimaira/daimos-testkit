#!/usr/bin/env python3
"""Read-only monitor replay of both real PI6 admission orderings."""
import argparse
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import time
import hashlib
import runpy

old = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                         "pure-k07-full-v1941/replay-v1941.py"))
symbols, words = old["symbols"], old["words"]
stages = (("IE","E"), ("D","D"), ("F","F"), ("G","G"),
          ("S","S"), ("Q","Q"), ("R","R"), ("V","V"),
          ("M","M"), ("A","A"), ("U","U"), ("Z","Z"))
def guest_marker(trace, marker, label):
    # SIMH flushes buffered DECtape on the EXPECT stop. That diagnostic
    # can follow the real guest marker before the monitor's echo.
    # Remove only the known full controller diagnostic, never arbitrary
    # monitor text or a fabricated checkpoint after a manual stop.
    prefix = trace.split("V1943_STAGE_"+label+"\n", 1)[0]
    prefix = re.sub(r"DTC[0-7]: writing buffer to file: [^\n]*\n",
                    "", prefix)
    return prefix.endswith(marker)


names = ("proc_current_slot","proc_high_slot","proc_table",
         "proc_swap_records","proc_exec_resv_head_v1933",
         "vfs_mount_root_base","dtfs_media_base","vfs_namespace_root",
         "vfs_mount_policy","mm_extent_count","mm_extent_capacity",
         "mm_arena_count","clk_tick_count","proc_timer_clock",
         "fs_provider_ready","fs_namespace_epoch_v1936")


def main():
    p=argparse.ArgumentParser()
    for n in ("build","work","prefix"):
        p.add_argument(n,type=Path)
    p.add_argument("--timeout",type=int,default=1150)
    a=p.parse_args()
    b,w,prefix=(x.resolve() for x in (a.build,a.work,a.prefix))
    w.mkdir(parents=True,exist_ok=True)
    media=w/"media"
    media.mkdir()
    sym=symbols(b/"kcore.map")
    assert all(n in sym for n in names)
    lines=[]
    for line in (b/"boot.ini").read_text().splitlines():
        f=line.split()
        if line.startswith("attach -q "):
            dev=f[2]
            if dev.startswith(("dsk","dr")):
                continue
            if dev.startswith(("dtc","mtc")):
                dst=media/(dev+".tap")
                shutil.copyfile(f[3],dst)
                line="attach -q "+dev+" "+str(dst)
        if line.startswith("attach -q -n "):
            line="attach -q -n "+f[3]+" "+str(media/(f[3]+".out"))
        if line.startswith("set -q -n log "):
            line="set -q -n log "+str(w/"simh.log")
        lines.append(line)
    ini="\n".join(lines)+"\n"
    assert ini.count("go 020\nexit\n")==1
    assert "set pclk REALTIME" in ini
    def scalars(label):
        return ("echo V1943_STAGE_"+label+"\n"+
                "".join("examine %06o\n"%sym[n] for n in names)+
                "echo V1943_SCALARS_"+label+"\n")
    ini=ini.replace("go 020\nexit\n",'expect "IE"\ngo 020\n'+scalars("E"))
    (w/"physical.ini").write_text(ini)
    helper=Path(__file__).resolve().parents[2]/"lib/daimos-simh-headless.sh"
    port=36000+os.getpid()%9000
    subprocess.run(["sh",str(helper),str(w/"physical.ini"),
                    str(w/"headless.ini"),str(port),str(port+12000)],check=True)
    (w/"images.sha256").write_text("".join(
        hashlib.sha256((b/n).read_bytes()).hexdigest()+"  "+n+"\n"
        for n in ("kcore.dxr","kinit.lowmem.words","pure-mres-v1612.dxr")))
    proc=subprocess.Popen(["stdbuf","-o0","-e0",str(prefix/"bin/pdp6"),
                          str(w/"headless.ini")],cwd=b,stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                         env=dict(os.environ,TERM="dumb"),bufsize=0)
    deadline=time.monotonic()+a.timeout
    buf=bytearray()
    with (w/"physical.log").open("wb",buffering=0) as log:
        def wait(marker,start):
            while marker.encode() not in buf[start:]:
                if time.monotonic()>=deadline:
                    raise RuntimeError("timeout before "+marker)
                if not select.select([proc.stdout],[],[],0.5)[0]:
                    continue
                chunk=os.read(proc.stdout.fileno(),65536)
                if not chunk:
                    raise RuntimeError("premature simulator exit")
                buf.extend(chunk);log.write(chunk)
                if len(buf)>4000000:
                    raise RuntimeError("oversized transcript")
            return buf[start:].decode("ascii","replace").replace("\r","")
        def send(cmd):
            n=len(buf);proc.stdin.write(cmd.encode("ascii"));proc.stdin.flush()
            return n
        def examine(addr,n):
            assert 0<addr<=0o137777 and 0<n<=272 and addr+n<=0o140000
            return "examine %06o-%06o\n"%(addr,addr+n-1)
        try:
            start=0
            for i,(marker,label) in enumerate(stages):
                t=wait("V1943_SCALARS_"+label,start)
                marker_ok = guest_marker(t, marker, label)
                d=words(t.split("V1943_STAGE_"+label,1)[1])
                high=d[sym["proc_high_slot"]]
                count=d[sym["mm_extent_count"]]
                assert 1<high<=24 and 0<count<=d[sym["mm_extent_capacity"]]<=136
                cmd=examine(d[sym["proc_table"]],high*3)
                cmd+=examine(d[sym["proc_swap_records"]],high)
                cmd+=examine(d[sym["vfs_mount_root_base"]],2)
                cmd+=examine(d[sym["dtfs_media_base"]],2)
                cmd+=examine(sym["mm_extents"],2*count)
                cmd+=examine(sym["mm_arenas"],d[sym["mm_arena_count"]])
                head=d[sym["proc_exec_resv_head_v1933"]]
                if head:
                    cmd+=examine(head,2)
                start=send(cmd+"echo V1943_END_"+label+"\n")
                wait("V1943_END_"+label,start)
                # Preserve physical tables on an interrupted run, but
                # never accept a monitor-generated label as a guest event.
                assert marker_ok, "missing actual guest marker "+marker
                print("v1943 checkpoint "+label+" clock "+
                      str(d[sym["proc_timer_clock"]])+" reservation "+
                      format(head,"06o"),flush=True)
                if i+1<len(stages):
                    nxt,nl=stages[i+1]
                    start=send('expect "%s"\ncont\n'%nxt+scalars(nl))
            start=send("cont\nexit\n")
            wait("HALT instruction",start);wait("Goodbye",start)
            assert proc.wait(timeout=10)==0
        finally:
            if proc.poll() is None:
                proc.terminate()
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill();proc.wait()
            while select.select([proc.stdout],[],[],0)[0]:
                data=os.read(proc.stdout.fileno(),65536)
                if not data: break
                buf.extend(data);log.write(data)
            (w/"physical.clean").write_bytes(bytes(buf).replace(b"\r",b""))
    print("v1943 physical replay complete: "+str(w))


if __name__=="__main__":
    main()

#!/usr/bin/env python3
"""Native KA10 CTY and Type-630 login; private media and TCP ports."""
import hashlib
import json
from pathlib import Path
import re
import runpy
import shutil
import socket
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

HERE = Path(__file__).resolve().parent
C = runpy.run_path(str(HERE.parent/"d6codec-shell-live-v1426/capture-v1426.py"))

class Terminal:
    def __init__(self, port, log):
        self.socket = socket.create_connection(("127.0.0.1",port),timeout=10)
        self.socket.settimeout(1)
        self.pending = b""
        self.log = log.open("wb",buffering=0)
    def take(self, marker, timeout=600):
        marker=marker.encode("ascii")
        deadline=time.monotonic()+timeout
        while marker not in self.pending:
            if time.monotonic()>deadline:
                raise TimeoutError(repr(self.pending[-500:]))
            try:
                data=self.socket.recv(4096)
            except socket.timeout:
                continue
            if not data:
                raise RuntimeError("DCS disconnected")
            self.log.write(data)
            self.pending+=data
        i=self.pending.index(marker)+len(marker)
        data,self.pending=self.pending[:i],self.pending[i:]
        return data.decode("latin-1")
    def send(self,data):
        self.socket.sendall(data.encode("ascii"))
    def close(self):
        self.socket.close()
        self.log.close()

def send(term,line):
    for ch in line:
        term.send(ch)
        time.sleep(.06)
    term.send("\r")

def command(term,line,expected):
    send(term,line)
    result=term.take("# ",600).replace("\r","")
    assert expected in [r.strip() for r in result.splitlines()], (line,result)
    assert not re.search(r"(?m)^(DSH:|\?RT|INIT: .*FAILED)",result),result

def login(term):
    term.take("LOGIN: ",600)
    send(term,"ROOT")
    term.take("DSH V1",600)
    term.take("# ",600)

def boot(build,prefix,w,root,drum,port):
    w.mkdir(parents=True)
    symbols={k:int(v,8) for k,v in re.findall(
        r"(?m)^(\w+)\s+([0-7]{6})$", (build/"kcore.map").read_text())}
    media=w/"rm10.drm"
    if drum:
        mk=str(prefix/"bin/mkauxstore")
        subprocess.run([mk,"--blank",str(media),"--blocks","05214"],check=True)
        subprocess.run([mk,"-i",str(media),"--confirm-destructive",
                        "--backstore-blocks","01000","--logstore-blocks","0",
                        "--cache-blocks","0","--d6fs-base","1",
                        "--d6fs-blocks","04213","--d6fs-super-a","0",
                        "--d6fs-super-b","1"],check=True)
    lines=[]
    for line in (build/"boot.ini").read_text().splitlines():
        if line.startswith(("attach -q dtc","attach -q dsk","attach -q ptr")):
            f=line.split()
            dest=w/(f[2]+Path(f[3]).suffix)
            shutil.copyfile(f[3],dest)
            line="attach -q "+f[2]+" "+str(dest)
        elif line.startswith("set -q -n log "):
            line="set -q -n log "+str(w/"simh.log")
        elif line.startswith("attach -q dcs0 "):
            line="attach -q dcs0 "+str(port)
        if line=="set fha disabled" and drum:
            lines+=["set fha enabled","set fha0 rm10","attach -q fha0 "+str(media)]
            continue
        if line!="exit":
            lines.append(line)
    assert "set dcs enabled" in lines and "attach -q dcs0 "+str(port) in lines
    ini=w/"boot.ini"
    ini.write_text("\n".join(lines)+"\n")
    c=C["Console"](prefix/"bin/pdp10-ka",ini,w)
    d=None
    try:
        # Attach before LOGIN starts so no initial prompt is lost.
        deadline=time.monotonic()+30
        while d is None:
            try:
                d=Terminal(port,w/"dcs.log")
            except OSError:
                if c.proc.poll() is not None or time.monotonic()>deadline:
                    raise
                time.sleep(.15)
        bootlog=c.take("INIT V1",600)
        assert re.search(r"DCS\s+OK",bootlog),bootlog
        assert "device number conflict" not in bootlog
        if drum:
            assert re.search(r"RM10\s+OK",bootlog)
        print(w.name,"native DCS installed; INIT",flush=True)
        # CTY and DCS must both receive prompts, then simultaneously
        # run separate shell commands with distinct result witnesses.
        login(c)
        d.take("simulator DCS device, line 0",600)
        # TMXR can accept a socket before it assigns the line to
        # the simulated scanner; the initial prompt may be lost.
        # A blank login attempt obtains a fresh guest prompt.
        send(d,"")
        login(d)
        print(w.name,"CTY and DCS0 ROOT shells",flush=True)
        with ThreadPoolExecutor(max_workers=2) as pool:
            jobs=[pool.submit(command,c,"ECHO CTY1972","CTY1972"),
                  pool.submit(command,d,"ECHO DCS1972","DCS1972")]
            for j in jobs:
                j.result()
        command(d,"PWD","/")
        send(d,"EXIT")
        d.take("LOGIN: ",600)
        send(d,"NOSUCH")
        d.take("LOGIN INCORRECT",600)
        login(d)
        command(d,"ECHO DCSRELOGIN1972","DCSRELOGIN1972")
        command(c,"ECHO CTYSTILL1972","CTYSTILL1972")
        c.stop()
        vals={n:C["examine"](c,symbols[n],1)[0] for n in
              ("vfs_namespace_root","backstore_blocks","backstore_blocks_used",
               "drm236_active_request","proc_high_slot","proc_table")}
        assert vals["vfs_namespace_root"]>>30==root
        assert vals["backstore_blocks"]==(512 if drum else (1024 if root==6 else 0))
        assert vals["backstore_blocks_used"]==vals["drm236_active_request"]==0
        assert C["examine"](c,0o152,2)==[0,0]
        (w/"report.json").write_text(json.dumps(vals,indent=2)+"\n")
        print(w.name,"PASS simultaneous CTY/DCS0, logout/respawn, backing",vals,flush=True)
    finally:
        if d is not None:
            d.close()
        try:
            if c.proc.poll() is None:
                c.stop()
        except Exception:
            pass
        c.close()

if __name__=="__main__":
    tape,disk,prefix,w=map(Path,sys.argv[1:5])
    start=int(sys.argv[5])
    profiles=[(n,b,r,d) for n,b,r in (("disk",disk,6),("tape",tape,7))
              for d in (False,True)]
    with ThreadPoolExecutor(max_workers=4) as pool:
        jobs=[pool.submit(boot,b,prefix,w/(n+("-rm10" if d else "-none")),r,d,start+i)
              for i,(n,b,r,d) in enumerate(profiles)]
        for j in jobs:
            j.result()

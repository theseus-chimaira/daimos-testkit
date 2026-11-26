#!/usr/bin/env python3
"""Historical CTY-only D6FS interactive sessions on private media."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import re
import runpy
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
C = runpy.run_path(str(HERE.parent/"d6codec-shell-live-v1426/capture-v1426.py"))

def boot(build, prefix, work, root, drum):
    work.mkdir(parents=True)
    symbols = {k:int(v,8) for k,v in re.findall(
        r"(?m)^(\w+)\s+([0-7]{6})$", (build/"kcore.map").read_text())}
    media = work/"rm10.drm"
    if drum:
        mk = str(prefix/"bin/mkauxstore")
        subprocess.run([mk,"--blank",str(media),"--blocks","05214"],check=True)
        subprocess.run([mk,"-i",str(media),"--confirm-destructive",
                        "--backstore-blocks","01000","--logstore-blocks","0",
                        "--cache-blocks","0","--d6fs-base","1",
                        "--d6fs-blocks","04213","--d6fs-super-a","0",
                        "--d6fs-super-b","1"],check=True)
    lines = []
    for line in (build/"boot.ini").read_text().splitlines():
        if line.startswith(("attach -q dtc","attach -q dsk","attach -q ptr")):
            f=line.split()
            dest=work/(f[2]+Path(f[3]).suffix)
            shutil.copyfile(f[3],dest)
            line="attach -q "+f[2]+" "+str(dest)
        elif line.startswith("set -q -n log "):
            line="set -q -n log "+str(work/"simh.log")
        if line=="set fha disabled" and drum:
            lines += ["set fha enabled","set fha0 rm10","attach -q fha0 "+str(media)]
            continue
        if line!="exit":
            lines.append(line)
    ini=work/"boot.ini"
    ini.write_text("\n".join(lines)+"\n")
    c=C["Console"](prefix/"bin/pdp10-ka",ini,work)
    def take(marker):
        return c.take(marker,900)
    def send(line):
        for ch in line:
            c.send(ch)
            time.sleep(.045)
        c.send("\r")
    def command(line, expected):
        send(line)
        s=take("# ").replace("\r","")
        # Echoed input is not a result witness.
        assert any(row.strip()==expected for row in s.splitlines()), (line,s)
        assert not re.search(r"(?m)^(DSH:|\?RT|INIT: .*FAILED)",s),s
    def say(*args):
        print(work.name,*args,flush=True)
    try:
        take("LOGIN: ")
        say("LOGIN prompt")
        send("NOSUCH")
        take("LOGIN INCORRECT")
        take("LOGIN: ")
        send("ROOT")
        take("DSH V1")
        take("# ")
        say("ROOT shell")
        command("PWD","/")
        command("ECHO K17SHELL1971","K17SHELL1971")
        say("PWD and ECHO")
        # External command, not a builtin; return to the same shell.
        send("TRUE")
        s=take("# ")
        assert not re.search(r"(?i)(not found|unknown|failed|DSH:)",s),s
        say("external TRUE returned")
        send("EXIT")
        take("LOGIN: ")
        send("ROOT")
        take("DSH V1")
        take("# ")
        command("ECHO K17RELOGIN1971","K17RELOGIN1971")
        say("EXIT and respawn")
        c.stop()
        vals={}
        for n in ("vfs_namespace_root","backstore_blocks","backstore_blocks_used",
                  "drm236_active_request","proc_high_slot","proc_table"):
            vals[n]=C["examine"](c,symbols[n],1)[0]
        assert vals["vfs_namespace_root"]>>30==root
        assert vals["backstore_blocks"]==(512 if drum else (1024 if root==6 else 0))
        assert vals["backstore_blocks_used"]==vals["drm236_active_request"]==0
        assert C["examine"](c,0o152,2)==[0,0]
        (work/"report.txt").write_text(repr(vals)+"\n")
        say("PASS interactive root",root,"RM10",drum,vals)
    finally:
        try:
            if c.proc.poll() is None:
                c.stop()
        except Exception:
            pass
        c.close()

def main():
    tape,disk,prefix,w=map(Path,sys.argv[1:])
    with ThreadPoolExecutor(max_workers=4) as pool:
        fs=[pool.submit(boot,b,prefix,w/(n+("-rm10" if drum else "-none")),root,drum)
            for n,b,root in (("disk",disk,6),) for drum in (False,True)]
        for f in fs:
            f.result()

if __name__=="__main__":
    main()

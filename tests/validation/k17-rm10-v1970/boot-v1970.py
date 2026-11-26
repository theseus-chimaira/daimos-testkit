#!/usr/bin/env python3
"""Four native 64K KA10 paper-tape root/AUXSTORE boot configurations."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys


def boot(build, prefix, work, root, drum):
    work.mkdir(parents=True)
    sym = {k:int(v,8) for k,v in re.findall(
        r"(?m)^(\w+)\s+([0-7]{6})$", (build/"kcore.map").read_text())}
    media = work/"rm10.drm"
    if drum:
        mk = prefix/"bin/mkauxstore"
        for args in (["--blank",media,"--blocks","05214"],
                     ["-i",media,"--confirm-destructive","--backstore-blocks","01000",
                      "--logstore-blocks","0","--cache-blocks","0",
                      "--d6fs-base","1","--d6fs-blocks","04213",
                      "--d6fs-super-a","0","--d6fs-super-b","1"],
                     ["--inspect",media]):
            with (work/"aux.log").open("a") as out:
                subprocess.run([str(mk),*map(str,args)],stdout=out,check=True)
        before = hashlib.sha256(media.read_bytes()).hexdigest()
    lines = []
    for line in (build/"boot.ini").read_text().splitlines():
        if line.startswith(("attach -q dtc","attach -q dsk")):
            f=line.split()
            dest=work/(f[2]+Path(f[3]).suffix)
            shutil.copyfile(f[3],dest)
            line="attach -q "+f[2]+" "+str(dest)
        elif line.startswith("set -q -n log "):
            line="set -q -n log "+str(work/"simh.log")
        if line=="set fha disabled" and drum:
            lines += ["set fha enabled","set fha0 rm10","attach -q fha0 "+str(media)]
            continue
        if line=="boot ptr":
            lines.append('expect "INIT V1" echo K17_RM10_INIT')
        if line=="exit":
            lines += ["ex RL","ex PL","ex 147-153"]
            for name in ("vfs_namespace_root","backstore_blocks","backstore_blocks_used",
                         "drm236_read_call","drm236_write_jump","storage_clock_drm_jump",
                         "drm236_active_request","mfsdev_drm_reads","mfsdev_drm_writes",
                         "device_region_map","backing_region_count"):
                lines.append("ex %06o"%sym[name])
        lines.append(line)
    ini=work/"boot.ini"
    ini.write_text("\n".join(lines)+"\n")
    with (work/"console.log").open("wb") as out:
        subprocess.run(["timeout","-k","3s","180s","stdbuf","-o0","-e0",
                        str(prefix/"bin/pdp10-ka"),str(ini)],stdout=out,stderr=subprocess.STDOUT,check=True)
    text=(work/"console.log").read_text(errors="replace")
    assert re.search(r"MACH\s+KA10",text) and re.search(r"MEM\s+64 K",text),text
    assert "INIT V1K17_RM10_INIT" in text,text
    assert not re.search(r"HALT instruction|device number conflict|Unknown command|\?RT|INIT: (RUN|RESPAWN) FAILED",text),text
    d={int(k,8):int(v,8) for k,v in re.findall(r"(?m)^([0-7]+):\s+([0-7]+)",text)}
    val=lambda n:d[sym[n]]
    assert val("vfs_namespace_root")>>30==root
    assert val("backstore_blocks")== (512 if drum else (1024 if root==6 else 0)),text
    assert val("backstore_blocks_used")==val("drm236_active_request")==0
    assert d[0o152]==d[0o153]==0
    if drum:
        assert re.search(r"RM10\s+OK",text),text
        assert val("mfsdev_drm_reads")>=1 and val("mfsdev_drm_writes")==0
        assert val("device_region_map")>>18==0o400000
        assert val("backing_region_count")==512
        assert d[0o150]>>18==0o777600 and d[0o151]>>18==0o151
        assert hashlib.sha256(media.read_bytes()).hexdigest()==before
    else:
        assert d[0o150]==d[0o151]==0
        assert val("mfsdev_drm_reads")==val("mfsdev_drm_writes")==0
    print("PASS root",root,"RM10",drum,"BACKSTORE",val("backstore_blocks"),
          "drum reads",val("mfsdev_drm_reads"),"map %012o"%val("device_region_map"),flush=True)


def main():
    tape,disk,prefix,w=map(Path,sys.argv[1:])
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures=[pool.submit(boot,b,prefix,w/(n+("-rm10" if drum else "-none")),root,drum)
                 for n,b,root in (("tape",tape,7),("disk",disk,6)) for drum in (False,True)]
        for f in futures:
            f.result()


if __name__=="__main__":
    main()

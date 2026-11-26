#!/usr/bin/env python3
"""Disposable split-member TSFS fixture; prove exact file/boot equivalence."""
from pathlib import Path
import hashlib
import os
import runpy
import subprocess
import sys

HERE=Path(__file__).resolve().parent
V=runpy.run_path(str(HERE.parent/"pure-k09-compact-v1957/verify-layout-v1957.py"))
words,region=V["words"],V["region"]
BLOCK,MASK=V["BLOCK"],V["MASK"]
build,root,w=map(lambda x:Path(x).resolve(),sys.argv[1:4])
mode=sys.argv[4]
assert mode in ("pressure","full")
w.mkdir()
manifest=w/"manifest"
lines=(build/"tsfs-root.manifest").read_text().splitlines()
if mode=="pressure":
    lines=[l for l in lines if l.startswith("D ") or
           l.split()[1] in ("/SYSTEM/INIT","/SYSTEM/EXEC/MOUNTALL") or
           l.split()[1].startswith("/CONFIG/")]
manifest.write_text("\n".join(lines)+"\n")
host=root/"tools/host"
s=(host/"mktsfs.c").read_text()
assert s.count("        data_member = 0U;")==1
src=w/"mktsfs-v1973.c"
src.write_text(s.replace("        data_member = 0U;","        data_member = 1U;"))
builder=w/"mktsfs-v1973"
subprocess.run([os.environ.get("HOST_CC","cc"),"-std=c99","-O2","-Wall","-Wextra","-Werror",
                "-I"+str(host),"-o",str(builder),str(src),str(host/"tsfs-format.c"),
                str(host/"d6block-codec-v1452.c")],check=True)
for exe,name in ((build/"mktsfs-v1461","reference"),(builder,"root")):
    subprocess.run([str(exe),"-n","3","-i","1:1","-g","1","-m",str(manifest),
                    "-b",str(build/"kinit.lowmem.words"),"-o",str(w/name)],check=True)
    subprocess.run([str(build/"tsfscheck-v1461")]+
                   [str(w/(name+str(i)+".dta")) for i in range(3)],check=True)
if mode=="full":
    for i in range(3):
        assert (w/("reference%d.dta"%i)).read_bytes()==(
            build/"media"/("dtc%d.tap"%i)).read_bytes()
    print("PASS complete reference equals stock original tape images",flush=True)
aa,bb=([words(w/(n+str(i)+".dta")) for i in range(3)] for n in ("reference","root"))
assert aa[0][:BLOCK]==bb[0][:BLOCK]
t,u=aa[0][3*BLOCK:4*BLOCK],bb[0][3*BLOCK:4*BLOCK]
assert t[:6]==u[:6] and t[7:12]==u[7:12] and t[12:16]==u[12:16]
assert t[7]>>18==1 and t[12]>>18==2
f,nf=t[8]&MASK,t[9]>>18
e,ne=t[13]&MASK,t[14]>>18
assert region(aa,0,f,nf)==region(bb,0,f,nf)
old,new=region(aa,0,e,ne),region(bb,0,e,ne)
first=578
for i in range(t[4]):
    x,y=old[4*i:4*i+4],new[4*i:4*i+4]
    assert x[0]==y[0] and x[2:]==y[2:]
    m,p=x[1]>>18,x[1]&MASK
    n,q=y[1]>>18,y[1]&MASK
    l=x[2]&MASK
    assert n in (1,2) and region(aa,m,p,l)==region(bb,n,q,l)
    if m==0:
        first=min(first,p)
tail=aa[0][3]
assert 0<tail<first
assert region(aa,0,tail,first-tail)==region(bb,0,tail,first-tail)
print("PASS",mode,t[3],"file records",t[4],"extents, exact bootstrap/file sectors",flush=True)
# Make a separate build view for the existing native test harnesses.
for p in build.iterdir():
    if p.name!="boot.ini" and not (w/p.name).exists():
        (w/p.name).symlink_to(p)
out=[]
for line in (build/"boot.ini").read_text().splitlines():
    if line.startswith("attach -q dtc"):
        v=line.split()
        unit=int(v[2][3:])
        if unit<3:
            line="attach -q "+v[2]+" "+str(w/("root%d.dta"%unit))
    out.append(line)
(w/"boot.ini").write_text("\n".join(out)+"\n")
paths=[build/"kcore.dxr",build/"kinit.dxr"]+[w/("root%d.dta"%i) for i in range(3)]
paths += [Path(l.split()[2]) for l in lines if l.startswith("F ")]
(w/"source.sha256").write_text("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+str(p)+"\n" for p in paths))

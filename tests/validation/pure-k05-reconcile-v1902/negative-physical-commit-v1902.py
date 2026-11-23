#!/usr/bin/env python3
"""Reject independently corrupted real PDP6 native target rollback traces."""

from pathlib import Path
import re
import subprocess
import sys


def change(text, stage, address, old, new):
    begin="V1902REC_STAGE_%s\n"%stage
    end="V1902REC_END_%s\n"%stage
    if text.count(begin)!=1 or text.count(end)!=1:
        raise ValueError("original physical stage not unique: "+stage)
    head,rest=text.split(begin,1)
    body,tail=rest.split(end,1)
    pattern=r"(?m)^(%o:\s*)([0-7]{12})$"%address
    vals=re.findall(pattern,body)
    if not vals or any(int(v,8)!=old for _,v in vals):
        raise ValueError("original native word drift: %06o"%address)
    body=re.sub(pattern,lambda m:m.group(1)+"%012o"%new,body)
    return head+begin+body+end+tail


def run(kit,build,work):
    path=work/"physical.clean"
    original=path.read_bytes()
    text=original.decode("ascii")
    # All words below are from the accepted source-linked 48K v1902
    # physical controller and actual original process table.
    slot3=0o45527
    uarea=0o46635
    source_pc=0o340000016702
    def clock_at(stage):
        start="V1902REC_STAGE_%s\n"%stage
        end="V1902REC_END_%s\n"%stage
        if text.count(start)!=1 or text.count(end)!=1:
            raise ValueError("original clock stage missing: "+stage)
        body=text.split(start,1)[1].split(end,1)[0]
        found=re.findall(r"(?m)^24526:\s*([0-7]{12})\s*$",body)
        if len(found)!=1:
            raise ValueError("original PCLK not uniquely observed")
        return int(found[0],8)
    clock_before=clock_at("BEFORE_TARGET_FREE")
    clock_after=clock_at("PARENT_AFTER_RECOVERY")
    if clock_after<=clock_before:
        raise ValueError("original native PCLK did not advance")
    controls=(
        ("fake-native-target-free-refusal",
         text.replace("V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_RETURN\n1:\t000000000000",
                      "V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_RETURN\n1:\t777777777773",1),
         "original native MM target free did not return MM_OK"),
        ("fake-no-MM-target-release",
         change(text,"TARGET_FREED",0o24251,17,18),
         "overlapping MM ownership"),
        ("fake-premature-TRANSITION-clear",
         change(text,"TARGET_FREED",slot3,0o46635600401,0o46635400401),
         "original process slot3/ROOT/TRANSITION invalid: TARGET_FREED"),
        ("fake-stuck-TRANSITION-after-rollback",
         change(text,"TRANSITION_UNLOCKED",slot3,0o46635400401,0o46635600401),
         "original process slot3/ROOT/TRANSITION invalid: TRANSITION_UNLOCKED"),
        ("fake-saved-executive-PC-change",
         change(text,"TRANSITION_UNLOCKED",uarea+0o20,source_pc,source_pc+1),
         "native rollback changed private continuation: TRANSITION_UNLOCKED"),
        ("fake-stale-parent-clock",
         change(text,"PARENT_AFTER_RECOVERY",0o24526,clock_after,clock_before),
         "original parent lost autonomous user HB/PCLK progress"),
    )
    verify=kit/"tests/validation/pure-k05-reconcile-v1902/verify-physical-commit-v1902.py"
    for name,mutated,error in controls:
        if mutated==text:
            raise ValueError("inert original physical mutation: "+name)
        path.write_text(mutated,encoding="ascii")
        try:
            r=subprocess.run([sys.executable,str(verify),str(kit),
                str(build),str(work)],capture_output=True,text=True)
        finally:
            path.write_bytes(original)
        if r.returncode==0 or error not in r.stderr:
            raise ValueError("unsafe native target physical %s not rejected: %s"%
                             (name,r.stderr.strip()))
        print("PASS v1902: native target physical %s rejected"%name)
    print("PASS v1902: %d independent source-linked native target controls"%len(controls))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-commit-v1902.py kit build physical-work")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,UnicodeError) as e:
        raise SystemExit("FAIL v1902 native target negative controls: "+str(e))

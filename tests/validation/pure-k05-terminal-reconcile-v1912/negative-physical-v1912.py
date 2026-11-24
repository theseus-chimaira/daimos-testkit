#!/usr/bin/env python3
"""Reject late target repair, premature unlock and forged terminal HALT."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit,build,work):
    tools=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    old=runpy.run_path(str(kit/"tests/validation/"
                          "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    x=old["values"](work/"expected-v1912.txt")
    trace=(work/"physical.clean").read_text(encoding="ascii")

    def mutate(stage,address,change):
        return tools["one_stage"](
            trace,"V1912_STAGE_"+stage,"V1912_END_"+stage,
            lambda s:tools["mutate_word"](s,address,change))

    bad=(
       ("foreign-target-not-really-repaired",
        tools["one_stage"](
            trace,"V1912_OWNER_REPAIR_AFTER","V1912_END_OWNER_REPAIR",
            lambda s:tools["mutate_word"](
                s,x["target_meta"],lambda v:0o1000002))),
       ("native-target-free-false-success",
        tools["one_stage"](
            trace,"V1912_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
            "V1912_STAGE_TARGET_FREED",
            lambda s:tools["mutate_word"](
                s,1,lambda v:0o777777777773))),
       ("premature-original-transition-clear",
        mutate("BEFORE_TARGET_FREE",x["table"]+9,
               lambda v:v&~(1<<16))),
       ("wrong-terminal-MM-extent-count",
        mutate("HALT",0o24253,lambda v:v+1)),
    )
    verify=(kit/"tests/validation/"
            "pure-k05-terminal-reconcile-v1912/verify-physical-v1912.py")
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1912-negative-") as p:
        scratch=Path(p)
        for name in ("physical.ini","physical-v1911.ini",
                     "expected-v1902.txt","expected-v1906.txt",
                     "expected-v1907.txt","expected-v1910.txt",
                     "expected-v1911.txt","expected-v1912.txt"):
            shutil.copy2(work/name,scratch/name)
        for label,mutant in bad:
            (scratch/"physical.clean").write_text(mutant,encoding="ascii")
            check=subprocess.run([sys.executable,str(verify),str(kit),
                                  str(build),str(scratch)],capture_output=True,
                                 text=True,timeout=40)
            if check.returncode==0 or \
               "FAIL v1912 real last-user reconcile/HALT:" not in check.stderr:
                raise ValueError("unsafe last-user terminal mutation accepted: "+label)
            print("PASS v1912 unsafe terminal trace rejected: "+label)
    print("PASS v1912: four targeted physical terminal negative controls")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1912.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1912 terminal negative controls: "+str(exc))

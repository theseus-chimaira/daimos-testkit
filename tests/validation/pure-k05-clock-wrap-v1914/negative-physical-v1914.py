#!/usr/bin/env python3
"""Reject unsafe clock-epoch, false hardware wrap and owner mutation."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit, build, work):
    helpers=runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    trace=(work / "physical.clean").read_text(encoding="ascii")

    def mutate(name,address,change):
        return helpers["one_stage"](
            trace,"V1914_STAGE_"+name,"V1914_END_"+name,
            lambda s:helpers["mutate_word"](s,address,change))

    faults=(
        ("rebase-epoch-not-in-step-with-clock",
         mutate("REBASE_AFTER",0o24532,lambda value:value+1)),
        ("hardware-clock-does-not-wrap",
         mutate("PI6_DONE_07",0o24530,lambda value:0o377777)),
        ("post-wrap-retry-early",
         mutate("POST_WRAP_RETRY_02",0o24530,lambda value:value-1)),
        ("foreign-target-owner-spuriously-repaired",
         mutate("POST_WRAP_DONE_03",0o24707,lambda value:0o1000003)),
    )
    checker=kit / "tests/validation/pure-k05-clock-wrap-v1914/verify-physical-v1914.py"
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home() / "tmp")),
            prefix="daimos-k05-v1914-negative-") as p:
        scratch=Path(p)
        for name in ("physical.ini","physical-v1913.ini",
                     "physical-v1911.ini","expected-v1902.txt",
                     "expected-v1906.txt","expected-v1907.txt",
                     "expected-v1910.txt","expected-v1911.txt",
                     "expected-v1913.txt","expected-v1914.txt"):
            shutil.copyfile(work/name,scratch/name)
        for label,changed in faults:
            (scratch/"physical.clean").write_text(changed,encoding="ascii")
            result=subprocess.run([sys.executable,str(checker),str(kit),
                                   str(build),str(scratch)],capture_output=True,
                                  text=True,timeout=45)
            if result.returncode==0 or \
               "FAIL v1914 original clock wrap:" not in result.stderr:
                raise ValueError("unsafe clock-wrap physical mutant accepted: "+label)
            print("PASS v1914 physical mutant rejected: "+label)
    print("PASS v1914: four independent clock/epoch/owner negative controls")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1914.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1914 physical negatives: "+str(exc))

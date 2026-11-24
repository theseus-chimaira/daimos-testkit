#!/usr/bin/env python3
"""Three independent unsafe PI6 physical witness mutations."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit,build,work):
    prior=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    prev=runpy.run_path(str(kit/"tests/validation/"
                        "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    pi=prev["values"](work/"expected-v1909.txt")
    e=prev["values"](work/"expected-v1906.txt")
    original=(work/"physical.clean").read_text(encoding="ascii")

    def mutate(start,end,addr,change):
        return prior["one_stage"](
            original,start,end,
            lambda s:prior["mutate_word"](s,addr,change))
    tests=(
        ("false-PI6-opcode",mutate(
            "V1909_ORIGINAL_CLOCK_PI6_HELD","V1909_STAGE_PI6_HELD",
            pi["pi6_pc"],lambda x:x^1)),
        ("PI6-not-in-idle",mutate(
            "V1909_ORIGINAL_CLOCK_PI6_HELD","V1909_STAGE_PI6_HELD",
            pi["pi6_save"],lambda x:(x&~0o777777)|0o4000)),
        ("PI6-lost-target-escrow",mutate(
            "V1909_STAGE_PI6_HELD","V1909_END_PI6_HELD",
            e["uarea"]+0o67,lambda x:x&~0o777777)),
    )
    verifier=kit/"tests/validation/pure-k05-held-pi6-v1909/verify-physical-v1909.py"
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-held-pi6-v1909-neg-") as tmp:
        dst=Path(tmp)
        for name in ("physical.ini","expected-v1902.txt",
                     "expected-v1906.txt","expected-v1907.txt",
                     "expected-v1908.txt","expected-v1909.txt"):
            shutil.copy2(work/name,dst/name)
        for name,data in tests:
            (dst/"physical.clean").write_text(data,encoding="ascii")
            proc=subprocess.run([sys.executable,str(verifier),str(kit),
                                 str(build),str(dst)],capture_output=True,
                                text=True,timeout=35)
            if proc.returncode==0 or \
               "FAIL v1909 native held-owner PI6:" not in proc.stderr:
                raise ValueError("unsafe PI6 mutant accepted: "+name)
            print("PASS v1909 PI6 mutant rejected: "+name)
    print("PASS v1909: three targeted PI6/escrow mutants")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1909.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1909 PI6 negatives: "+str(exc))

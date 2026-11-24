#!/usr/bin/env python3
"""Four targeted corruptions: real TERM result, MM, escrow and gate."""

from pathlib import Path
import os
import re
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit,build,work):
    helper=runpy.run_path(str(kit/"tests/validation/"
                          "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    proof=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    e=proof["values"](work/"expected-v1906.txt")
    v=proof["values"](work/"expected-v1907.txt")
    source=(work/"physical.clean").read_text(encoding="ascii")

    def mutant(label,addr,change):
        first="V1907_STAGE_TERM_REFUSED" if label=="TERM_REFUSED" else \
              "V1907_"+label
        return helper["one_stage"](
            source,first,"V1907_END_"+label,
            lambda s:helper["mutate_word"](s,addr,change))

    changed_result,n=re.subn(r"TR(\s*V1907_ORIGINAL_USER_TERM_REFUSED)",
                             r"TA\1",source,count=1)
    if n!=1:
        raise ValueError("real user TERM console marker not unique")
    changes=(
        ("TERM-accepted",changed_result),
        ("gate-armed-before-fault",mutant(
            "TERM_GATE_BEFORE",v["term_gate"],lambda x:v["term_value"])),
        ("freed-foreign-target",mutant(
            "TERM_REFUSED",e["target_meta"],lambda x:0o1000003)),
        ("lost-original-escrow",mutant(
            "TERM_REFUSED",e["uarea"]+0o67,
            lambda x:x&~0o777777)),
    )
    verifier=kit/"tests/validation/pure-k05-foreign-term-v1907/verify-physical-v1907.py"
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-term-v1907-mutant-") as tmp:
        dst=Path(tmp)
        for file in ("physical.ini","expected-v1902.txt",
                     "expected-v1906.txt","expected-v1907.txt"):
            shutil.copy2(work/file,dst/file)
        for name,data in changes:
            if data==source:
                raise ValueError("ineffective real physical corruption: "+name)
            (dst/"physical.clean").write_text(data,encoding="ascii")
            rc=subprocess.run([sys.executable,str(verifier),str(kit),
                               str(build),str(dst)],capture_output=True,
                              text=True,timeout=35)
            if rc.returncode==0 or \
                    "FAIL v1907 physical TERM/escrow:" not in rc.stderr:
                raise ValueError("unsafe mutation accepted: "+name)
            print("PASS v1907 unsafe physical mutant rejected: "+name)
    print("PASS v1907: four targeted unsafe TERM/escrow mutations")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1907.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,AssertionError,KeyError) as exc:
        raise SystemExit("FAIL v1907 negative TERM audit: "+str(exc))

#!/usr/bin/env python3
"""Reject three targeted unsafe last-orphan states in physical evidence."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit,build,work):
    old=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    read=runpy.run_path(str(kit/"tests/validation/"
                          "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    e=read["values"](work/"expected-v1906.txt")
    x=read["values"](work/"expected-v1911.txt")
    trace=(work/"physical.clean").read_text(encoding="ascii")

    def one(stage,address,new):
        return old["one_stage"](
            trace,"V1911_STAGE_"+stage,"V1911_END_"+stage,
            lambda s:old["mutate_word"](s,address,new))

    tests=(
       ("false-last-orphan-live-sibling",
        one("ONLY_ORPHAN",x["table"]+12,lambda old:0o47427400001)),
       ("lost-idle-retry-pending",
        one("IDLE_RETRY_2",x["pending"],lambda old:0)),
       ("lost-executive-escrow-after-final-PI6",
        one("LAST_PI6",e["uarea"]+0o67,lambda old:old&~0o777777)),
    )
    verify=(kit/"tests/validation/"
            "pure-k05-last-orphan-v1911/verify-physical-v1911.py")
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1911-negative-") as name:
        target=Path(name)
        for fname in ("physical.ini","expected-v1902.txt",
                      "expected-v1906.txt","expected-v1907.txt",
                      "expected-v1910.txt","expected-v1911.txt"):
            shutil.copy2(work/fname,target/fname)
        for label,mutant in tests:
            (target/"physical.clean").write_text(mutant,encoding="ascii")
            p=subprocess.run([sys.executable,str(verify),str(kit),
                              str(build),str(target)],capture_output=True,
                             text=True,timeout=40)
            if p.returncode==0 or \
                "FAIL v1911 last-orphan genuine PDP6 test:" not in p.stderr:
                raise ValueError("unsafe last-orphan trace accepted: "+label)
            print("PASS v1911 targeted physical mutant rejected: "+label)
    print("PASS v1911: three targeted last-orphan negative controls")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1911.py kit build work")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1911 physical negative controls: "+str(exc))

#!/usr/bin/env python3
"""Reject forged OOM/capacity or last foreign-orphan physical evidence."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit, build, work):
    helpers=runpy.run_path(str(kit/"tests/validation/"
                           "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    transcript=(work/"physical.clean").read_text(encoding="ascii")

    def mutate(stage,addr,fn):
        return helpers["one_stage"](
            transcript,"V1915_STAGE_"+stage,"V1915_END_"+stage,
            lambda s:helpers["mutate_word"](s,addr,fn))

    falsifications=(
        ("native-BRK-request-not-physically-impossible",
         helpers["one_stage"](
             transcript,"V1915_ORIGINAL_MM_ARENA_FITS",
             "V1915_STAGE_MM_ARENA_FITS",
             lambda s:helpers["mutate_word"](
                 s,1,lambda value:0o10000))),
        ("foreign-PROCESS-target-improperly-reowned",
         mutate("OOM_REQUESTER",0o24725,
                lambda value:0o1000003)),
        ("held-private-executive-escrow-lost",
         mutate("PARENT_GONE",0o47106,
                lambda value:0)),
        ("last-orphan-process-prematurely-free",
         mutate("LAST_PI6",0o45711,
                lambda value:0)),
    )
    verify=kit/"tests/validation/pure-k05-orphan-oom-v1915/verify-physical-v1915.py"
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1915-negative-") as p:
        scratch=Path(p)
        for name in ("physical.ini","physical-v1907.ini",
                     "expected-v1902.txt","expected-v1906.txt",
                     "expected-v1907.txt","expected-v1915.txt"):
            shutil.copyfile(work/name,scratch/name)
        for label,changed in falsifications:
            (scratch/"physical.clean").write_text(changed,encoding="ascii")
            result=subprocess.run([sys.executable,str(verify),str(kit),
                                   str(build),str(scratch)],capture_output=True,
                                  text=True,timeout=45)
            if result.returncode==0 or \
               "FAIL v1915 native orphan OOM:" not in result.stderr:
                raise ValueError("unsafe original OOM physical mutation accepted: "+label)
            print("PASS v1915 physical OOM mutant rejected: "+label)
    print("PASS v1915: four targeted source-linked BRK/owner/escrow controls")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1915.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1915 native OOM physical negatives: "+str(exc))

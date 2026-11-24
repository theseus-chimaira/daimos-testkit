#!/usr/bin/env python3
"""Reject four unsafe persisted foreign-orphan physical transcripts."""

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
    source=(work / "physical.clean").read_text(encoding="ascii")
    one=helpers["one_stage"]
    change=helpers["mutate_word"]

    def mutate(name,addr,fn):
        return one(source,"V1913_STAGE_"+name,"V1913_END_"+name,
                   lambda stage:change(stage,addr,fn))

    faults=(
        ("foreign-target-spuriously-reowned",
         mutate("RETRY_04",0o24707,lambda value:0o1000003)),
        ("late-unlock-before-authoritative-repair",
         mutate("RETRY_DONE_08",0o45711,
                lambda value:value&~0o200000)),
        ("lost-original-executive-escrow",
         mutate("RETRY_12",0o47106,lambda value:value&~0o777777)),
        ("false-capped-clock-cadence",
         mutate("RETRY_09",0o24530,lambda value:value+1)),
    )
    check=kit / "tests/validation/pure-k05-permanent-orphan-v1913/verify-physical-v1913.py"
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home() / "tmp")),
            prefix="daimos-k05-v1913-negative-") as d:
        temporary=Path(d)
        for name in ("physical.ini","physical-v1911.ini",
                     "expected-v1902.txt","expected-v1906.txt",
                     "expected-v1907.txt","expected-v1910.txt",
                     "expected-v1911.txt","expected-v1913.txt"):
            shutil.copyfile(work / name,temporary / name)
        for label,mutant in faults:
            (temporary / "physical.clean").write_text(mutant,encoding="ascii")
            result=subprocess.run([sys.executable,str(check),str(kit),
                                   str(build),str(temporary)],capture_output=True,
                                  text=True,timeout=45)
            if result.returncode==0 or \
               "FAIL v1913 persistent terminal orphan:" not in result.stderr:
                raise ValueError("unsafe original physical mutation accepted: "+label)
            print("PASS v1913 physical mutant rejected: "+label)
    print("PASS v1913: four targeted permanent-owner negative controls")


if __name__ == "__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1913.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1913 physical negatives: "+str(exc))

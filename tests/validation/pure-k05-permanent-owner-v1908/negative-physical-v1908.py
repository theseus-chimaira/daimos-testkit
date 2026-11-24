#!/usr/bin/env python3
"""Three focused physical negatives: publication, cap and parent clock."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit, build, work):
    prior=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    data=runpy.run_path(str(kit/"tests/validation/"
                        "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    sym=runpy.run_path(str(kit/"tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core=sym["symbols"](build/"kcore.map")
    e=data["values"](work/"expected-v1906.txt")
    script=(work/"physical.clean").read_text(encoding="ascii")
    label="LONG_HELD_HB_10"
    def mutate(address,change):
        return prior["one_stage"](
            script,"V1908_STAGE_"+label,"V1908_END_"+label,
            lambda text:prior["mutate_word"](text,address,change))
    tests=(
        ("premature-transition-unlock",mutate(
            e["process_table"]+9,lambda x:x&~(1<<16))),
        ("retry-over-cap",mutate(
            core["proc_timer_clock"]+2,
            lambda x:(x&~(0o377777<<18))|(0o2000<<18))),
        ("stalled-parent-PCLK",mutate(
            core["proc_timer_clock"],lambda x:x-0o100)),
    )
    verifier=kit/"tests/validation/pure-k05-permanent-owner-v1908/verify-physical-v1908.py"
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1908-negative-") as tmp:
        dest=Path(tmp)
        for filename in ("physical.ini","expected-v1902.txt",
                         "expected-v1906.txt","expected-v1907.txt",
                         "expected-v1908.txt"):
            shutil.copy2(work/filename,dest/filename)
        for label,mutant in tests:
            (dest/"physical.clean").write_text(mutant,encoding="ascii")
            result=subprocess.run([sys.executable,str(verifier),str(kit),
                                   str(build),str(dest)],capture_output=True,
                                  text=True,timeout=35)
            if result.returncode==0 or \
                    "FAIL v1908 original long-held owner physical:" not in result.stderr:
                raise ValueError("unsafe v1908 physical mutant accepted: "+label)
            print("PASS v1908 targeted mutant rejected: "+label)
    print("PASS v1908: 3 targeted terminal/backoff/clock mutations")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1908.py kit build work")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1908 targeted mutants: "+str(exc))

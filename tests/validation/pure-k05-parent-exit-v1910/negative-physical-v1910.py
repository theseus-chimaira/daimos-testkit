#!/usr/bin/env python3
"""Three focused native EXIT/foreign-owner transcript rejection tests."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit, build, work):
    prior = runpy.run_path(str(kit / "tests/validation/"
                           "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    old = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    symbols = runpy.run_path(str(kit / "tests/validation/"
                             "pure-k05-secondary-physical-v1845/prepare-v1845.py"))[
                             "symbols"]
    core = symbols(build / "kcore.map")
    e = old["values"](work / "expected-v1906.txt")
    x = old["values"](work / "expected-v1910.txt")
    original = (work / "physical.clean").read_text(encoding="ascii")

    def mutate(label, address, change):
        return prior["one_stage"](
            original, "V1910_STAGE_" + label, "V1910_END_" + label,
            lambda text: prior["mutate_word"](text, address, change))

    tests = (
        ("parent-EXIT-without-slot0", mutate(
            "FINALIZER", core["proc_current_slot"],lambda v:1)),
        ("child-TRANSITION-lost-on-adoption", mutate(
            "PARENT_GONE",e["process_table"]+9,lambda v:v&~(1<<16))),
        ("child-escrow-lost-after-EXIT", mutate(
            "POST_EXIT_PI6",e["uarea"]+0o67,lambda v:v&~0o777777)),
    )
    verifier = (kit / "tests/validation/"
                "pure-k05-parent-exit-v1910/verify-physical-v1910.py")
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1910-negative-") as name:
        out = Path(name)
        for filename in ("physical.ini","expected-v1902.txt",
                         "expected-v1906.txt","expected-v1907.txt",
                         "expected-v1910.txt"):
            shutil.copy2(work / filename, out / filename)
        for label, mutant in tests:
            (out / "physical.clean").write_text(mutant,encoding="ascii")
            r = subprocess.run([sys.executable,str(verifier),str(kit),
                                str(build),str(out)],capture_output=True,
                               text=True,timeout=40)
            if r.returncode==0 or \
               "FAIL v1910 original parent EXIT/foreign FULL:" not in r.stderr:
                raise ValueError("unsafe physical parent EXIT mutant accepted: "+label)
            print("PASS v1910 targeted native EXIT mutant rejected: "+label)
    print("PASS v1910: three parent EXIT/child escrow negative controls")


if __name__ == "__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1910.py kit build work")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1910 target negatives: "+str(exc))

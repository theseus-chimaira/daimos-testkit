#!/usr/bin/env python3
"""Reject independently corrupted original PDP-6 v1906 foreign-MM traces."""

from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit, build, work):
    helper=runpy.run_path(str(kit/"tests/validation/"
                      "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    proof=runpy.run_path(str(kit/"tests/validation/"
                     "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    old=runpy.run_path(str(kit/"tests/validation/"
                   "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core=old["symbols"](build/"kcore.map")
    e=proof["values"](work/"expected-v1906.txt")
    source=(work/"physical.clean").read_text(encoding="ascii")

    def stage(label,addr,fn):
        return helper["one_stage"](
            source,"V1906_STAGE_"+label,"V1906_END_"+label,
            lambda t:helper["mutate_word"](t,addr,fn))

    first=proof["section"](source,"V1906_STAGE_FOREIGN_HELD_HB_1",
                           "V1906_END_FOREIGN_HELD_HB_1")
    pclk=proof["word"](first,core["proc_timer_clock"])
    mutations=(
        ("false-original-target-preflight",helper["one_stage"](
            source,"V1906_FOREIGN_TARGET_INJECT",
            "V1906_END_FOREIGN_TARGET_INJECT",
            lambda t:helper["mutate_word"](
                t,e["target_meta"],lambda x:0o1000002))),
        ("target-foreign-owner-lost",stage(
            "FOREIGN_HELD_HB_1",e["target_meta"],lambda x:0o1000003)),
        ("target-retagged-module",stage(
            "FOREIGN_HELD_HB_2",e["target_meta"],lambda x:0o3000002)),
        ("raw-source-lost",stage(
            "FOREIGN_HELD_HB_2",e["source_meta"],lambda x:x^1)),
        ("premature-transition-clear",stage(
            "FOREIGN_HELD_HB_2",e["process_table"]+9,
            lambda x:x&~(1<<16))),
        ("missing-target-escrow",stage(
            "FOREIGN_HELD_HB_2",e["uarea"]+0o67,
            lambda x:x&~0o777777)),
        ("incorrect-target-escrow",stage(
            "FOREIGN_HELD_HB_3",e["uarea"]+0o67,
            lambda x:x^1)),
        ("changed-private-executive-pc",stage(
            "FOREIGN_HELD_HB_1",e["uarea"]+0o20,lambda x:x^1)),
        ("lost-shared-retry-backoff",stage(
            "FOREIGN_HELD_HB_2",core["proc_timer_clock"]+2,
            lambda x:x&~(1<<35))),
        ("stale-parent-pclk",stage(
            "FOREIGN_HELD_HB_2",core["proc_timer_clock"],
            lambda x:pclk)),
        ("false-repaired-target-preflight",helper["one_stage"](
            source,"V1906_FOREIGN_TARGET_REPAIR",
            "V1906_END_FOREIGN_TARGET_REPAIR",
            lambda t:helper["mutate_word"](
                t,e["target_meta"],lambda x:0o1000003))),
        ("native-target-free-refused",helper["one_stage"](
            source,"V1906_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
            "V1906_STAGE_TARGET_FREED",
            lambda t:helper["mutate_word"](
                t,1,lambda x:0o777777777773))),
        ("early-parent-wait-gate",stage(
            "FULL_COMMITTED",e["parent_gate"],lambda x:0o12345670123)),
        ("missing-committed-APR",stage(
            "FULL_COMMITTED",e["process_table"]+10,
            lambda x:x&~0o777777)),
        ("missing-typed-WAIT",source.replace(
            "V1906_ORIGINAL_PARENT_TYPED_WAIT_Z\n","",1)),
        ("missing-real-HALT",source.replace(
            "HALT instruction, PC: 000000","HALT instruction, PC: 004000",1)),
    )
    verifier=kit/"tests/validation/pure-k05-foreign-target-v1906/verify-physical-v1906.py"
    root=Path(os.environ.get("TMPDIR",str(Path.home()/"tmp")))
    with tempfile.TemporaryDirectory(dir=root,
                                     prefix="daimos-k05-v1906-mutants-") as name:
        dest=Path(name)
        for fname in ("physical.ini","expected-v1902.txt",
                      "expected-v1906.txt"):
            shutil.copy2(work/fname,dest/fname)
        for label,mutant in mutations:
            if mutant==source:
                raise ValueError("mutation was ineffective: "+label)
            (dest/"physical.clean").write_text(mutant,encoding="ascii")
            rc=subprocess.run([sys.executable,str(verifier),str(kit),
                               str(build),str(dest)],capture_output=True,
                              text=True,timeout=40)
            if rc.returncode==0 or \
                    "FAIL v1906 original PDP6 escrow physical:" not in rc.stderr:
                raise ValueError("unsafe physical mutation not rejected: "+label)
            print("PASS v1906 unsafe physical mutant rejected: "+label)
    print("PASS v1906: %d independent native-physical unsafe mutations" %
          len(mutations))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1906.py kit build work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1906 negative physical audit: " + str(exc))

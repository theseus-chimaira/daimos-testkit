#!/usr/bin/env python3
"""Reject unsafe mutations of the real persistent-target-pin PDP-6 trace."""

from pathlib import Path
import os
import re
import runpy
import shutil
import subprocess
import sys
import tempfile


def run(kit, build, work):
    previous = runpy.run_path(str(kit / "tests/validation/"
                           "pure-k05-full-commit-v1903/negative-physical-v1903.py"))
    proof = runpy.run_path(str(kit / "tests/validation/"
                        "pure-k05-target-pin-idle-v1904/verify-physical-v1904.py"))
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    source = (work / "physical.clean").read_text(encoding="ascii")
    expected = proof["values"](work / "expected-v1904.txt")
    old = proof["values"](work / "expected-v1903.txt")
    raw = proof["values"](work / "expected-v1902.txt")
    core = base["symbols"](build / "kcore.map")

    def stage(label,addr,replace):
        return previous["one_stage"](
            source,"V1904_STAGE_"+label,"V1904_END_"+label,
            lambda x:previous["mutate_word"](x,addr,replace))

    first = proof["section"](source,"V1904_STAGE_HELD_HB_1",
                              "V1904_END_HELD_HB_1")
    prev_clock = proof["word"](first,core["proc_timer_clock"])
    mutations = (
        ("wrong-foreign-parent-descriptor",previous["one_stage"](
            source,"V1904_TARGET_EXTERNAL_PIN_INSTALL",
            "V1904_END_TARGET_PIN_INSTALL",
            lambda s:previous["mutate_word"](
                s,expected["target_meta"],lambda x:0o1000001))),
        ("unpin-before-release",stage("HELD_HB_1",expected["target_meta"],
                                      lambda x:expected["target_pin0"])),
        ("lost-authoritative-raw",stage("HELD_HB_2",raw["source_meta"],
                                        lambda x:x^1)),
        ("early-transition-clear",stage("HELD_HB_2",
                                         old["process_table"]+9,
                                         lambda x:x&~(1<<16))),
        ("forged-runnable-vm",stage("HELD_HB_3",
                                    old["process_table"]+10,
                                    lambda x:(x&~0o777777)|0o120000)),
        ("changed-saved-executive-pc",stage("HELD_HB_2",
                                             old["uarea"]+0o20,
                                             lambda x:x^1)),
        ("cleared-retry-marker",stage("HELD_HB_1",
                                       old["uarea"]+0o67,lambda x:0)),
        ("lost-shared-backoff",stage("HELD_HB_2",
                                      expected["retry_word"],
                                      lambda x:x&~(1<<35))),
        ("stale-clock",stage("HELD_HB_2",core["proc_timer_clock"],
                             lambda x:prev_clock)),
        ("preexisting-parent-wait-gate",stage("HELD_HB_3",
                                                old["parent_gate"],
                                                lambda x:0o12345670123)),
        ("premature-target-free",stage("HELD_HB_2",
                                        core["mm_extent_count"],
                                        lambda x:x-1)),
        ("false-target-pin-release",previous["one_stage"](
            source,"V1904_TARGET_EXTERNAL_PIN_RELEASE",
            "V1904_END_TARGET_PIN_RELEASE",
            lambda s:previous["mutate_word"](
                s,expected["target_meta"],lambda x:expected["target_pin0"]))),
    )
    verifier = kit / "tests/validation/pure-k05-target-pin-idle-v1904/verify-physical-v1904.py"
    tmp_root = os.environ.get("TMPDIR",str(Path.home() / "tmp"))
    with tempfile.TemporaryDirectory(dir=tmp_root,
                                     prefix="daimos-k05-v1904-negative-") as name:
        scratch = Path(name)
        for file in ("physical.ini","expected-v1902.txt",
                     "expected-v1903.txt","expected-v1904.txt"):
            shutil.copy2(work / file,scratch / file)
        for label,altered in mutations:
            if altered == source:
                raise ValueError("ineffective original trace corruption: " + label)
            (scratch / "physical.clean").write_text(altered,encoding="ascii")
            result = subprocess.run([sys.executable,str(verifier),str(kit),
                                     str(build),str(scratch)],
                                    capture_output=True,text=True,timeout=35)
            if result.returncode == 0 or \
                    "FAIL v1904 real PDP6 persistent-pin test:" not in result.stderr:
                raise ValueError("unsafe physical mutation not specifically rejected: " + label)
            print("PASS v1904 unsafe physical mutant rejected: " + label)
    print("PASS v1904: %d independent unsafe physical mutations" % len(mutations))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-physical-v1904.py kit build work")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1904 negative physical audit: " + str(exc))

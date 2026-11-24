#!/usr/bin/env python3
"""Execute independent unsafe mutations of genuine v1903 physical proof."""

from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile


def one_stage(trace, start, end, transform):
    a, b = start + "\n", end + "\n"
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("missing original physical segment: " + start)
    prefix, rest = trace.split(a, 1)
    inside, suffix = rest.split(b, 1)
    result = transform(inside)
    if result == inside:
        raise ValueError("mutation did not affect physical evidence")
    return prefix + a + result + b + suffix


def mutate_word(text, address, change):
    pattern = r"(?m)^(%o:\s*)([0-7]{12})(\s*)$" % address
    matches = list(re.finditer(pattern, text))
    # The original MM-count scalar is examined both independently and
    # in the contiguous KCORE scalar window. All equal observations
    # must be changed together, or the negative would only prove that
    # duplicate transcript readings disagree.
    if not matches or len({m.group(2) for m in matches}) != 1:
        raise ValueError("original physical witness absent/ambiguous: %06o" % address)
    current = int(matches[0].group(2), 8)
    altered = change(current)
    if current == altered or not 0 <= altered < (1 << 36):
        raise ValueError("invalid or ineffective unsafe physical mutation")
    return re.sub(pattern,lambda m:m.group(1)+"%012o" % altered+m.group(3),text)


def run(verifier, kit, build, work):
    source = (work / "physical.clean").read_text(encoding="ascii")
    vals = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work / "expected-v1903.txt").read_text(encoding="ascii")))
    core_map = (build / "kcore.map").read_text(encoding="ascii")
    core_counts = re.findall(r"(?m)^mm_extent_count\s+([0-7]+)$",core_map)
    if len(core_counts) != 1:
        raise ValueError("source-linked physical MM count symbol not unique")
    count_addr = int(core_counts[0],8)
    stage = lambda a,b,addr,fn: one_stage(
        source,"V1903_"+a,"V1903_"+b,
        lambda text: mutate_word(text,addr,fn))
    faults = (
        ("false-source-refusal-success",one_stage(
            source,"V1902_REAL_MM_FREE_REFUSED","V1902_STAGE_NATIVE_REFUSED",
            lambda s:mutate_word(s,1,lambda v:0))),
        ("false-target-free-refusal",stage(
            "ORIGINAL_NATIVE_TARGET_FREE_RETURN","STAGE_TARGET_FREED",
            1,lambda v:0o777777777773)),
        ("false-second-source-free-refusal",stage(
            "SECOND_NATIVE_SOURCE_FREE_RETURN","STAGE_SOURCE_FREED",
            1,lambda v:0o777777777773)),
        ("premature-transition",stage(
            "STAGE_FULL_COMMITTED","END_FULL_COMMITTED",
            vals["process_table"]+9,lambda v:v|(1<<16))),
        ("missing-committed-APR",stage(
            "STAGE_FULL_COMMITTED","END_FULL_COMMITTED",
            vals["process_table"]+10,lambda v:v&~0o777777)),
        ("stale-raw-owner-count",stage(
            "STAGE_SOURCE_FREED","END_SOURCE_FREED",
            count_addr,lambda v:v+1)),
        ("premature-parent-gate",stage(
            "STAGE_FULL_COMMITTED","END_FULL_COMMITTED",
            vals["parent_gate"],lambda v:0o12345670123)),
        ("changed-private-PC",stage(
            "STAGE_TARGET_FREED","END_TARGET_FREED",
            vals["uarea"]+0o20,lambda v:v^1)),
        ("missing-parent-typed-WAIT",source.replace(
            "V1903_ORIGINAL_PARENT_TYPED_WAIT_Z\n","",1)),
        ("missing-real-halt",source.replace(
            "HALT instruction, PC: 000000","HALT instruction, PC: 004074",1))
    )
    tmp_root = os.environ.get("TMPDIR",str(Path.home() / "tmp"))
    with tempfile.TemporaryDirectory(dir=tmp_root,
                                     prefix="daimos-k05-v1903-negative-") as tmp:
        scratch = Path(tmp)
        for name in ("expected-v1902.txt","expected-v1903.txt","physical.ini"):
            shutil.copy2(work / name, scratch / name)
        for name, text in faults:
            if text == source:
                raise ValueError("negative physical witness ineffective: " + name)
            (scratch / "physical.clean").write_text(text, encoding="ascii")
            check = subprocess.run([sys.executable, str(verifier),str(kit),
                                    str(build),str(scratch)],
                                   capture_output=True,text=True,timeout=35)
            if check.returncode == 0:
                raise ValueError("unsafe physical mutation ACCEPTED: " + name)
            if "FAIL v1903" not in check.stderr:
                raise ValueError("mutant failed for unrelated reason: " + name)
            print("PASS unsafe native physical mutant rejected: " + name)
    print("PASS v1903: %d independent unsafe negative controls" % len(faults))


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: negative-physical-v1903.py verifier kit build work")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1903 negative physical: " + str(exc))

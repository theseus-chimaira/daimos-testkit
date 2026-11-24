#!/usr/bin/env python3
"""Recognize unsafe original transition publication under foreign MM claim."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def section(trace, first, last):
    a, b = first+"\n", last+"\n"
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("source-linked physical stage missing: " + first)
    return trace.split(a,1)[1].split(b,1)[0]


def word(text, addr):
    values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr,text)
    if not values or len(set(values)) != 1:
        raise ValueError("invalid physical word at %06o" % addr)
    return int(values[0],8)


def values(path):
    return dict((k,int(v,8)) for k,v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        path.read_text(encoding="ascii")))


def verify(kit, build, work):
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = base["symbols"](build / "kcore.map")
    e = values(work / "expected-v1905.txt")
    old = values(work / "expected-v1902.txt")
    script = (work / "physical.ini").read_text(encoding="ascii")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    kcore_hash = hashlib.sha256((build/"kcore.dxr").read_bytes()).hexdigest()
    pure_hash = hashlib.sha256((build/"pure-mres-v1612.dxr").read_bytes()).hexdigest()
    if kcore_hash != \
            "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
            pure_hash != \
            "55be5113d4d15fe5c4a44409dca22afd463c75f05f661b3f8f71451a057c577f":
        raise ValueError("different from original accepted v1903 production binaries")
    if e["target_meta"] != core["mm_extents"]+0o41 or \
            e["source_meta"] != old["source_meta"] or \
            e["foreign_meta"] != (1<<18)|2 or \
            e["own_meta"] != (1<<18)|3 or \
            script.count("deposit %06o %012o\n" %
                         (e["target_meta"],e["foreign_meta"])) != 1 or \
            script.count("deposit %06o %012o\n" %
                         (old["source_meta"],old["source_pin0"])) != 1:
        raise ValueError("foreign claim not exact single MM target owner fault")
    stages = ("V1902_REAL_MM_FREE_REFUSED",
              "V1902_ORIGINAL_FAILED_FULL_RETURN",
              "V1902_REAL_PARENT_HEARTBEAT_PINNED",
              "V1902_EXTERNAL_PIN_RELEASE", "V1902_END_PIN_RELEASE",
              "V1905_FOREIGN_TARGET_INJECT",
              "V1905_END_FOREIGN_TARGET_INJECT",
              "V1905_ORIGINAL_TRANSITION_CLEAR_PC",
              "V1905_STAGE_UNSAFE_CLEAR", "V1905_END_UNSAFE_CLEAR")
    marks = [s+"\n" for s in stages]
    if any(trace.count(s)!=1 for s in marks) or \
            [trace.index(s) for s in marks] != sorted(trace.index(s) for s in marks):
        raise ValueError("original retry/foreign physical milestones reordered")
    if not re.search(r"Breakpoint, PC: %06o " % e["transition_clear"],trace):
        raise ValueError("original transition-clear machine instruction not executed")
    if word(section(trace,"V1905_FOREIGN_TARGET_INJECT",
                    "V1905_END_FOREIGN_TARGET_INJECT"),e["target_meta"]) != \
            e["own_meta"]:
        raise ValueError("original target was not owned by original child pre-fault")
    old_scalar,old_owners = mm["stage"](
        trace.replace("V1902_","V1638_"),core,"PINNED_HB")
    new_scalar,new_owners = mm["stage"](
        trace.replace("V1905_","V1638_"),core,"UNSAFE_CLEAR")
    source_pin1 = (0o111200,0o120000,4,1,3)
    source_pin0 = (0o111200,0o120000,4,0,3)
    target_slot3 = (0o120000,0o130000,1,0,3)
    target_foreign = (0o120000,0o130000,1,0,2)
    if old_owners.count(source_pin1) != 1 or \
            old_owners.count(target_slot3) != 1:
        raise ValueError("not genuine original dual-owner failed FULL")
    expected = [source_pin0 if x==source_pin1 else
                target_foreign if x==target_slot3 else x for x in old_owners]
    if new_owners != expected or \
            old_scalar[core["mm_extent_count"]] != 18 or \
            new_scalar[core["mm_extent_count"]] != 18 or \
            new_scalar[core["vfs_namespace_root"]] != \
            old_scalar[core["vfs_namespace_root"]] or \
            new_scalar[core["proc_current_slot"]] != 0:
        raise ValueError("foreign-claimed full MM target lost/changed unexpectedly")
    block = section(trace,"V1905_STAGE_UNSAFE_CLEAR",
                    "V1905_END_UNSAFE_CLEAR")
    meta = word(block,e["process_table"]+9)
    if (meta >> 18) != e["uarea"] or \
            (meta & (1<<16)) or \
            word(block,e["process_table"]+10) & 0o777777 or \
            word(block,e["uarea"]+0o67) != 0:
        raise ValueError("original recovery did not publish observed unsafe unlock")
    if not ("MEM                                  48 K" in trace and
            "PURE                              LOADED" in trace and
            "DTFS                              LOADED" in trace):
        raise ValueError("original 48K PDP6 guest not booted")
    print("REPRO v1905: original source free -5 with genuine original owners")
    print("REPRO v1905: test-only target owner becomes foreign slot2, MM18")
    print("REPRO v1905: original KCORE/PURE clears TRANSITION while foreign")
    print("REPRO v1905: unsafe orphaned target and saved exec context remain")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-physical-v1905.py kit build physical-work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1905 original foreign ownership proof: " + str(exc))

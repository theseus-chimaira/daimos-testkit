#!/usr/bin/env python3
"""Physically complete original target cleanup free, then lose its reply."""

from pathlib import Path
import re
import runpy
import subprocess
import sys


def prepare(kit, build, probe, prior, work, dxrcheck, objdump):
    v1894 = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-real-free-refusal-v1894/prepare-v1894.py"))
    base = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    v1894["read"](kit, build, probe, prior, work, dxrcheck, objdump)
    core = base["symbols"](build / "kcore.map")
    pure = base["symbols"](build / "pure-mres-v1612.map")
    physical_base = base["read_probe"](build, probe)
    original_linked = base["source_words"](build, dxrcheck)
    obj = build / "proc_pure_full_v1611.dobj"
    listing = subprocess.check_output([str(objdump), "-t", str(obj)],
                                      encoding="ascii")
    orig = re.findall(r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,"
                      r"([0-7]{6})\s+proc_pure_ram_restore_v1391\s*$", listing)
    relocs = subprocess.check_output([str(objdump), "-r", str(obj)],
                                     encoding="ascii")
    calls = [int(s, 8) for s in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_free addend=", relocs)]
    if len(orig) != 1 or len(calls) != 2 or calls != sorted(calls):
        raise ValueError("original compiled FULL source/target free calls drifted")
    full_start = pure["proc_pure_ram_restore_v1391"]
    offset = int(orig[0], 8)
    source_call = full_start + calls[0] - offset
    target_call = full_start + calls[1] - offset
    opcode = 0o260740000000 | core["mm_free"]
    if source_call >= target_call or target_call >= source_call + 0o100 or \
            original_linked.get(source_call) != opcode or \
            original_linked.get(target_call) != opcode:
        raise ValueError("original linked target cleanup free PUSHJ differs")
    target_call += physical_base
    target_return = target_call + 1
    full, extents = audit["stage"](
        (prior / "physical.clean").read_text(encoding="ascii").replace(
            "V1845_", "V1638_"), core, "FULL_PINNED")
    target_addr = []
    for i in range(full[core["mm_extent_count"]]):
        addr = core["mm_extents"] + 2 * i
        if full[addr] == ((0o10000 << 18) | 0o120000) and \
                full[addr + 1] == ((1 << 21) | (1 << 18) | 3):
            target_addr.append(addr + 1)
    if len(target_addr) != 1 or \
            extents.count((0o120000, 0o130000, 1, 1, 3)) != 1:
        raise ValueError("original target MM descriptor not uniquely derived")
    dest_meta = target_addr[0]
    text = (work / "physical.ini").read_text(encoding="ascii")
    expected = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1894.txt").read_text(encoding="ascii")))
    anchor = ("break %06o\ncont\necho V1894_ORIGINAL_ROLLBACK_RETURN\n" %
              expected["service_return"])
    if text.count(anchor) != 1:
        raise ValueError("v1894 exact two-zero-pin target rollback entry drifted")
    prefix, _ = text.split(anchor, 1)
    if prefix.count("V1894_END_TWO_UNPINNED\n") != 1:
        raise ValueError("original v1894 must release ONLY external source pin")
    if "deposit %06o" % dest_meta in prefix:
        raise ValueError("target MM pin cannot be changed before its original free")

    def snapshot(name):
        part = base["snapshot"](core, name).replace("V1845_", "V1897_")
        return part

    tail = ("break %06o\ncont\n" % target_call +
        "echo V1897_ORIGINAL_TARGET_FREE_CALL\n" +
        "examine %06o\n" % dest_meta + snapshot("TARGET_FREE_CALL") +
        "nobreak\nbreak %06o\ncont\n" % target_return +
        "echo V1897_ORIGINAL_SUCCESSFUL_TARGET_FREE_RETURN\nexamine 1\n" +
        snapshot("TARGET_FREED") +
        "nobreak\ndeposit 1 777777777773\n" +
        "echo V1897_FORGED_FAILED_TARGET_FREE_REPLY\nexamine 1\n" +
        "echo V1897_END_FORGED_FAILED_TARGET_FREE_REPLY\n" +
        "break %06o\ncont\n" % expected["service_return"] +
        "echo V1897_ORIGINAL_FAILED_FULL_RETURN\nexamine 1\n" +
        "examine %06o\n" % core["proc_table"] +
        "examine 044723-044725\n" + snapshot("FAILED_FULL") +
        "nobreak\nexpect \"Z\"\ncont\n" +
        "echo V1897_ORIGINAL_CHILDREN_WAIT_Z\n" + snapshot("Z") +
        "cont\nexit\n")
    result = prefix + tail
    if tail.count("deposit 1 777777777773\n") != 1 or \
            "detach dtc3" in tail or "deposit %06o" % dest_meta in tail:
        raise ValueError("only AC1 may be overwritten after real target deletion")
    (work / "physical.ini").write_text(result, encoding="ascii")
    (work / "expected-v1897.txt").write_text(
        ("source_call %06o\nsource_return %06o\n"
         "target_call %06o\ntarget_return %06o\nservice_return %06o\n"
         "source_meta_address %06o\nsource_meta_pin0 %012o\n"
         "source_meta_pin1 %012o\n"
         "target_meta_address %06o\nprocess_table 044712\n") %
        (expected["source_call"], expected["source_return"],
         target_call, target_return, expected["service_return"],
         expected["source_meta_address"], expected["source_meta_pin0"],
         expected["source_meta_pin1"], dest_meta), encoding="ascii")
    print("v1897: compiled original cleanup free CALL=%06o RETURN=%06o" %
          (target_call, target_return))
    print("v1897: genuine physical target deletion first; falsify only AC1 after return")


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1897.py kit build probe v1894work work dxrcheck objdump")
    prepare(*(Path(s) for s in sys.argv[1:]))

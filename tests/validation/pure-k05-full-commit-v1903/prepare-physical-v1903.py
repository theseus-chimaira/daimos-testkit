#!/usr/bin/env python3
"""Prove real second FULL commit then release original parent typed WAIT."""

from pathlib import Path
import re
import runpy
import subprocess
import sys


def one(path, name):
    matches = re.findall(r"(?m)^%s\s+([0-7]+)$" % name,
                         path.read_text(encoding="ascii"))
    if len(matches) != 1:
        raise ValueError("source-linked physical value missing: " + name)
    return int(matches[0], 8)


def prepare(kit, build, probe, work, prefix):
    old = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-reconcile-v1902/prepare-physical-v1902.py"))
    old["prepare"](kit, build, probe, work,
                   prefix / "bin/dxrcheck",
                   prefix / "bin/pdp10-dec-none-objdump")
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    decode = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-reconcile-v1902/prepare-physical-commit-v1902.py"))
    core = base["symbols"](build / "kcore.map")
    pure = base["symbols"](build / "pure-mres-v1612.map")
    parent = base["symbols"](build.parent / "user/init.map")
    gate_offset = parent.get("v1901_term_gate", 0)
    if not 0 < gate_offset < 0o10000:
        raise ValueError("test-only USER gate is not inside parent APR")
    parent_apr = 0o130000
    image_core, core_words = decode["image"](
        prefix / "bin/dxrcheck", build / "kcore.dxr")
    image_pure, pure_words = decode["image"](
        prefix / "bin/dxrcheck", build / "pure-mres-v1612.dxr")
    if image_core < 0o24165 or image_pure != 0o4615:
        raise ValueError("required original v1902 recovery code missing")
    pure_base = one(work / "expected-v1902.txt", "pure_base")
    # The current compiler also changes the transient KINIT geometry.
    # The actual installed PURE MRES base moves 032435 -> 032453, and
    # the first independently executed physical trace proves that the
    # runtime process table and private u-area follow that placement.
    # KCORE IMAGE growth alone cannot predict their physical address.
    table = 0o45516 + pure_base - 0o32435
    uarea = 0o46635 + pure_base - 0o32435
    if not (0o45000 <= table < 0o46000 and
            table < uarea < 0o50000):
        raise ValueError("unexpected 48K process table/u-area geometry")
    # Every predicted physical pointer is checked against actual live
    # MM/process-table observations. The new compiler may grow KCORE;
    # never silently use v1902's old absolute MM addresses.
    obj = build / "proc_pure_service_v1612.dobj"
    objdump = prefix / "bin/pdp10-dec-none-objdump"
    relocs = subprocess.check_output([str(objdump), "-r", str(obj)],
                                     encoding="ascii")
    frees = [int(x,8) for x in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_free addend=",relocs)]
    syms = subprocess.check_output([str(objdump), "-t", str(obj)],
                                   encoding="ascii")
    origins = re.findall(
        r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,([0-7]{6})\s+"
        r"proc_pure_mres_service_v1612\s*$",syms)
    if len(frees) != 1 or len(origins) != 1:
        raise ValueError("source-linked original PURE target free not unique")
    native_offset = pure["proc_pure_mres_service_v1612"] + \
        frees[0] - int(origins[0],8)
    if pure_words.get(native_offset) != (0o260740000000 | core["mm_free"]):
        raise ValueError("compiled original PURE native mm_free call drifted")
    if (pure_words.get(0o635),pure_words.get(0o637),
            pure_words.get(0o640)) != (0o402004000067,
                                      0o406337777774,
                                      0o200040000012):
        raise ValueError("native slot-0 retry/TRANSITION stores changed")
    native_target_call = pure_base + native_offset
    transition_clear = pure_base + 0o640
    if not 0o20000 <= native_target_call < 0o140000:
        raise ValueError("native target-free call outside physical memory")
    source_return = one(work / "expected-v1902.txt", "source_return")
    service_return = one(work / "expected-v1902.txt", "service_return")
    script = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1902_END_PIN_RELEASE\n"
    if script.count(anchor) != 1:
        raise ValueError("original source-free -5/pin release anchor drifted")
    script = script.split(anchor,1)[0] + anchor

    def snapshot(label):
        s = base["snapshot"](core, label).replace("V1845_", "V1903_")
        tail = "echo V1903_END_%s\n" % label
        if not s.endswith(tail):
            raise ValueError("physical MM snapshot schema drift")
        return (s[:-len(tail)] +
                "examine %06o\n" % core["proc_table"] +
                "examine %06o-%06o\n" % (table, table+0o20) +
                "examine %06o\n" % core["proc_sched_cursor"] +
                "examine %06o\n" % core["proc_timer_clock"] +
                "examine %06o\n" % (uarea+0o20) +
                "examine %06o\n" % (uarea+0o24) +
                "examine %06o\n" % (uarea+0o67) +
                "examine %06o\n" % (parent_apr + gate_offset) + tail)

    # Only the initial external source MM pin is test-injected.
    # After that, both physical frees, second FULL commit and original
    # child continuations are executed by unchanged KCORE/PURE.
    script += (
        "nobreak\nbreak %06o\ncont\n" % native_target_call +
        "echo V1903_ORIGINAL_NATIVE_TARGET_FREE_CALL\n" +
        snapshot("BEFORE_TARGET_FREE") +
        "nobreak\nbreak %06o\ncont\n" % (native_target_call+1) +
        "echo V1903_ORIGINAL_NATIVE_TARGET_FREE_RETURN\nexamine 1\n" +
        snapshot("TARGET_FREED") +
        "nobreak\nbreak %06o\ncont\n" % transition_clear +
        "echo V1903_ORIGINAL_SLOT0_TRANSITION_CLEAR\n" +
        snapshot("TRANSITION_UNLOCKED") +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1903_ORIGINAL_PARENT_AFTER_RECOVERY\n" +
        snapshot("PARENT_AFTER_RECOVERY") +
        "nobreak\nbreak %06o\ncont\n" % source_return +
        "echo V1903_SECOND_NATIVE_SOURCE_FREE_RETURN\nexamine 1\n" +
        snapshot("SOURCE_FREED") +
        "nobreak\nbreak %06o\ncont\n" % service_return +
        "echo V1903_SECOND_FULL_SERVICE_RETURN\nexamine 1\n" +
        snapshot("FULL_COMMITTED") +
        "echo V1903_TEST_ONLY_PARENT_USER_GATE\n" +
        "examine %06o\n" % (parent_apr + gate_offset) +
        "deposit %06o %012o\n" %
        (parent_apr + gate_offset, 0o12345670123) +
        "echo V1903_END_PARENT_USER_GATE\n" +
        "nobreak\nexpect \"Z\"\ncont\n" +
        "echo V1903_ORIGINAL_PARENT_TYPED_WAIT_Z\n" +
        snapshot("PARENT_Z") +
        "cont\n" +
        "echo V1903_ORIGINAL_NATIVE_HALT\n" +
        snapshot("HALT") + "exit\n")
    # SIMH NOBREAK without an address does NOT clear older breakpoints:
    # it means "remove the breakpoint at the current PC". The old
    # source-free CALL would therefore stop a second FULL *before* its
    # native MM free and falsely label that stage as a return. Clear
    # ALL old E breakpoints explicitly at every new checkpoint.
    bare = script.count("nobreak\n")
    if bare < 8:
        raise ValueError("unexpected number of source-linked break stages")
    script = script.replace("nobreak\n", "nobreak all\n")
    if "nobreak\n" in script:
        raise ValueError("stale original SIMH breakpoint would survive")
    if script.count("deposit %06o %012o\n" %
                    (parent_apr+gate_offset, 0o12345670123)) != 1:
        raise ValueError("test-only parent USER gate is not uniquely written")
    (work / "physical.ini").write_text(script, encoding="ascii")
    (work / "expected-v1903.txt").write_text(
        "parent_apr %06o\nparent_gate %06o\nsource_return %06o\n"
        "service_return %06o\nnative_target_call %06o\n"
        "transition_clear %06o\nprocess_table %06o\nuarea %06o\n" %
        (parent_apr,parent_apr+gate_offset,source_return,service_return,
         native_target_call,transition_clear,table,uarea),
        encoding="ascii")
    print("v1903: source free %06o service %06o parent USER gate %06o" %
          (source_return, service_return, parent_apr+gate_offset))


if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: prepare-physical-v1903.py kit build probe work prefix")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError, ValueError, AssertionError, KeyError) as exc:
        raise SystemExit("FAIL v1903 source-linked physical: " + str(exc))

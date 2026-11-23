#!/usr/bin/env python3
"""Execute original PDP6 source-unpin -4 and checked target rollback."""

from pathlib import Path
import re
import runpy
import subprocess
import sys


def prepare(kit, build, probe, prior, work, dxrcheck, objdump):
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                        "pure-full-restore-v1638/audit-v1638.py"))
    v1894 = runpy.run_path(str(kit / "tests/validation/"
                        "pure-k05-real-free-refusal-v1894/prepare-v1894.py"))
    v1894["read"](kit, build, probe, prior, work, dxrcheck, objdump)
    core = base["symbols"](build / "kcore.map")
    pure = base["symbols"](build / "pure-mres-v1612.map")
    physical_base = base["read_probe"](build, probe)
    linked = base["source_words"](build, dxrcheck)
    object_path = build / "proc_pure_full_v1611.dobj"
    symbols = subprocess.check_output([str(objdump), "-t", str(object_path)],
                                      encoding="ascii")
    first = re.findall(r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,"
                       r"([0-7]{6})\s+proc_pure_ram_restore_v1391\s*$", symbols)
    reloc = subprocess.check_output([str(objdump), "-r", str(object_path)],
                                    encoding="ascii")
    unpins = [int(n, 8) for n in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_unpin addend=", reloc)]
    frees = [int(n, 8) for n in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_free addend=", reloc)]
    if len(first) != 1 or unpins != [0o655, 0o662, 0o746, 0o766] or \
            frees != [0o674, 0o755]:
        raise ValueError("original FULL source/target unpin/free relocations changed")
    func = pure["proc_pure_ram_restore_v1391"]
    obj_func = int(first[0], 8)
    def native(offset, symbol):
        vma = func + offset - obj_func
        if linked.get(vma) != (0o260740000000 | core[symbol]):
            raise ValueError("original source-linked native %s opcode differs" % symbol)
        return vma + physical_base
    target_unpin = native(unpins[0], "mm_unpin")
    source_unpin = native(unpins[1], "mm_unpin")
    target_free = native(frees[1], "mm_free")
    if not target_unpin < source_unpin < target_free:
        raise ValueError("original source-unpin/target-free order changed")
    prior_trace = (prior / "physical.clean").read_text(encoding="ascii")
    start, owners = audit["stage"](prior_trace.replace("V1845_", "V1638_"),
                                   core, "FULL_PINNED")
    found = []
    for i in range(start[core["mm_extent_count"]]):
        addr = core["mm_extents"] + 2 * i
        if start[addr] == ((0o6600 << 18) | 0o111200) and \
                start[addr + 1] == ((1 << 21) | (4 << 18) | 3):
            found.append(addr + 1)
    if len(found) != 1 or owners.count((0o111200, 0o120000, 4, 1, 3)) != 1 \
            or owners.count((0o120000, 0o130000, 1, 1, 3)) != 1:
        raise ValueError("original unique authoritative source MM metadata changed")
    meta = found[0]
    pin1 = start[meta]
    pin0 = pin1 - (1 << 21)
    ini = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1845_END_FULL_PINNED\nnobreak\nbreak "
    if ini.count(anchor) != 1:
        raise ValueError("original physical pinned FULL stage changed")
    prefix, _ = ini.split(anchor, 1)
    original_expected = dict((name, int(value, 8)) for name, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1894.txt").read_text(encoding="ascii")))
    if original_expected["source_meta_address"] != meta:
        raise ValueError("source descriptor does not match accepted v1894 case")

    def snapshot(label):
        s = base["snapshot"](core, label).replace("V1845_", "V1899_")
        end = "echo V1899_END_%s\n" % label
        if not s.endswith(end):
            raise ValueError("original MM snapshot terminator changed")
        return (s[:-len(end)] + "examine %06o\n" % core["proc_table"] +
                "examine 044712-044732\n" +
                "examine %06o\n" % core["proc_timer_clock"] + end)

    script = (prefix + "echo V1845_END_FULL_PINNED\n" +
        "nobreak\nbreak %06o\ncont\n" % source_unpin +
        "echo V1899_ORIGINAL_SOURCE_UNPIN_CALL\n" +
        "examine %06o\n" % meta + snapshot("SOURCE_UNPIN_CALL") +
        "nobreak\ndeposit %06o %012o\n" % (meta, pin0) +
        "echo V1899_TEST_ONLY_ZERO_SOURCE_PIN\n" +
        "examine %06o\n" % meta +
        "echo V1899_END_TEST_ONLY_ZERO_SOURCE_PIN\n" +
        "break %06o\ncont\n" % (source_unpin + 1) +
        "echo V1899_ORIGINAL_NATIVE_SOURCE_UNPIN_REFUSAL\nexamine 1\n" +
        snapshot("SOURCE_REFUSED") +
        "nobreak\nbreak %06o\ncont\n" % target_free +
        "echo V1899_ORIGINAL_TARGET_ROLLBACK_FREE_CALL\n" +
        snapshot("TARGET_FREE_CALL") +
        "nobreak\nbreak %06o\ncont\n" % (target_free + 1) +
        "echo V1899_ORIGINAL_TARGET_FREE_COMMITTED\nexamine 1\n" +
        snapshot("TARGET_FREED") +
        "nobreak\nbreak %06o\ncont\n" % original_expected["service_return"] +
        "echo V1899_ORIGINAL_FULL_FAILURE_RETURN\nexamine 1\n" +
        snapshot("FAILED_FULL") +
        "nobreak\nexpect \"Z\"\ncont\n" +
        "echo V1899_ORIGINAL_FIVE_CHILD_WAIT_Z\n" +
        snapshot("Z") +
        "cont\nexit\n")
    if script.count("deposit %06o %012o\n" % (meta, pin0)) != 1 or \
            script.count("deposit %06o %012o\n" % (meta, pin1)) or \
            "detach dtc3" in script:
        raise ValueError("source unpin failure must use only ONE source MM deposit")
    (work / "physical.ini").write_text(script, encoding="ascii")
    (work / "expected-v1899.txt").write_text(
        ("target_unpin %06o\nsource_unpin %06o\nsource_return %06o\n"
         "target_free %06o\ntarget_return %06o\nservice_return %06o\n"
         "source_meta_address %06o\nsource_pin1 %012o\n"
         "source_pin0 %012o\nprocess_table 044712\n") %
        (target_unpin, source_unpin, source_unpin + 1,
         target_free, target_free + 1, original_expected["service_return"],
         meta, pin1, pin0), encoding="ascii")
    print("v1899: original target unpin=%06o, source unpin=%06o return=%06o" %
          (target_unpin, source_unpin, source_unpin + 1))
    print("v1899: actual original rollback target free=%06o return=%06o" %
          (target_free, target_free + 1))
    print("v1899: sole test-only MM metadata deposit %06o: %012o -> %012o" %
          (meta, pin1, pin0))


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1899.py kit build probe prior work dxrcheck objdump")
    prepare(*(Path(s) for s in sys.argv[1:]))

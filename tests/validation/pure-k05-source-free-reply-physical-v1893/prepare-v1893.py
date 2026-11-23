#!/usr/bin/env python3
"""Test-only original physical lost-successful-PACKED-free return injection."""

from pathlib import Path
import hashlib
import re
import runpy
import subprocess
import sys


def owner_free_return(kit, build, base, dxrcheck, objdump):
    m = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = m["symbols"](build / "kcore.map")
    pure = m["symbols"](build / "pure-mres-v1612.map")
    words = m["source_words"](build, dxrcheck)
    obj = build / "proc_pure_full_v1611.dobj"
    symbols = subprocess.check_output([str(objdump), "-t", str(obj)],
                                      encoding="ascii")
    found = re.findall(r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,"
                       r"([0-7]{6})\s+proc_pure_ram_restore_v1391\s*$", symbols)
    if len(found) != 1:
        raise ValueError("missing exact compiled FULL DOJB symbol offset")
    start = int(found[0], 8)
    reloc = subprocess.check_output([str(objdump), "-r", str(obj)],
                                    encoding="ascii")
    mm_free = [int(x, 8) for x in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_free addend=", reloc)]
    if len(mm_free) != 2 or mm_free != sorted(mm_free) or mm_free[0] <= start:
        raise ValueError("original FULL source/rollback mm_free calls changed")
    # The first original source-linked call is mm_free(PACKED); the
    # later call belongs to the error cleanup mm_free(PROCESS).
    call = pure["proc_pure_ram_restore_v1391"] + mm_free[0] - start
    ret = call + 1
    if words.get(call) != (0o260740000000 | core["mm_free"]):
        raise ValueError("source call is not original PUSHJ 17,mm_free")
    if words.get(ret) != 0o200400000001:
        raise ValueError("original PACKED-free reply consumer changed")
    if not 0o20000 < base + ret < 0o140000:
        raise ValueError("physical source free return outside 48K core")
    print("v1893: exact original source-free PUSHJ=%06o, return=%06o"
          % (base + call, base + ret))
    return base + ret


def prepare(kit, build, probe, work, dxrcheck, objdump):
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b":
        raise ValueError("v1893 fixed KCORE differs from accepted v1855")
    if hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("v1893 opt-in PURE MRES differs from accepted v1855")
    m = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = m["symbols"](build / "kcore.map")
    base = m["read_probe"](build, probe)
    source_return = owner_free_return(kit, build, base, dxrcheck, objdump)
    m["physical"](build, work, base, dxrcheck)
    script = (work / "physical.ini").read_text(encoding="ascii")
    begin = "echo V1845_END_FULL_PINNED\nnobreak\ndetach dtc3\n"
    end = "exit\n"
    if script.count(begin) != 1:
        raise ValueError("original pinned FULL/source loss injector drifted")
    prefix, _ = script.split(begin, 1)
    exp = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1845.txt").read_text(encoding="ascii")))
    # Disambiguate the original physical PACKED source deletion from
    # any later cleanup or another process's mm_free. Its return is
    # observed BEFORE AC1 is changed, so the oracle must prove a
    # genuine successful deletion and exact sole complete successor.
    rest = ("echo V1845_END_FULL_PINNED\n" +
            "nobreak\nbreak %06o\ncont\n" % source_return +
            "echo V1893_REAL_SOURCE_FREE_RETURN\nexamine 1\n" +
            m["snapshot"](core, "SOURCE_FREED").replace("V1845_", "V1893_") +
            "nobreak\n" +
            "deposit 1 777777777773\n" +
            "echo V1893_FORGED_FAILED_REPLY\nexamine 1\n" +
            "echo V1893_END_FORGED_REPLY\n" +
            "break %06o\ncont\n" % exp["service_return"] +
            "echo V1893_ORIGINAL_RECOVERED_FULL_RETURN\nexamine 1\n" +
            "examine %06o\n" % core["proc_table"] +
            "examine 044723-044725\n" +
            m["snapshot"](core, "RESTORED").replace("V1845_", "V1893_") +
            "nobreak\n" +
            'expect "Z"\ncont\n' +
            "echo V1893_NORMAL_CHILDREN_WAIT_Z\n" +
            m["snapshot"](core, "Z").replace("V1845_", "V1893_") +
            "cont\n" + end)
    if rest.count("deposit 1 777777777773\n") != 1 or \
            "detach dtc3\n" in rest:
        raise ValueError("physical fail-reply inject is not AC1 only")
    (work / "physical.ini").write_text(prefix + rest, encoding="ascii")
    (work / "expected-v1893.txt").write_text(
        ("mm_free_return %06o\nservice_return %06o\n"
         "physical_owner_slot 000003\n"
         "original_source_start 111200\noriginal_source_end 120000\n"
         "original_target_start 120000\noriginal_target_end 130000\n"
         "original_proc_table 044712\n") %
        (source_return, exp["service_return"]), encoding="ascii")
    print("v1893: original FULL must reconcile lost successful source-free return")
    print("v1893: original five-child WAIT/HALT must complete with DTC3 intact")


if __name__ == "__main__":
    if len(sys.argv) != 7:
        raise SystemExit("usage: prepare-v1893.py kit build probe work dxrcheck objdump")
    prepare(*(Path(a) for a in sys.argv[1:]))

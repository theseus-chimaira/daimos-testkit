#!/usr/bin/env python3
"""Inject a temporary REAL MM source pin to force native PDP6 free -5."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def read(kit, build, probe, prior, work, dxrcheck, objdump):
    prev = runpy.run_path(str(kit / "tests/validation/"
                "pure-k05-source-free-reply-physical-v1893/prepare-v1893.py"))
    base_mod = runpy.run_path(str(kit / "tests/validation/"
                "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    stage_mod = runpy.run_path(str(kit / "tests/diagnostics/"
                "pure-full-restore-v1638/audit-v1638.py"))
    core = base_mod["symbols"](build / "kcore.map")
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("v1894 must use original v1855 production binaries")
    previous_trace = (prior / "physical.clean").read_text(encoding="ascii")
    pinned, extents = stage_mod["stage"](
        previous_trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    expected_src = (0o111200, 0o120000, 4, 1, 3)
    expected_dst = (0o120000, 0o130000, 1, 1, 3)
    if extents.count(expected_src) != 1 or extents.count(expected_dst) != 1:
        raise ValueError("previous original physical pinned pair changed")
    source_meta = []
    for i in range(pinned[core["mm_extent_count"]]):
        address = core["mm_extents"] + 2 * i
        span = pinned[address]
        meta = pinned[address + 1]
        if span == (0o6600 << 18 | 0o111200) and \
                meta == ((1 << 21) | (4 << 18) | 3):
            source_meta.append(address + 1)
    if len(source_meta) != 1:
        raise ValueError("physical source descriptor not uniquely pinned")
    address = source_meta[0]
    pin1 = pinned[address]
    pin0 = pin1 - (1 << 21)
    base = base_mod["read_probe"](build, probe)
    source_return = prev["owner_free_return"](
        kit, build, base, dxrcheck, objdump)
    source_call = source_return - 1
    base_mod["physical"](build, work, base, dxrcheck)
    text = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1845_END_FULL_PINNED\nnobreak\ndetach dtc3\n"
    if text.count(anchor) != 1:
        raise ValueError("original source-linked pinned FULL anchor changed")
    prefix, _ = text.split(anchor, 1)
    expected = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1845.txt").read_text(encoding="ascii")))
    snapshot = lambda name: base_mod["snapshot"](core, name).replace(
        "V1845_", "V1894_")
    result = ("echo V1845_END_FULL_PINNED\n" +
        "nobreak\nbreak %06o\ncont\n" % source_call +
        "echo V1894_ORIGINAL_SOURCE_FREE_CALL\n" +
        "examine %06o\n" % address + snapshot("BEFORE_PIN") +
        # The genuine original C commits both successful unpins before
        # this call; the test introduces ONE other owner pin, so the
        # original fixed KCORE mm_free MUST refuse with MM_ERR_BUSY.
        "nobreak\ndeposit %06o %012o\n" % (address, pin1) +
        "echo V1894_TEMPORARY_REAL_PIN\nexamine %06o\n" % address +
        "echo V1894_END_TEMPORARY_REAL_PIN\n" +
        "break %06o\ncont\n" % source_return +
        "echo V1894_ACTUAL_MM_FREE_REFUSAL\nexamine 1\n" +
        snapshot("REFUSED") +
        "nobreak\ndeposit %06o %012o\n" % (address, pin0) +
        "echo V1894_EXTERNAL_PIN_RELEASE\nexamine %06o\n" % address +
        snapshot("TWO_UNPINNED") +
        "break %06o\ncont\n" % expected["service_return"] +
        "echo V1894_ORIGINAL_ROLLBACK_RETURN\nexamine 1\n" +
        "examine %06o\n" % core["proc_table"] +
        "examine 044723-044725\n" + snapshot("ROLLED_BACK") +
        "nobreak\nexpect \"Z\"\ncont\n" +
        "echo V1894_RECOVERED_CHILDREN_WAIT_Z\n" +
        snapshot("Z") + "cont\nexit\n")
    if result.count("deposit %06o %012o" % (address, pin1)) != 1 or \
            result.count("deposit %06o %012o" % (address, pin0)) != 1 or \
            "detach dtc3" in result:
        raise ValueError("v1894 must temporarily pin then release only source")
    (work / "physical.ini").write_text(prefix + result, encoding="ascii")
    (work / "expected-v1894.txt").write_text(
        ("source_call %06o\nsource_return %06o\nservice_return %06o\n"
         "source_meta_address %06o\nsource_meta_pin0 %012o\n"
         "source_meta_pin1 %012o\nsource_base 111200\ntarget_base 120000\n"
         "process_slot 000003\nprocess_table 044712\n") %
        (source_call, source_return, expected["service_return"], address,
         pin0, pin1), encoding="ascii")
    print("v1894: original physical source MM meta %06o pin0=%012o pin1=%012o"
          % (address, pin0, pin1))
    print("v1894: original actual mm_free call %06o return %06o service %06o"
          % (source_call, source_return, expected["service_return"]))


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1894.py kit build probe prior-v1893 work dxrcheck objdump")
    read(*(Path(x) for x in sys.argv[1:]))

#!/usr/bin/env python3
"""Real PDP6 original MM target cleanup free refusal, live resident parent."""

from pathlib import Path
import re
import runpy
import subprocess
import sys


def prepare(kit, build, probe, prior, work, dxrcheck, objdump):
    # Reuse v1894's exact original source-free call and physical
    # two-unpinned-owner setup; that result must reach fail_target.
    v1894 = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-real-free-refusal-v1894/prepare-v1894.py"))
    base = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    for marker in ("(void)p14_char('H');", "(void)p14_char('B');",
                   "#define P14_CHILDREN         5U"):
        if guest.count(marker) != 1:
            raise ValueError("v1896 requires accepted v1892 resident-parent guest")
    if guest.index("(void)p14_char('L');") >= guest.index(
            "(void)p14_char('H');"):
        raise ValueError("v1896 parent HB must follow original child pressure")
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
        raise ValueError("original compiled FULL two mm_free calls changed")
    target_call = (pure["proc_pure_ram_restore_v1391"] +
                   calls[1] - int(orig[0], 8))
    original_call = pure["proc_pure_ram_restore_v1391"] + calls[0] - int(orig[0], 8)
    if original_linked.get(target_call) != 0o260740000000 | core["mm_free"]:
        raise ValueError("original FULL cleanup call is not PUSHJ 17,mm_free")
    if target_call <= original_call or target_call >= original_call + 0o100:
        raise ValueError("source/target original native mm_free are not distinct")
    target_call += physical_base
    target_return = target_call + 1

    trace = (prior / "physical.clean").read_text(encoding="ascii")
    full, ext = audit["stage"](trace.replace("V1845_", "V1638_"),
                               core, "FULL_PINNED")
    target_addr = []
    for i in range(full[core["mm_extent_count"]]):
        addr = core["mm_extents"] + 2 * i
        if full[addr] == ((0o10000 << 18) | 0o120000) and \
                full[addr + 1] == ((1 << 21) | (1 << 18) | 3):
            target_addr.append(addr + 1)
    if len(target_addr) != 1 or ext.count((0o120000, 0o130000, 1, 1, 3)) != 1:
        raise ValueError("original target MM owner/metadata not unique")
    dest = target_addr[0]
    pin1 = full[dest]
    pin0 = pin1 - (1 << 21)

    expected = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1894.txt").read_text(encoding="ascii")))
    old = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "break %06o\ncont\necho V1894_ORIGINAL_ROLLBACK_RETURN\n" % expected["service_return"]
    if old.count(anchor) != 1:
        raise ValueError("v1894 physical exact-two-zero-pin branch changed")
    prefix, _ = old.split(anchor, 1)
    if prefix.count("deposit %06o %012o" % (dest, pin1)) or \
            prefix.count("V1894_END_TWO_UNPINNED\n") != 1:
        raise ValueError("v1896 must start at original exact two-unpinned owners")

    def snapshot(name):
        original = base["snapshot"](core, name).replace("V1845_", "V1896_")
        end = "echo V1896_END_%s\n" % name
        if not original.endswith(end):
            raise ValueError("original physical snapshot schema changed")
        return (original[:-len(end)] +
                "examine %06o\n" % core["proc_table"] +
                "examine 044712-044732\n" +
                "examine %06o\n" % core["proc_timer_clock"] + end)

    script = (prefix +
        "break %06o\ncont\n" % target_call +
        "echo V1896_ORIGINAL_TARGET_FREE_CALL\n" +
        "examine %06o\n" % dest + snapshot("TARGET_FREE_CALL") +
        "nobreak\ndeposit %06o %012o\n" % (dest, pin1) +
        "echo V1896_EXTERNAL_TARGET_PIN_PERSISTENT\n" +
        "examine %06o\n" % dest +
        "echo V1896_END_TARGET_PIN_PERSISTENT\n" +
        "break %06o\ncont\n" % target_return +
        "echo V1896_ACTUAL_NATIVE_TARGET_FREE_REFUSAL\nexamine 1\n" +
        snapshot("TARGET_REFUSED") +
        "nobreak\nbreak %06o\ncont\n" % expected["service_return"] +
        "echo V1896_ORIGINAL_FULL_FAILED_CLEANUP_RETURN\nexamine 1\n" +
        snapshot("QUARANTINED") +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1896_ACTUAL_RESIDENT_HEARTBEAT_1\n" +
        snapshot("HEARTBEAT_1") +
        "expect \"HB\"\ncont\n" +
        "echo V1896_ACTUAL_RESIDENT_HEARTBEAT_2\n" +
        snapshot("HEARTBEAT_2") +
        "exit\n")
    if script.count("deposit %06o %012o" % (dest, pin1)) != 1 or \
            script.count("deposit %06o %012o" % (dest, pin0)) or \
            script.count('expect "HB"\ncont\n') != 2 or \
            "detach dtc3" in script:
        raise ValueError("persistent physical target pin controller invalid")
    (work / "physical.ini").write_text(script, encoding="ascii")
    (work / "expected-v1896.txt").write_text(
        ("source_call %06o\nsource_return %06o\n"
         "target_call %06o\ntarget_return %06o\nservice_return %06o\n"
         "source_meta_address %06o\nsource_meta_pin0 %012o\n"
         "source_meta_pin1 %012o\n"
         "target_meta_address %06o\ntarget_meta_pin0 %012o\n"
         "target_meta_pin1 %012o\nprocess_table 044712\n") %
        (expected["source_call"], expected["source_return"],
         target_call, target_return, expected["service_return"],
         expected["source_meta_address"], expected["source_meta_pin0"],
         expected["source_meta_pin1"], dest, pin0, pin1), encoding="ascii")
    print("v1896: original source free call=%06o, rollback target free call=%06o, return=%06o" %
          (expected["source_call"], target_call, target_return))
    print("v1896: original PROCESS target descriptor %06o pin0=%012o, forced pin1=%012o" %
          (dest, pin0, pin1))


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1896.py kit build probe v1894work work dxrcheck objdump")
    prepare(*(Path(s) for s in sys.argv[1:]))

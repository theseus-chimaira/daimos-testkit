#!/usr/bin/env python3
"""Real PDP6 PACKED-free -5, persistent source pin, live parent heartbeats."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def prepare(kit, build, probe, prior, out, dxrcheck, objdump):
    source = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if source.count("(void)p14_char('H');") != 1 or \
            source.count("(void)p14_char('B');") != 1 or \
            source.count("#define P14_CHILDREN         5U") != 1 or \
            source.index("(void)p14_char('L');") >= source.index(
                "(void)p14_char('H');") or \
            source.index("if (argc > 1)") >= source.index(
                "(void)p14_char('H');"):
        raise ValueError("v1895 requires v1892 parent-only resident HB guest")
    previous = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-real-free-refusal-v1894/prepare-v1894.py"))
    previous["read"](kit, build, probe, prior, out, dxrcheck, objdump)
    module = runpy.run_path(str(kit / "tests/validation/"
                   "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = module["symbols"](build / "kcore.map")
    original = (out / "physical.ini").read_text(encoding="ascii")
    expected = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (out / "expected-v1894.txt").read_text(encoding="ascii")))
    address = expected["source_meta_address"]
    pin0 = expected["source_meta_pin0"]
    anchor = "nobreak\ndeposit %06o %012o\n" % (address, pin0)
    if original.count(anchor) != 1:
        raise ValueError("v1894 temporary external release not uniquely located")
    prefix, suffix = original.split(anchor, 1)
    if prefix.count("V1894_ACTUAL_MM_FREE_REFUSAL\n") != 1 or \
            prefix.count("V1894_END_REFUSED\n") != 1 or \
            suffix.count("V1894_ORIGINAL_ROLLBACK_RETURN\n") != 1:
        raise ValueError("original true -5 source call/return was not retained")

    def snapshot(name):
        part = module["snapshot"](core, name).replace("V1845_", "V1895_")
        terminal = "echo V1895_END_%s\n" % name
        if not part.endswith(terminal):
            raise ValueError("original physical MM stage terminator changed")
        # In the old original physical v1892 this exact real
        # KCORE proc_table pointer was read as 044712 octal. Require
        # original current pointer at each live observation too.
        return (part[:-len(terminal)] +
                "examine %06o\n" % core["proc_table"] +
                "examine %06o-%06o\n" % (0o44712, 0o44712 + 20) +
                "examine %06o\n" % core["proc_timer_clock"] +
                terminal)

    # Deliberately never remove the extra source pin. The original
    # v1839 source-free reply scan must reject the nonzero pin set
    # without rolling back the provisional target or publishing it.
    script = (prefix +
        "echo V1895_PERSISTENT_EXTERNAL_SOURCE_PIN\n" +
        "examine %06o\n" % address +
        "echo V1895_END_PERSISTENT_PIN\n" +
        "nobreak\nbreak %06o\ncont\n" % expected["service_return"] +
        "echo V1895_ORIGINAL_QUARANTINED_FULL_RETURN\nexamine 1\n" +
        snapshot("QUARANTINED") +
        "nobreak\n" +
        'expect "HB"\ncont\n' +
        "echo V1895_ACTUAL_RESIDENT_HEARTBEAT_1\n" +
        snapshot("HEARTBEAT_1") +
        'expect "HB"\ncont\n' +
        "echo V1895_ACTUAL_RESIDENT_HEARTBEAT_2\n" +
        snapshot("HEARTBEAT_2") +
        "exit\n")
    if script.count("deposit %06o %012o" %
                    (address, expected["source_meta_pin1"])) != 1 or \
            "deposit %06o %012o" % (address, pin0) in script or \
            script.count('expect "HB"\ncont\n') != 2 or \
            "detach dtc3" in script:
        raise ValueError("v1895 controller cannot release external source pin")
    (out / "physical.ini").write_text(script, encoding="ascii")
    (out / "expected-v1895.txt").write_text(
        ("source_call %06o\nsource_return %06o\nservice_return %06o\n"
         "source_meta_address %06o\nsource_meta_pin0 %012o\n"
         "source_meta_pin1 %012o\nprocess_table 044712\n"
         "source_start 111200\nsource_end 120000\n"
         "target_start 120000\ntarget_end 130000\n") %
        (expected["source_call"], expected["source_return"],
         expected["service_return"], address, pin0,
         expected["source_meta_pin1"]), encoding="ascii")
    print("v1895: original real source-free -5, MM source pin1 PERMANENTLY held")
    print("v1895: original slot3 full service -5 then two genuine parent user HBs")


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1895.py kit build probe v1894work work dxrcheck objdump")
    prepare(*(Path(a) for a in sys.argv[1:]))

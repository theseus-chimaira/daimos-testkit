#!/usr/bin/env python3
"""Source-linked 48K original FULL persistent source pin on v1900 MRES."""

from pathlib import Path
import hashlib
import re
import runpy
import subprocess
import sys


KCORE_SHA = "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b"
PURE_SHA = "09bcb71e4cbb172222f6389153c27293353fdaf6d3210eeef4630ed06de934f2"


def prepare(kit, build, probe, accepted, work, dxrcheck, objdump):
    base = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    free = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-source-free-reply-physical-v1893/prepare-v1893.py"))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != KCORE_SHA or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != PURE_SHA:
        raise ValueError("v1900 must use exact newly rebuilt source-matched 48K PURE")
    # The source-built image has a test-only /SYSTEM/COMP installed
    # AFTER the main image link. A subsequent make image can silently
    # regenerate base TSFS root tapes without that compressed child.
    # Detect that test-image error BEFORE running any physical trace.
    manifest = (build.parent / "tsfs-root-v1638.manifest").read_text(
        encoding="ascii")
    if manifest.count("F /SYSTEM/COMP ") != 1:
        raise ValueError("missing source-matched compressed test-file manifest")
    for unit in range(3):
        selected = build / "media" / ("dtc%d.tap" % unit)
        expected = build.parent / ("tsfs-v1638%d.dta" % unit)
        if selected.read_bytes() != expected.read_bytes():
            raise ValueError("TSFS compressed test media replaced after MRES relink")
    terminal = (build / "pure-terminal-v1666.s").read_text(encoding="ascii")
    for key in ("ppure_detach_target_v1900:",
                "camle   4,mm_extent_capacity", "ppure_detach_postfree_scan_v1900:"):
        if terminal.count(key) != 1:
            raise ValueError("v1900 terminal release source is not actually rebuilt")
    previous = (accepted / "physical.clean").read_text(encoding="ascii")
    core = base["symbols"](build / "kcore.map")
    pinned, owners = mm["stage"](previous.replace("V1845_", "V1638_"),
                                 core, "FULL_PINNED")
    if owners.count((0o111200, 0o120000, 4, 1, 3)) != 1 or \
            owners.count((0o120000, 0o130000, 1, 1, 3)) != 1 or \
            pinned[core["mm_extent_count"]] != 18:
        raise ValueError("accepted pinned native geometry changed")
    found = []
    for i in range(pinned[core["mm_extent_count"]]):
        address = core["mm_extents"] + 2 * i
        if pinned[address] == ((0o6600 << 18) | 0o111200) and \
                pinned[address + 1] == ((1 << 21) | (4 << 18) | 3):
            found.append(address + 1)
    if len(found) != 1:
        raise ValueError("original unique pinned source descriptor moved")
    addr = found[0]
    pin1 = pinned[addr]
    pin0 = pin1 - (1 << 21)
    pure_base = base["read_probe"](build, probe)
    source_return = free["owner_free_return"](kit, build, pure_base,
                                             dxrcheck, objdump)
    source_call = source_return - 1
    base["physical"](build, work, pure_base, dxrcheck)
    ini = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1845_END_FULL_PINNED\nnobreak\ndetach dtc3\n"
    if ini.count(anchor) != 1:
        raise ValueError("original source-linked FULL pinned stage moved")
    prefix, _ = ini.split(anchor, 1)
    previous_expected = dict((name, int(value, 8)) for name, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1845.txt").read_text(encoding="ascii")))
    # Source-built PURE grew. KINIT places the runtime proc_table
    # immediately after installed modules; v1895's 044712 is NOT an
    # acceptable hard-coded pointer for this exact new PURE image.
    # Derive the expected new pointer from the accepted older physical
    # proc_table and the actual DXR installed IMAGE-word increase.
    old_block = previous.split("V1895_STAGE_HEARTBEAT_1\n", 1)[1].split(
        "V1895_END_HEARTBEAT_1\n", 1)[0]
    old_values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % core["proc_table"],
                            old_block)
    dump = subprocess.check_output([str(dxrcheck), "-d",
                                    str(build / "pure-mres-v1612.dxr")],
                                   encoding="ascii")
    new_values = re.findall(r"(?m)^DXR magic=DXR entry=[0-7]+ image=([0-7]+)", dump)
    if len(old_values) != 1 or len(new_values) != 1 or \
            int(new_values[0], 8) != 0o4131:
        raise ValueError("v1900 installed PURE image/proc_table proof changed")
    original_table = int(old_values[0], 8)
    expected_table = original_table + (int(new_values[0], 8) - 0o4027)
    if original_table != 0o44712 or expected_table != 0o45014:
        raise ValueError("physical process table did not follow exact PURE growth")

    def snapshot(version, label):
        s = base["snapshot"](core, label).replace("V1845_", version)
        if version == "V1895_":
            end = "echo V1895_END_%s\n" % label
            if not s.endswith(end):
                raise ValueError("original MM snapshot schema changed")
            s = (s[:-len(end)] +
                 "examine %06o\n" % core["proc_table"] +
                 "examine %06o-%06o\n" % (expected_table,
                                               expected_table + 0o20) +
                 "examine %06o\n" % core["proc_timer_clock"] + end)
        return s

    ini = (prefix + "echo V1845_END_FULL_PINNED\n" +
        "nobreak\nbreak %06o\ncont\n" % source_call +
        "echo V1894_ORIGINAL_SOURCE_FREE_CALL\n" +
        "examine %06o\n" % addr + snapshot("V1894_", "BEFORE_PIN") +
        "nobreak\ndeposit %06o %012o\n" % (addr, pin1) +
        "echo V1894_TEMPORARY_REAL_PIN\n" +
        "examine %06o\n" % addr + "echo V1894_END_TEMPORARY_REAL_PIN\n" +
        "break %06o\ncont\n" % source_return +
        "echo V1894_ACTUAL_MM_FREE_REFUSAL\nexamine 1\n" +
        snapshot("V1894_", "REFUSED") +
        "echo V1895_PERSISTENT_EXTERNAL_SOURCE_PIN\n" +
        "examine %06o\n" % addr +
        "echo V1895_END_PERSISTENT_PIN\n" +
        "nobreak\nbreak %06o\ncont\n" % previous_expected["service_return"] +
        "echo V1895_ORIGINAL_QUARANTINED_FULL_RETURN\nexamine 1\n" +
        snapshot("V1895_", "QUARANTINED") +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1895_ACTUAL_RESIDENT_HEARTBEAT_1\n" +
        snapshot("V1895_", "HEARTBEAT_1") +
        "expect \"HB\"\ncont\n" +
        "echo V1895_ACTUAL_RESIDENT_HEARTBEAT_2\n" +
        snapshot("V1895_", "HEARTBEAT_2") +
        "exit\n")
    if ini.count("deposit %06o %012o" % (addr, pin1)) != 1 or \
            "deposit %06o %012o" % (addr, pin0) in ini or \
            ini.count('expect "HB"\ncont\n') != 2 or \
            "detach dtc3" in ini:
        raise ValueError("v1900 must never unpin source or detach backing")
    (work / "physical.ini").write_text(ini, encoding="ascii")
    (work / "expected-v1895.txt").write_text(
        ("source_call %06o\nsource_return %06o\nservice_return %06o\n"
         "source_meta_address %06o\nsource_meta_pin0 %012o\n"
         "source_meta_pin1 %012o\nprocess_table %06o\n"
         "source_start 111200\nsource_end 120000\n"
         "target_start 120000\ntarget_end 130000\n") %
        (source_call, source_return, previous_expected["service_return"],
         addr, pin0, pin1, expected_table), encoding="ascii")
    print("v1900: original fixed-KCORE genuine MM source-free -5 with new PURE")
    print("v1900: source-linked free call=%06o return=%06o service=%06o" %
          (source_call, source_return, previous_expected["service_return"]))
    print("v1900: installed PURE image %06o vs old 004027; proc_table %06o -> %06o" %
          (int(new_values[0], 8), original_table, expected_table))


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-physical-v1900.py kit build probe originalv1895 work dxrcheck objdump")
    try:
        prepare(*(Path(p) for p in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1900 physical source-linked controller: " + str(exc))

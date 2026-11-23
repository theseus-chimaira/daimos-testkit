#!/usr/bin/env python3
"""Source-linked real PDP-6 physical pin2 and held FULL owner audit."""

from pathlib import Path
import re
import runpy
import sys


def address_word(section, addr):
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, section)
    if len(found) != 1:
        raise ValueError("physical word %06o not unique" % addr)
    return int(found[0], 8)


def section(trace, first, last):
    begin = "V1890_%s\n" % first
    end = "V1890_%s\n" % last
    if trace.count(begin) != 1 or trace.count(end) != 1:
        raise ValueError("physical trace missing stage " + first)
    return trace.split(begin, 1)[1].split(end, 1)[0]


def read(kit, build, work):
    previous = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    stage = previous["stage"]
    core = previous["symbols"]((build / "kcore.map").read_text(
        encoding="ascii"))
    expected = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1890.txt").read_text(encoding="ascii")))
    earlier = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1845.txt").read_text(encoding="ascii")))
    transcript = (work / "physical.clean").read_text(encoding="ascii")
    stages = ("V1845_END_B\n", "V1845_END_A\n",
              "V1845_BOUNDED_FULL_SECONDARY\n",
              "V1845_END_FULL_PINNED\n",
              "V1890_PHYSICAL_PREINJECT\n",
              "V1890_END_PREINJECT\n",
              "V1890_PHYSICAL_SECOND_PIN\n",
              "V1890_END_SECOND_PIN\n",
              "V1890_ORIGINAL_FULL_RETURN\n",
              "V1890_STAGE_QUARANTINED\n",
              "V1890_END_QUARANTINED\n",
              "V1890_REAL_CLOCK_AFTER_FAILURE\n",
              "V1890_STAGE_CLOCK_LATER\n",
              "V1890_END_CLOCK_LATER\n")
    if any(transcript.count(x) != 1 for x in stages) or \
            [transcript.index(x) for x in stages] != sorted(
                transcript.index(x) for x in stages):
        raise ValueError("physical FULL/pin2/return/clock markers missing or out of order")
    if "MEM                                  48 K" not in transcript or \
            "PURE                              LOADED" not in transcript or \
            "DTFS                              LOADED" not in transcript or \
            "aaaaax[B" not in transcript or "[A" not in transcript:
        raise ValueError("not the original five-child 48K PURE pressure")
    if "V1845_DTC3_DETACHED" in transcript or \
            "DTC3    147KW, not attached" in transcript:
        raise ValueError("a physical source detach invalidated pin-only fault")
    if not re.search(r"Breakpoint, PC: %06o " % earlier["loader"],
                     transcript):
        raise ValueError("source-linked original FULL loader not entered")
    if not re.search(r"Breakpoint, PC: %06o " % earlier["service_return"],
                     transcript) or expected["return_pc"] != earlier["service_return"]:
        raise ValueError("source-linked original FULL return not entered")
    if not re.search(r"Breakpoint, PC: %06o " % expected["pi6_pc"],
                     transcript):
        raise ValueError("real original hardware PI6 handler not reached")
    entry, entry_ext = stage(transcript.replace("V1845_", "V1638_"),
                             core, "FULL_PINNED")
    quarantined, held = stage(transcript.replace("V1890_", "V1638_"),
                               core, "QUARANTINED")
    later, after = stage(transcript.replace("V1890_", "V1638_"),
                         core, "CLOCK_LATER")
    target = (0o120000, 0o130000, 1, 1, 3)
    source = (0o111200, 0o120000, 4, 1, 3)
    if entry_ext.count(target) != 1 or entry_ext.count(source) != 1 or \
            entry[core["proc_current_slot"]] != 0:
        raise ValueError("actual original FULL has no pinned exact slot3 pair")
    meta = expected["target_meta_address"]
    before = section(transcript, "PHYSICAL_PREINJECT", "END_PREINJECT")
    injected = section(transcript, "PHYSICAL_SECOND_PIN", "END_SECOND_PIN")
    if address_word(before, meta) != expected["old_meta"]:
        raise ValueError("predeposit physical target is not exact pin1")
    if address_word(injected, meta) != expected["new_meta"] or \
            expected["new_meta"] - expected["old_meta"] != 1 << 21:
        raise ValueError("physical simulator did not inject exactly one target pin")
    response = section(transcript, "ORIGINAL_FULL_RETURN", "STAGE_QUARANTINED")
    if not re.search(r"(?m)^1:\s*777777777773\s*$", response):
        raise ValueError("original FULL failed to return MM_ERR_BUSY (-5)")
    desired = [
        (x, y, kind, 2 if x == 0o120000 and kind == 1 and slot == 3 else pin, slot)
        for x, y, kind, pin, slot in entry_ext]
    if held != desired or \
            quarantined[core["mm_extent_count"]] != entry[core["mm_extent_count"]]:
        raise ValueError("physical overpin did not retain exact FULL MM owners")
    if quarantined[core["proc_current_slot"]] != 0 or \
            quarantined[core["vfs_namespace_root"]] != \
            entry[core["vfs_namespace_root"]]:
        raise ValueError("physical held restore changed slot0 or TSFS root")
    if after != desired or \
            later[core["vfs_namespace_root"]] != entry[core["vfs_namespace_root"]]:
        raise ValueError("actual postfailure PI6 lost held MM owner or root")
    original_clock = section(transcript, "REAL_CLOCK_AFTER_FAILURE",
                             "STAGE_CLOCK_LATER")
    if address_word(original_clock, core["proc_timer_clock"]) < 1:
        raise ValueError("postfailure PI6 has no actual clock tick")
    if "HALT instruction" in transcript:
        raise ValueError("quarantine physical monitor run unexpectedly HALTed")
    print("PASS v1890: original 48K physical FULL returned -5 after target pin2")
    print("v1890: original PACKED pin1 and PROCESS pin2 both retained")
    print("v1890: independent PCLK PI6 preserved MM/root after quarantine")
    print("NOT PROVEN: independent user process WAIT/EXIT or whole-machine HALT")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1890.py testkit build evidence")
    try:
        read(*(Path(a) for a in sys.argv[1:]))
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        raise SystemExit("FAIL v1890 original physical FULL overpin: " + str(exc))

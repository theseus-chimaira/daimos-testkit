#!/usr/bin/env python3
"""Reject four independent forged original physical MM/clock witnesses."""

from pathlib import Path
import re
import subprocess
import sys


def replace_one(text, first, last, address, old, new):
    start = "V1890_%s\n" % first
    end = "V1890_%s\n" % last
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError("missing physical mutation boundary")
    left, rest = text.split(start, 1)
    body, right = rest.split(end, 1)
    needle = "%o:\t%012o" % (address, old)
    substitute = "%o:\t%012o" % (address, new)
    if body.count(needle) != 1:
        raise ValueError("negative source physical MM word is not unique")
    return left + start + body.replace(needle, substitute, 1) + end + right


def run(kit, build, work):
    trace = work / "physical.clean"
    original = trace.read_text(encoding="ascii")
    values = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1890.txt").read_text(encoding="ascii")))
    core = {}
    for line in (build / "kcore.map").read_text(encoding="ascii").splitlines():
        parts = line.split()
        if len(parts) == 2 and re.fullmatch("[0-7]+", parts[1]):
            core[parts[0]] = int(parts[1], 8)
    addr = values["target_meta_address"]
    pin1 = values["old_meta"]
    pin2 = values["new_meta"]
    # The physically observed two slot3 descriptors are adjacent
    # sorted extents in this source-matched fixed KCORE layout.
    if addr < core["mm_extents"] + 3 or (addr - core["mm_extents"]) % 2 != 1:
        raise ValueError("physical source/target MM descriptors drifted")
    # At source index15: 024703, target index16: 024705.
    source = addr - 2
    source_pin1 = 0o000014000003
    source_pin0 = source_pin1 - (1 << 21)
    mutations = (
        ("original-preinject-wrong-pin",
         replace_one(original, "PHYSICAL_PREINJECT", "END_PREINJECT",
                     addr, pin1, pin2),
         "predeposit physical target is not exact pin1"),
        ("deposit-failed",
         replace_one(original, "PHYSICAL_SECOND_PIN", "END_SECOND_PIN",
                     addr, pin2, pin1),
         "physical simulator did not inject exactly one target pin"),
        ("rollback-lost-source-pin",
         replace_one(original, "STAGE_QUARANTINED", "END_QUARANTINED",
                     source, source_pin1, source_pin0),
         "physical overpin did not retain exact FULL MM owners"),
        ("later-clock-lost-target-pin",
         replace_one(original, "STAGE_CLOCK_LATER", "END_CLOCK_LATER",
                     addr, pin2, pin1),
         "actual postfailure PI6 lost held MM owner or root"),
    )
    for label, mutant, diagnostic in mutations:
        trace.write_text(mutant, encoding="ascii")
        try:
            result = subprocess.run([
                sys.executable, str(kit / "tests/validation/"
                    "pure-k05-physical-overpin-v1890/verify-v1890.py"),
                str(kit), str(build), str(work)],
                capture_output=True, text=True)
        finally:
            trace.write_text(original, encoding="ascii")
        if result.returncode == 0 or diagnostic not in result.stderr:
            raise ValueError("v1890 rejected wrong mutation point " + label +
                             " (" + result.stderr.strip() + ")")
        print("PASS v1890: physical %s mutant rejected" % label)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1890.py kit build evidence")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        raise SystemExit("FAIL v1890 negative physical oracle: " + str(exc))

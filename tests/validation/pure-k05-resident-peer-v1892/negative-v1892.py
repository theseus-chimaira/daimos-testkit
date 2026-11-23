#!/usr/bin/env python3
"""Executed negative controls for source-backed POST-fault user progress."""

from pathlib import Path
import re
import subprocess
import sys


def block_change(trace, start, end, needle, replacement):
    left = "V1892_%s\n" % start
    right = "V1892_%s\n" % end
    if trace.count(left) != 1 or trace.count(right) != 1:
        raise ValueError("physical heartbeat negative boundaries not unique")
    prefix, rest = trace.split(left, 1)
    body, tail = rest.split(right, 1)
    if body.count(needle) != 1:
        raise ValueError("physical heartbeat negative witness not unique")
    return prefix + left + body.replace(needle, replacement, 1) + right + tail


def word_change(trace, label, addr, old, new):
    return block_change(trace, "STAGE_" + label, "END_" + label,
                        "%o:\t%012o" % (addr, old),
                        "%o:\t%012o" % (addr, new))


def run(kit, build, work):
    trace = work / "physical.clean"
    original = trace.read_text(encoding="ascii")
    symbols = {}
    for line in (build / "kcore.map").read_text(encoding="ascii").splitlines():
        parts = line.split()
        if len(parts) == 2 and re.fullmatch(r"[0-7]+", parts[1]):
            symbols[parts[0]] = int(parts[1], 8)
    expected = {}
    for line in (work / "expected-process-v1891.txt").read_text(
            encoding="ascii").splitlines():
        name, number = line.split()
        expected[name] = int(number, 8)
    p = expected["physical_table"]
    def word(label, addr):
        first = "V1892_STAGE_%s\n" % label
        last = "V1892_END_%s\n" % label
        section = original.split(first, 1)[1].split(last, 1)[0]
        found = re.findall(r"(?m)^%o:\s*([0-7]{12})$" % addr, section)
        if len(found) != 1:
            raise ValueError("physical negative word not unique")
        return int(found[0], 8)
    second = "HEARTBEAT_2"
    parent_vm = word("HEARTBEAT_1", p + 4)
    slot3 = word(second, p + 3 * 3)
    source_meta_addr = symbols["mm_extents"] + 2 * 15 + 1
    source_meta = word(second, source_meta_addr)
    clock_addr = symbols["proc_timer_clock"]
    tick1 = word("HEARTBEAT_1", clock_addr)
    tick2 = word(second, clock_addr)
    if not source_meta & (1 << 21) or not slot3 & (1 << 16) or \
            not parent_vm & 0o777777 or tick2 <= tick1:
        raise ValueError("native physical heartbeat invariants absent")
    cases = [
        ("missing-second-real-HB",
         block_change(original, "END_STAGE_HEARTBEAT_1",
                      "ACTUAL_USER_HEARTBEAT_2", "HB", "HX"),
         "physical parent HB not newly emitted after checkpoint"),
        ("parent-no-longer-resident",
         word_change(original, "HEARTBEAT_1", p + 4, parent_vm,
                     parent_vm & ~0o777777),
         "live parent was not independently resident"),
        ("wrong-active-user-slot",
         word_change(original, "HEARTBEAT_1", symbols["proc_current_slot"],
                     1, 0),
         "heartbeat did not execute from original parent slot1"),
        ("lost-quarantined-TRANSITION",
         word_change(original, second, p + 3 * 3, slot3,
                     slot3 & ~(1 << 16)),
         "physical slot3 escaped quarantine during heartbeat"),
        ("lost-RAW-source-pin",
         word_change(original, second, source_meta_addr, source_meta,
                     source_meta - (1 << 21)),
         "physical parent heartbeat released held slot3 MM"),
        ("clock-not-advancing",
         word_change(original, second, clock_addr, tick2, tick1),
         "original PCLK did not advance between parent HBs"),
    ]
    for label, mutation, diagnostic in cases:
        trace.write_text(mutation, encoding="ascii")
        try:
            result = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-resident-peer-v1892/"
                    "verify-v1892.py"), str(kit), str(build), str(work)],
                capture_output=True, text=True)
        finally:
            trace.write_text(original, encoding="ascii")
        if result.returncode == 0 or diagnostic not in result.stderr:
            raise ValueError("v1892 mutant was not rejected at intended "
                             "physical oracle: %s (%s)" %
                             (label, result.stderr.strip()))
        print("PASS v1892: independent physical %s mutation rejected" % label)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1892.py kit build physical-work")
    try:
        run(*(Path(arg) for arg in sys.argv[1:]))
    except (ValueError, KeyError, AssertionError, OSError) as exc:
        raise SystemExit("FAIL v1892 negative physical peer oracle: " + str(exc))

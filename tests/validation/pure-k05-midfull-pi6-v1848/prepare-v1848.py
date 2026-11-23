#!/usr/bin/env python3
"""Arm an authentic KCORE PI6 tick only INSIDE pinned PURE FULL loader."""

from pathlib import Path
import runpy
import sys


def prepare(kit, build, probe, work, dxrcheck):
    previous = runpy.run_path(str(
        kit / "tests/validation/pure-k05-postfault-pi6-v1847/"
              "prepare-v1847.py"))
    previous["prepare"](kit, build, probe, work, dxrcheck)
    core_module = runpy.run_path(str(
        kit / "tests/validation/pure-k05-secondary-physical-v1845/"
              "prepare-v1845.py"))
    core = core_module["symbols"](build / "kcore.map")
    for key in ("pdp10_pi_level6", "proc_sched_pi_tick",
                "proc_swap_pressure_ticks", "proc_sched_cursor"):
        if key not in core:
            raise ValueError("missing permanent KCORE PI6/owner witness " + key)
    pi6 = core["proc_sched_pi_tick"]
    ini = (work / "physical.ini").read_text(encoding="ascii")
    # v1847 waits for its PI6 event AFTER rollback. v1848 deliberately
    # moves the same original handler breakpoint into the pinned FULL
    # window, before any source device detach or loader failure.
    start = "echo V1845_END_ROLLED_BACK\nnobreak\nbreak %06o\ncont\n" % pi6
    end = "nobreak\nattach -q dtc3 "
    if ini.count(start) != 1 or ini.count(end) != 1:
        raise ValueError("v1847 PI6 boundary no longer unique")
    prefix, tail = ini.split(start, 1)
    middle, suffix = tail.split(end, 1)
    if middle.count("V1847_ORIGINAL_PI6_CLOCK\n") != 1 or \
            middle.count("V1847_END_PI6_POSTFAIL\n") != 1:
        raise ValueError("missing original v1847 PI6 witness")
    original = prefix + "echo V1845_END_ROLLED_BACK\n" + end + suffix
    insert = "echo V1845_END_FULL_PINNED\nnobreak\ndetach dtc3\n"
    if original.count(insert) != 1:
        raise ValueError("v1845 pinned TWO-owner checkpoint drifted")
    # Include the physical PI6 return PC, which is saved by original
    # KCORE before dispatching the clock to proc_sched_pi_tick.
    tick = ("echo V1845_END_FULL_PINNED\n"
            "nobreak\nbreak %06o\ncont\n" % pi6 +
            middle.replace("V1847_", "V1848_").replace(
                "echo V1848_STAGE_PI6_POSTFAIL\n",
                "examine %06o\n" % core["pdp10_pi_level6"] +
                "echo V1848_STAGE_PI6_MIDFULL\n").replace(
                "V1848_END_PI6_POSTFAIL", "V1848_END_PI6_MIDFULL") +
            "nobreak\ndetach dtc3\n")
    # middle begins at the echoed v1847 PI6 callback, so all normal
    # terminal/wait and original first FULL loader checks are retained.
    updated = original.replace(insert, tick, 1)
    if updated.count("break %06o\n" % pi6) != 1 or \
            updated.count("detach dtc3\n") != 1 or \
            updated.count("attach -q dtc3 ") != 2:
        raise ValueError("unexpected original SIMH source-loss topology")
    (work / "physical.ini").write_text(updated, encoding="ascii")
    (work / "expected-pi6-v1848.txt").write_text(
        "pi6_pc %06o\npi6_save %06o\n" %
        (pi6, core["pdp10_pi_level6"]), encoding="ascii")
    print("v1848: original PI6 PC %06o, saved interrupted PC at %06o" %
          (pi6, core["pdp10_pi_level6"]))


def main(argv):
    if len(argv) != 6:
        raise SystemExit("usage: prepare-v1848.py kit build probe work dxrcheck")
    prepare(*(Path(s) for s in argv[1:]))


if __name__ == "__main__":
    main(sys.argv)

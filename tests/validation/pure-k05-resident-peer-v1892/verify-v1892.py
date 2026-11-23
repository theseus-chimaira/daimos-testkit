#!/usr/bin/env python3
"""Original physical pin2 quarantined slot3 and TWO later parent user ticks."""

from pathlib import Path
import re
import runpy
import sys


def heartbeat_section(trace, name):
    first = "V1892_STAGE_%s\n" % name
    last = "V1892_END_%s\n" % name
    if trace.count(first) != 1 or trace.count(last) != 1:
        raise ValueError("physical HB snapshot is missing or duplicated")
    return trace.split(first, 1)[1].split(last, 1)[0]


def read(kit, build, work):
    native = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-physical-overpin-v1890/verify-v1890.py"))
    native["read"](kit, build, work)
    stage_mod = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    core = stage_mod["symbols"]((build / "kcore.map").read_text(
        encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    src = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if src.count("(void)p14_char('H');") != 1 or \
            src.count("(void)p14_char('B');") != 1 or \
            src.count("(void)p14_char('L');") != 1:
        raise ValueError("user heartbeat not uniquely in original test guest")
    if src.index("(void)p14_char('L');") >= src.index(
            "(void)p14_char('H');") or \
            src.index("if (argc > 1)") >= src.index(
                "(void)p14_char('H');"):
        raise ValueError("user heartbeat is not parent-only after original pressure")
    markers = ["V1890_ORIGINAL_FULL_RETURN\n",
               "V1890_REAL_CLOCK_AFTER_FAILURE\n",
               "V1891_END_PROCESS_SLOTS\n",
               "V1892_OBSERVED_PARENT_READY\n",
               "V1892_ACTUAL_USER_HEARTBEAT_1\n",
               "V1892_STAGE_HEARTBEAT_1\n",
               "V1892_END_HEARTBEAT_1\n",
               "V1892_ACTUAL_USER_HEARTBEAT_2\n",
               "V1892_STAGE_HEARTBEAT_2\n",
               "V1892_END_HEARTBEAT_2\n"]
    if any(trace.count(x) != 1 for x in markers) or \
            [trace.index(x) for x in markers] != sorted(
                trace.index(x) for x in markers):
        raise ValueError("user mode heartbeats not after real failed FULL")
    for i, earlier in ((1, "V1892_OBSERVED_PARENT_READY\n"),
                       (2, "V1892_END_STAGE_HEARTBEAT_1\n")):
        end = "V1892_ACTUAL_USER_HEARTBEAT_%d\n" % i
        if trace.count(earlier) != 1:
            raise ValueError("missing parent user progress boundary")
        window = trace.split(earlier, 1)[1].split(end, 1)[0]
        if not re.search(r"HB\s*$", window):
            raise ValueError("physical parent HB not newly emitted after checkpoint")
    pointer_expected = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-process-v1891.txt").read_text(encoding="ascii")))
    ptr = pointer_expected["physical_table"]
    prior, original_extents = stage_mod["stage"](
        trace.replace("V1890_", "V1638_"), core, "CLOCK_LATER")
    previous = None
    previous_clock = 0
    for label in ("HEARTBEAT_1", "HEARTBEAT_2"):
        block, extents = stage_mod["stage"](
            trace.replace("V1892_", "V1638_"), core, label)
        section = heartbeat_section(trace, label)
        words = lambda addr: native["address_word"](section, addr)
        if words(core["proc_table"]) != ptr:
            raise ValueError("original parent process table pointer changed")
        slot3 = words(ptr + 3 * 3)
        vm3 = words(ptr + 3 * 3 + 1)
        parent = words(ptr + 3)
        parent_vm = words(ptr + 4)
        parent_state = (words(ptr + 5) >> 33) & 7
        if not (slot3 & (1 << 16)) or vm3 & 0o777777:
            raise ValueError("physical slot3 escaped quarantine during heartbeat")
        if block[core["proc_current_slot"]] != 1:
            raise ValueError("heartbeat did not execute from original parent slot1")
        if (parent & (1 << 16)) or (parent_vm & 0o777777) != 0o130000 or \
                parent_state != 2:
            raise ValueError("live parent was not independently resident")
        expected = [(0o111200, 0o120000, 4, 1, 3),
                    (0o120000, 0o130000, 1, 2, 3)]
        if any(extents.count(x) != 1 for x in expected):
            raise ValueError("physical parent heartbeat released held slot3 MM")
        if extents.count((0o130000, 0o140000, 1, 0, 1)) != 1:
            raise ValueError("physical parent lost its independent resident APR")
        if extents != original_extents or \
                block[core["mm_extent_count"]] != prior[core["mm_extent_count"]]:
            raise ValueError("physical heartbeat changed an unrelated MM owner")
        if block[core["vfs_namespace_root"]] >> 24 != (7 << 6) | 1:
            raise ValueError("physical heartbeat changed TSFS ROOT")
        clock = words(core["proc_timer_clock"])
        if previous is not None:
            if clock <= previous_clock:
                raise ValueError("original PCLK did not advance between parent HBs")
            if block[core["vfs_namespace_root"]] != \
                    previous[core["vfs_namespace_root"]]:
                raise ValueError("original TSFS root changed between parent HBs")
        previous_clock = clock
        previous = block
    print("PASS v1892: physical resident parent emitted 2 new HB markers after FULL -5")
    print("v1892: original user parent APR and heartbeat PCLK progress confirmed")
    print("v1892: slot3 TRANSITION, RAW pin1 and target pin2 survive both heartbeats")
    print("NOT PROVEN: independently resident secondary child or postfault WAIT/HALT")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1892.py kit build physical-work")
    try:
        read(*(Path(a) for a in sys.argv[1:]))
    except (ValueError, KeyError, AssertionError, OSError, UnicodeError) as exc:
        raise SystemExit("FAIL v1892 original resident user peer: " + str(exc))

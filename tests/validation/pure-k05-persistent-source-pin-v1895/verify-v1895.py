#!/usr/bin/env python3
"""Actual PDP6 permanent source pin and independent parent user progress."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def section(trace, a, b):
    start = "V1895_%s\n" % a
    stop = "V1895_%s\n" % b
    if trace.count(start) != 1 or trace.count(stop) != 1:
        raise ValueError("missing original physical source-pin stage " + a)
    return trace.split(start, 1)[1].split(stop, 1)[0]


def word(text, addr):
    values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, text)
    if len(values) != 1:
        raise ValueError("original physical word not unique: %06o" % addr)
    return int(values[0], 8)


def read(kit, build, work):
    original = runpy.run_path(str(kit / "tests/diagnostics/"
                         "pure-full-restore-v1638/audit-v1638.py"))
    core = original["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    exp = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1895.txt").read_text(encoding="ascii")))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("original production PDP6 KCORE/PURE image changed")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if guest.count("(void)p14_char('H');") != 1 or \
            guest.count("(void)p14_char('B');") != 1 or \
            guest.count("(void)p14_char('L');") != 1 or \
            guest.count("#define P14_CHILDREN         5U") != 1 or \
            guest.index("(void)p14_char('L');") >= guest.index(
                "(void)p14_char('H');") or \
            guest.index("if (argc > 1)") >= guest.index(
                "(void)p14_char('H');"):
        raise ValueError("not original 5-child fixture plus ONLY resident parent HB")
    checkpoints = [
        "V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
        "V1894_ORIGINAL_SOURCE_FREE_CALL\n", "V1894_STAGE_BEFORE_PIN\n",
        "V1894_END_BEFORE_PIN\n", "V1894_TEMPORARY_REAL_PIN\n",
        "V1894_END_TEMPORARY_REAL_PIN\n",
        "V1894_ACTUAL_MM_FREE_REFUSAL\n", "V1894_STAGE_REFUSED\n",
        "V1894_END_REFUSED\n", "V1895_PERSISTENT_EXTERNAL_SOURCE_PIN\n",
        "V1895_END_PERSISTENT_PIN\n",
        "V1895_ORIGINAL_QUARANTINED_FULL_RETURN\n",
        "V1895_STAGE_QUARANTINED\n", "V1895_END_QUARANTINED\n",
        "V1895_ACTUAL_RESIDENT_HEARTBEAT_1\n",
        "V1895_STAGE_HEARTBEAT_1\n", "V1895_END_HEARTBEAT_1\n",
        "V1895_ACTUAL_RESIDENT_HEARTBEAT_2\n",
        "V1895_STAGE_HEARTBEAT_2\n", "V1895_END_HEARTBEAT_2\n",
    ]
    if any(trace.count(x) != 1 for x in checkpoints) or \
            [trace.index(x) for x in checkpoints] != sorted(
                trace.index(x) for x in checkpoints):
        raise ValueError("original physical source-free / heartbeat order invalid")
    for symbol in ("MEM                                  48 K",
                   "PURE                              LOADED",
                   "DTFS                              LOADED", "aaaaax[B"):
        if symbol not in trace:
            raise ValueError("not source-built original 48K five-child pressure")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("original executable backing was detached")
    for key in ("source_call", "source_return", "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % exp[key], trace):
            raise ValueError("actual original source-linked PC absent: " + key)
    pinned, at_entry = original["stage"](
        trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    srcpin = (0o111200, 0o120000, 4, 1, 3)
    tgtpin = (0o120000, 0o130000, 1, 1, 3)
    src0 = (0o111200, 0o120000, 4, 0, 3)
    tgt0 = (0o120000, 0o130000, 1, 0, 3)
    if at_entry.count(srcpin) != 1 or at_entry.count(tgtpin) != 1 or \
            pinned[core["mm_extent_count"]] != 18:
        raise ValueError("original FULL did not begin with exactly two pinned owners")
    expected_free = [src0 if e == srcpin else tgt0 if e == tgtpin else e
                     for e in at_entry]
    at_call, free = original["stage"](
        trace.replace("V1894_", "V1638_"), core, "BEFORE_PIN")
    if free != expected_free:
        raise ValueError("original C failed to unpin both source and target before free")
    addr = exp["source_meta_address"]
    if word(trace.split("V1894_ORIGINAL_SOURCE_FREE_CALL\n", 1)[1].split(
            "V1894_STAGE_BEFORE_PIN\n", 1)[0], addr) != exp["source_meta_pin0"]:
        raise ValueError("native MM source not initially unpinned")
    if word(trace.split("V1894_TEMPORARY_REAL_PIN\n", 1)[1].split(
            "V1894_END_TEMPORARY_REAL_PIN\n", 1)[0], addr) != exp["source_meta_pin1"]:
        raise ValueError("external source pin never acquired")
    refused, preserved = original["stage"](
        trace.replace("V1894_", "V1638_"), core, "REFUSED")
    expected_held = [srcpin if e == src0 else e for e in expected_free]
    if preserved != expected_held or refused[core["mm_extent_count"]] != 18:
        raise ValueError("original mm_free did not retain both extents and source pin")
    ac1 = word(trace.split("V1894_ACTUAL_MM_FREE_REFUSAL\n", 1)[1].split(
        "V1894_STAGE_REFUSED\n", 1)[0], 1)
    if ac1 != 0o777777777773:
        raise ValueError("original real fixed KCORE mm_free did not return -5")
    if word(section(trace, "PERSISTENT_EXTERNAL_SOURCE_PIN", "END_PERSISTENT_PIN"),
            addr) != exp["source_meta_pin1"]:
        raise ValueError("persistent external PACKED pin unexpectedly released")
    root = refused[core["vfs_namespace_root"]]
    if root != pinned[core["vfs_namespace_root"]] or \
            at_call[core["vfs_namespace_root"]] != root:
        raise ValueError("selected TSFS root changed during original source free")
    prev_clock = None
    for tag in ("QUARANTINED", "HEARTBEAT_1", "HEARTBEAT_2"):
        frame, extents = original["stage"](
            trace.replace("V1895_", "V1638_"), core, tag)
        section_text = section(trace, "STAGE_" + tag, "END_" + tag)
        if extents != expected_held or frame[core["mm_extent_count"]] != 18:
            raise ValueError("persistent source pin lost exact original owners: " + tag)
        if frame[core["vfs_namespace_root"]] != root:
            raise ValueError("original TSFS root changed after persistent free failure")
        if word(section_text, core["proc_table"]) != exp["process_table"]:
            raise ValueError("original process table pointer changed")
        proc3 = word(section_text, exp["process_table"] + 9)
        vm3 = word(section_text, exp["process_table"] + 10)
        if not (proc3 & (1 << 16)) or (vm3 & 0o777777):
            raise ValueError("quarantined slot3 lost TRANSITION or published APR")
        if tag == "QUARANTINED":
            if word(section(trace, "ORIGINAL_QUARANTINED_FULL_RETURN",
                            "STAGE_QUARANTINED"), 1) != 0o777777777773:
                raise ValueError("genuine source-free refusal was not retained as -5")
        else:
            if frame[core["proc_current_slot"]] != 1:
                raise ValueError("user HB not executing from actual resident parent")
            p = word(section_text, exp["process_table"] + 3)
            pvm = word(section_text, exp["process_table"] + 4)
            pstate = word(section_text, exp["process_table"] + 5)
            if p & (1 << 16) or (pvm & 0o777777) != 0o130000 or \
                    (pstate >> 33 & 7) != 2 or \
                    (0o130000, 0o140000, 1, 0, 1) not in extents:
                raise ValueError("original parent lost real independent resident APR")
        clock = word(section_text, core["proc_timer_clock"])
        # The first independently emitted HB can occur in the same
        # original PCLK interval as the failed FULL return. Only the
        # two separately emitted postfault user HBs must demonstrate
        # an advancing original clock; never claim an extra PI6 tick
        # that the original hardware did not actually execute.
        if tag == "HEARTBEAT_2" and (prev_clock is None or clock <= prev_clock):
            raise ValueError("original PCLK clock failed to advance across user HBs")
        if tag != "QUARANTINED":
            prev_clock = clock
    for event, prior in (("ACTUAL_RESIDENT_HEARTBEAT_1",
                          "V1895_END_QUARANTINED\n"),
                         ("ACTUAL_RESIDENT_HEARTBEAT_2",
                          "V1895_END_HEARTBEAT_1\n")):
        window = trace.split(prior, 1)[1].split("V1895_" + event + "\n", 1)[0]
        if not re.search(r"HB\s*$", window):
            raise ValueError("second independent parent HB not physically emitted")
    print("PASS v1895: real fixed-KCORE mm_free -5 with source pin1 permanently held")
    print("v1895: no unsafe rollback, 18 identical MM extents, slot3 TRANSITION VM0")
    print("v1895: two actual parent user HBs and real advancing original PCLK")
    print("NOT PROVEN: child WAIT/HALT, source unpin, terminal uncertain-owner cleanup")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1895.py kit original-build physical-work")
    try:
        read(*(Path(x) for x in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as exc:
        raise SystemExit("FAIL v1895 persistent source pin: " + str(exc))

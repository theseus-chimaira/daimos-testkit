#!/usr/bin/env python3
"""Test the original slot-0 rollback while its PROCESS target stays pinned."""

from pathlib import Path
import re
import runpy
import sys


def one(path, name):
    values = re.findall(r"(?m)^%s\s+([0-7]+)$" % name,
                        path.read_text(encoding="ascii"))
    if len(values) != 1:
        raise ValueError("missing exact v1903 physical key: " + name)
    return int(values[0], 8)


def prepare(kit, build, probe, work, prefix):
    old = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-full-commit-v1903/prepare-physical-v1903.py"))
    old["prepare"](kit, build, probe, work, prefix)
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = base["symbols"](build / "kcore.map")
    source_meta = one(work / "expected-v1902.txt", "source_meta")
    table = one(work / "expected-v1903.txt", "process_table")
    uarea = one(work / "expected-v1903.txt", "uarea")
    parent_gate = one(work / "expected-v1903.txt", "parent_gate")
    # Two words per MM descriptor. The next descriptor after PACKED
    # belongs to the full target, whereas source_meta+4 is the
    # independent resident parent. Never pin that foreign process.
    target_meta = source_meta + 2
    target0 = 0o1000003
    target1 = 0o11000003
    # Exact original v1903 48K MM layout. The RAW source and complete
    # target are adjacent in the real MM extent table, not inferred from
    # a temporary guest pointer or synthetic owner registry.
    if source_meta != core["mm_extents"] + 0o37 or \
            target_meta != core["mm_extents"] + 0o41:
        raise ValueError("source-linked target descriptor is not slot3 PROCESS")

    def snapshot(label):
        old = base["snapshot"](core, label).replace("V1845_", "V1904_")
        tail = "echo V1904_END_%s\n" % label
        if not old.endswith(tail):
            raise ValueError("original physical MM snapshot format changed")
        return (old[:-len(tail)] +
                "examine %06o\n" % core["proc_table"] +
                "examine %06o-%06o\n" % (table, table+0o20) +
                "examine %06o\n" % core["proc_timer_clock"] +
                # Adjacent in original proc_pdp6.s BSS: timer_next
                # then the shared post-VM retry epoch/delay word.
                "examine %06o\n" % (core["proc_timer_clock"]+2) +
                "examine %06o\n" % (uarea+0o20) +
                "examine %06o\n" % (uarea+0o24) +
                "examine %06o\n" % (uarea+0o67) +
                "examine %06o\n" % parent_gate + tail)

    script_path = work / "physical.ini"
    script = script_path.read_text(encoding="ascii")
    anchor = "echo V1902_END_PIN_RELEASE\n"
    if script.count(anchor) != 1:
        raise ValueError("original v1903 source pin release not unique")
    # After the ORIGINAL source was released and before the simulated
    # machine advances, add ONE external pin to the remaining target.
    # The core must not free either owner while the target remains
    # pinned. Its normal idle retries, timer, and parent heartbeat run.
    insert = ("echo V1904_TARGET_EXTERNAL_PIN_INSTALL\n" +
              "examine %06o\n" % target_meta +
              "deposit %06o %012o\n" % (target_meta,target1) +
              "echo V1904_END_TARGET_PIN_INSTALL\n")
    for i in (1,2,3):
        insert += ("nobreak all\nexpect \"HB\"\ncont\n" +
                   "echo V1904_TARGET_PINNED_PARENT_HB_%d\n" % i +
                   snapshot("HELD_HB_%d" % i))
    insert += ("echo V1904_TARGET_EXTERNAL_PIN_RELEASE\n" +
               "examine %06o\n" % target_meta +
               "examine %06o\n" % core["proc_timer_clock"] +
               "examine %06o\n" % (core["proc_timer_clock"]+2) +
               "deposit %06o %012o\n" % (target_meta,target0) +
               "echo V1904_END_TARGET_PIN_RELEASE\n")
    script = script.replace(anchor,anchor+insert,1)
    if "nobreak\n" in script or \
            script.count("deposit %06o %012o\n" % (target_meta,target1)) != 1 or \
            script.count("deposit %06o %012o\n" % (target_meta,target0)) != 1:
        raise ValueError("unsafe/duplicate physical target-pin controller")
    script_path.write_text(script, encoding="ascii")
    (work / "expected-v1904.txt").write_text(
        "target_meta %06o\ntarget_pin0 %012o\ntarget_pin1 %012o\n"
        "retry_word %06o\n" %
        (target_meta,target0,target1,core["proc_timer_clock"]+2),
        encoding="ascii")
    print("v1904: source-linked slot3 target %06o; three pinned parent HBs" %
          target_meta)


if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: prepare-physical-v1904.py kit build probe work prefix")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError, ValueError, AssertionError, KeyError) as exc:
        raise SystemExit("FAIL v1904 physical preparation: " + str(exc))

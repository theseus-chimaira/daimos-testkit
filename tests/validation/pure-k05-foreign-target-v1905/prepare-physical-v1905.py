#!/usr/bin/env python3
"""Exercise original K05 recovery with a foreign-claimed full target."""

from pathlib import Path
import runpy
import sys


def prepare(kit, build, probe, work, prefix):
    original = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-full-commit-v1903/prepare-physical-v1903.py"))
    original["prepare"](kit, build, probe, work, prefix)
    helper = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = helper["symbols"](build / "kcore.map")
    get = original["one"]
    target_meta = get(work / "expected-v1902.txt", "source_meta") + 2
    user = get(work / "expected-v1903.txt", "uarea")
    table = get(work / "expected-v1903.txt", "process_table")
    transition_pc = get(work / "expected-v1903.txt", "transition_clear")
    if target_meta != core["mm_extents"] + 0o41:
        raise ValueError("foreign fault is not the original slot3 target")

    def snap(label):
        text = helper["snapshot"](core, label).replace("V1845_", "V1905_")
        end = "echo V1905_END_%s\n" % label
        if not text.endswith(end):
            raise ValueError("native MM snapshot convention drifted")
        return (text[:-len(end)] +
                "examine %06o\n" % core["proc_table"] +
                "examine %06o-%06o\n" % (table,table+0o20) +
                "examine %06o\n" % (user+0o20) +
                "examine %06o\n" % (user+0o24) +
                "examine %06o\n" % (user+0o67) +
                "examine %06o\n" % core["proc_timer_clock"] +
                "examine %06o\n" % (core["proc_timer_clock"]+2) + end)

    path = work / "physical.ini"
    script = path.read_text(encoding="ascii")
    anchor = "echo V1902_END_PIN_RELEASE\n"
    if script.count(anchor) != 1:
        raise ValueError("original v1903 source-pin release anchor missing")
    # The original FULL/source error already installed a real pending
    # retry bit. Change only the surviving provisional target OWNER
    # from slot3 to slot2, leaving its PROCESS type, size and pin0
    # intact. This is explicit test-only corrupt metadata, not a
    # legitimate MM ownership transfer or production scheduler event.
    foreign_meta = (1 << 18) | 2
    own_meta = (1 << 18) | 3
    script = (script.split(anchor,1)[0] + anchor +
              "echo V1905_FOREIGN_TARGET_INJECT\n" +
              "examine %06o\n" % target_meta +
              "deposit %06o %012o\n" % (target_meta,foreign_meta) +
              "echo V1905_END_FOREIGN_TARGET_INJECT\n" +
              "nobreak all\nbreak %06o\ncont\n" % transition_pc +
              "echo V1905_ORIGINAL_TRANSITION_CLEAR_PC\n" +
              snap("UNSAFE_CLEAR") +
              "exit\n")
    if script.count("deposit %06o %012o\n" %
                    (target_meta,foreign_meta)) != 1 or \
            "deposit %06o %012o\n" % (target_meta,own_meta) in script or \
            "nobreak\n" in script:
        raise ValueError("uncontrolled foreign-owner injection or breakpoints")
    path.write_text(script,encoding="ascii")
    (work / "expected-v1905.txt").write_text(
        "target_meta %06o\nsource_meta %06o\nforeign_meta %012o\n"
        "own_meta %012o\ntransition_clear %06o\nprocess_table %06o\n"
        "uarea %06o\n" % (target_meta,target_meta-2,foreign_meta,
                          own_meta,transition_pc,table,user),encoding="ascii")
    print("v1905: induced foreign owner at %06o, original TRANSITION PC %06o" %
          (target_meta,transition_pc))


if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: prepare-physical-v1905.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError, ValueError, AssertionError, KeyError) as exc:
        raise SystemExit("FAIL v1905 physical setup: " + str(exc))

#!/usr/bin/env python3
"""Execute independent unsafe original physical MM cleanup/parent mutations."""

from pathlib import Path
import re
import subprocess
import sys


def stage(trace, prefix, first, last):
    a = "V%s_%s\n" % (prefix, first)
    b = "V%s_%s\n" % (prefix, last)
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("original source-linked MM stage missing")
    return a, b


def replace(trace, prefix, first, last, old, new):
    a, b = stage(trace, prefix, first, last)
    left, tail = trace.split(a, 1)
    middle, right = tail.split(b, 1)
    if middle.count(old) != 1:
        raise ValueError("negative physical MM value not uniquely present")
    return left + a + middle.replace(old, new, 1) + b + right


def value(trace, prefix, first, last, address):
    a, b = stage(trace, prefix, first, last)
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address,
                       trace.split(a, 1)[1].split(b, 1)[0])
    if len(found) != 1:
        raise ValueError("not one original physical word")
    return int(found[0], 8)


def word(trace, prefix, first, last, address, old, new):
    return replace(trace, prefix, first, last,
                   "%o:\t%012o" % (address, old),
                   "%o:\t%012o" % (address, new))


def run(kit, build, work):
    target = work / "physical.clean"
    original_bytes = target.read_bytes()
    original = original_bytes.decode("ascii")
    fields = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1896.txt").read_text(encoding="ascii")))
    core = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^(\S+)\s+([0-7]{6})\s*$",
        (build / "kcore.map").read_text(encoding="ascii")))
    src = fields["source_meta_address"]
    dst = fields["target_meta_address"]
    proc = fields["process_table"]
    slot3meta = value(original, "1896", "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1", proc + 9)
    slot3vm = value(original, "1896", "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2", proc + 10)
    clk1 = value(original, "1896", "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
                 core["proc_timer_clock"])
    clk2 = value(original, "1896", "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
                 core["proc_timer_clock"])
    if not (slot3meta & (1 << 16)) or clk2 <= clk1:
        raise ValueError("original real physical process or PCLK contract drifted")
    mutants = [
        ("original-source-free-was-not-refused",
         word(original, "1894", "ACTUAL_MM_FREE_REFUSAL", "STAGE_REFUSED",
              1, 0o777777777773, 0),
         "original source mm_free did not genuinely refuse -5"),
        ("source-pin-release-missing-before-target-cleanup",
         word(original, "1894", "EXTERNAL_PIN_RELEASE", "STAGE_TWO_UNPINNED",
              src, fields["source_meta_pin0"], fields["source_meta_pin1"]),
         "source pin was not released for checked rollback"),
        ("target-pinned-before-original-cleanup-call",
         word(original, "1896", "ORIGINAL_TARGET_FREE_CALL", "STAGE_TARGET_FREE_CALL",
              dst, fields["target_meta_pin0"], fields["target_meta_pin1"]),
         "original target was already pinned before cleanup free"),
        ("missing-external-target-pin",
         word(original, "1896", "EXTERNAL_TARGET_PIN_PERSISTENT",
              "END_TARGET_PIN_PERSISTENT", dst,
              fields["target_meta_pin1"], fields["target_meta_pin0"]),
         "target MM external persistent pin injection missing"),
        ("original-target-free-falsely-returned-success",
         word(original, "1896", "ACTUAL_NATIVE_TARGET_FREE_REFUSAL",
              "STAGE_TARGET_REFUSED", 1, 0o777777777773, 0),
         "original native MM target free did not genuinely refuse -5"),
        ("target-lost-despite-native-free-refusal",
         word(original, "1896", "STAGE_TARGET_REFUSED", "END_TARGET_REFUSED",
              dst, fields["target_meta_pin1"], fields["target_meta_pin0"]),
         "original target cleanup free changed protected MM owners"),
        ("source-lost-during-failed-target-cleanup",
         word(original, "1896", "STAGE_QUARANTINED", "END_QUARANTINED",
              src, fields["source_meta_pin0"], fields["source_meta_pin1"]),
         "failed native target cleanup lost MM owners"),
        ("slot3-transition-falsely-cleared",
         word(original, "1896", "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
              proc + 9, slot3meta, slot3meta & ~(1 << 16)),
         "failed target rollback cleared TRANSITION or published APR"),
        ("slot3-runnable-VM-falsely-published",
         word(original, "1896", "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
              proc + 10, slot3vm, slot3vm | 0o120000),
         "failed target rollback cleared TRANSITION or published APR"),
        ("original-full-return-incorrectly-successful",
         word(original, "1896", "ORIGINAL_FULL_FAILED_CLEANUP_RETURN",
              "STAGE_QUARANTINED", 1, 0o777777777773, 0),
         "failed target cleanup lost original MM_ERR_BUSY reply"),
        ("parent-not-running-after-target-cleanup-refusal",
         word(original, "1896", "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
              core["proc_current_slot"], 1, 3),
         "postfailure user HB not dispatched as original parent"),
        ("PCLK-falsely-stopped-between-new-heartbeats",
         word(original, "1896", "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
              core["proc_timer_clock"], clk2, clk1),
         "original PCLK failed to advance between new user heartbeats"),
        ("second-parent-heartbeat-not-actually-emitted",
         replace(original, "1896", "END_HEARTBEAT_1",
                 "ACTUAL_RESIDENT_HEARTBEAT_2", "HB", "XX"),
         "original user did not emit both independent postfailure HB"),
    ]
    for name, altered, expected in mutants:
        if altered == original:
            raise ValueError("original negative physical transcript was not mutated")
        target.write_text(altered, encoding="ascii")
        try:
            p = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-target-free-refusal-v1896/"
                    "verify-v1896.py"), str(kit), str(build), str(work)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        finally:
            target.write_bytes(original_bytes)
        if p.returncode == 0 or expected not in p.stderr:
            raise ValueError("unsafe original physical %s not rejected at intended check: %s"
                             % (name, p.stderr.strip()))
        print("PASS v1896: unsafe original physical %s transcript rejected" % name)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1896.py kit original-build physical-work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1896 negative physical owner/cleanup oracle: " + str(exc))

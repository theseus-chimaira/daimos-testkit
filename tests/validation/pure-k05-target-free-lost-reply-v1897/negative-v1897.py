#!/usr/bin/env python3
"""Execute forged physical transcripts against the target-free audit."""

from pathlib import Path
import re
import subprocess
import sys


def replace(text, prefix, first, last, old, new):
    start = "V%s_%s\n" % (prefix, first)
    stop = "V%s_%s\n" % (prefix, last)
    if text.count(start) != 1 or text.count(stop) != 1:
        raise ValueError("original physical target free stage is not unique")
    left, remaining = text.split(start, 1)
    middle, right = remaining.split(stop, 1)
    if middle.count(old) != 1:
        raise ValueError("original physical target free oracle input not unique")
    return left + start + middle.replace(old, new, 1) + stop + right


def value(text, prefix, first, last, addr):
    start = "V%s_%s\n" % (prefix, first)
    stop = "V%s_%s\n" % (prefix, last)
    block = text.split(start, 1)[1].split(stop, 1)[0]
    values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, block)
    # The original MM snapshot prints the count both in its header
    # and as the first cell of the contiguous MM descriptor dump.
    # Either one or two IDENTICAL observations are legitimate.
    if not values or len(values) > 2 or len(set(values)) != 1:
        raise ValueError("original physical MM value not uniquely observed")
    return int(values[0], 8)


def field(text, prefix, first, last, addr, before, after):
    return replace(text, prefix, first, last,
                   "%o:\t%012o" % (addr, before),
                   "%o:\t%012o" % (addr, after))


def repeated_field(text, prefix, first, last, addr, before, after):
    start = "V%s_%s\n" % (prefix, first)
    stop = "V%s_%s\n" % (prefix, last)
    left, remaining = text.split(start, 1)
    middle, right = remaining.split(stop, 1)
    old = "%o:\t%012o" % (addr, before)
    new = "%o:\t%012o" % (addr, after)
    if middle.count(old) != 2:
        raise ValueError("original MM count did not have two exact printouts")
    return left + start + middle.replace(old, new) + stop + right


def run(kit, build, work):
    target = work / "physical.clean"
    original_bytes = target.read_bytes()
    original = original_bytes.decode("ascii")
    exp = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1897.txt").read_text(encoding="ascii")))
    core = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^(\S+)\s+([0-7]{6})\s*$",
        (build / "kcore.map").read_text(encoding="ascii")))
    source = exp["source_meta_address"]
    target_meta = exp["target_meta_address"]
    meta3 = value(original, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL",
                  exp["process_table"] + 9)
    vm3 = value(original, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL",
                exp["process_table"] + 10)
    final_count = value(original, "1897", "STAGE_Z", "END_Z", core["mm_extent_count"])
    if not (meta3 & (1 << 16)) or final_count != 8:
        raise ValueError("original physical source/target contract changed")
    cases = [
        ("source-free-false-success",
         field(original, "1894", "ACTUAL_MM_FREE_REFUSAL", "STAGE_REFUSED", 1,
               0o777777777773, 0),
         "original PACKED source free did not genuinely return -5"),
        ("target-pinned-before-native-free-call",
         field(original, "1897", "ORIGINAL_TARGET_FREE_CALL", "STAGE_TARGET_FREE_CALL",
               target_meta, 0o000001000003, 0o000011000003),
         "original target was not physical pin0 at free entry"),
        ("original-target-free-actually-refused",
         field(original, "1897", "ORIGINAL_SUCCESSFUL_TARGET_FREE_RETURN",
               "STAGE_TARGET_FREED", 1, 0, 0o777777777773),
         "original native target cleanup free did not return MM_OK"),
        ("successful-target-free-left-unknown-source-pin",
         field(original, "1897", "STAGE_TARGET_FREED", "END_TARGET_FREED",
               source, exp["source_meta_pin0"], exp["source_meta_pin1"]),
         "original native target cleanup did not physically delete target"),
        ("lost-target-reply-not-injected",
         field(original, "1897", "FORGED_FAILED_TARGET_FREE_REPLY",
               "END_FORGED_FAILED_TARGET_FREE_REPLY", 1,
               0o777777777773, 0),
         "target cleanup free success reply not replaced by test-only -5"),
        ("source-retained-after-failure-has-foreign-owner",
         field(original, "1897", "STAGE_FAILED_FULL", "END_FAILED_FULL",
               source, exp["source_meta_pin0"], exp["source_meta_pin0"] - 1),
         "original failed cleanup reply lost authoritative RAW source"),
        ("original-FULL-erroneously-succeeds",
         field(original, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL",
               1, 0o777777777773, 0),
         "original failed target-free reply did not report BUSY"),
        ("original-process-table-pointer-stale",
         field(original, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL",
               core["proc_table"], exp["process_table"], exp["process_table"] + 3),
         "original proc_table pointer changed"),
        ("slot3-transition-falsely-cleared",
         field(original, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL",
               exp["process_table"] + 9, meta3, meta3 & ~(1 << 16)),
         "original falsely successful rollback published invalid slot3 APR"),
        ("slot3-VM-falsely-published",
         field(original, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL",
               exp["process_table"] + 10, vm3, vm3 | 0o120000),
         "original falsely successful rollback published invalid slot3 APR"),
        ("terminal-MM-count-leaked",
         repeated_field(original, "1897", "STAGE_Z", "END_Z",
                        core["mm_extent_count"], final_count, final_count - 1),
         "original terminal WAIT left stale slot3 PACKED/PROCESS"),
        ("terminal-HALT-not-reached",
         original.replace("HALT instruction, PC: 000000",
                          "HALT instruction, PC: 000001", 1),
         "original five child EXIT/WAIT and parent HALT did not recover"),
    ]
    for name, mutant, diagnostic in cases:
        if mutant == original:
            raise ValueError("unsafe original physical target-free transcript unchanged: " + name)
        target.write_text(mutant, encoding="ascii")
        try:
            p = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-target-free-lost-reply-v1897/"
                    "verify-v1897.py"), str(kit), str(build), str(work)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        finally:
            target.write_bytes(original_bytes)
        if p.returncode == 0 or diagnostic not in p.stderr:
            raise ValueError("unsafe physical %s not rejected at intended test: %s"
                             % (name, p.stderr.strip()))
        print("PASS v1897: unsafe original physical %s transcript rejected" % name)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1897.py kit original-build physical-work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1897 original physical target-free negatives: " + str(exc))

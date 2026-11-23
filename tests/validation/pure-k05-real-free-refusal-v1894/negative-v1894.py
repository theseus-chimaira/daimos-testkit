#!/usr/bin/env python3
"""Executed unsafe physical transcripts for real PDP6 PACKED-free -5."""

from pathlib import Path
import re
import subprocess
import sys


def change(text, begin, end, old, new):
    start = "V1894_%s\n" % begin
    stop = "V1894_%s\n" % end
    if text.count(start) != 1 or text.count(stop) != 1:
        raise ValueError("physical negative control stage boundary missing")
    left, remainder = text.split(start, 1)
    data, right = remainder.split(stop, 1)
    if data.count(old) != 1:
        raise ValueError("actual physical MM word not unique in negative control")
    return left + start + data.replace(old, new, 1) + stop + right


def word(text, begin, end, addr, before, after):
    return change(text, begin, end, "%o:\t%012o" % (addr, before),
                  "%o:\t%012o" % (addr, after))


def run(kit, build, work):
    original = (work / "physical.clean").read_text(encoding="ascii")
    expected = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1894.txt").read_text(encoding="ascii")))
    source = expected["source_meta_address"]
    pin0 = expected["source_meta_pin0"]
    pin1 = expected["source_meta_pin1"]
    vars = [
        ("original-source-not-unpinned",
         word(original, "ORIGINAL_SOURCE_FREE_CALL", "STAGE_BEFORE_PIN",
              source, pin0, pin1),
         "original source MM pin not physically zero at free call"),
        ("external-pin-injection-missing",
         word(original, "TEMPORARY_REAL_PIN", "END_TEMPORARY_REAL_PIN",
              source, pin1, pin0),
         "original source MM physical pin injection missing"),
        ("physical-mm-free-accepted-pinned-source",
         word(original, "ACTUAL_MM_FREE_REFUSAL", "STAGE_REFUSED", 1,
              0o777777777773, 0),
         "original MM did not actually refuse pinned source -5"),
        ("source-was-destroyed-despite-refusal",
         word(original, "STAGE_REFUSED", "END_REFUSED",
              source, pin1, pin0),
         "native mm_free BUSY did not preserve both owners/pins"),
        ("external-pin-not-released",
         word(original, "EXTERNAL_PIN_RELEASE", "STAGE_TWO_UNPINNED",
              source, pin0, pin1),
         "temporary external pin was not physically released"),
        ("exact-two-owner-scan-unsafe",
         word(original, "STAGE_TWO_UNPINNED", "END_TWO_UNPINNED",
              source, pin0, pin1),
         "genuinely refused free did not retain exact two unpinned owners"),
        ("rollback-falsely-published-success",
         word(original, "ORIGINAL_ROLLBACK_RETURN", "STAGE_ROLLED_BACK",
              1, 0o777777777773, 0),
         "original v1839 rollback failed to return actual MM_BUSY"),
    ]
    for label, changed, diagnostic in vars:
        (work / "physical.clean").write_text(changed, encoding="ascii")
        try:
            result = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-real-free-refusal-v1894/"
                    "verify-v1894.py"), str(kit), str(build), str(work)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        finally:
            (work / "physical.clean").write_text(original, encoding="ascii")
        if result.returncode == 0 or diagnostic not in result.stderr:
            raise ValueError("unsafe physical %s NOT rejected at intended check: %s"
                             % (label, result.stderr.strip()))
        print("PASS v1894: unsafe %s physical transcript rejected" % label)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1894.py kit original-build physical-work")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1894 original physical negative controls: " + str(exc))

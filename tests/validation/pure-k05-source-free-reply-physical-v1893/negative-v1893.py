#!/usr/bin/env python3
"""Execute forged physical source-free reply traces against exact oracle."""

from pathlib import Path
import re
import subprocess
import sys


def change(trace, first, last, needle, replacement):
    a = "V1893_%s\n" % first
    b = "V1893_%s\n" % last
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("source-free physical mutation boundary missing")
    left, rest = trace.split(a, 1)
    body, right = rest.split(b, 1)
    if body.count(needle) != 1:
        raise ValueError("original source-free physical word not unique")
    return left + a + body.replace(needle, replacement, 1) + b + right


def field(trace, first, last, addr, old, new):
    return change(trace, first, last,
                  "%o:\t%012o" % (addr, old),
                  "%o:\t%012o" % (addr, new))


def run(kit, build, work):
    trace = work / "physical.clean"
    original = trace.read_text(encoding="ascii")
    actual = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1893.txt").read_text(encoding="ascii")))
    core = {}
    for row in (build / "kcore.map").read_text(encoding="ascii").splitlines():
        parts = row.split()
        if len(parts) == 2 and re.fullmatch(r"[0-7]+", parts[1]):
            core[parts[0]] = int(parts[1], 8)
    first = "REAL_SOURCE_FREE_RETURN"
    second = "STAGE_SOURCE_FREED"
    stage_end = "END_SOURCE_FREED"
    values = dict((int(a, 8), int(b, 8)) for a, b in re.findall(
        r"(?m)^([0-7]+):\s*([0-7]{12})$",
        original.split("V1893_%s\n" % second, 1)[1].split(
            "V1893_%s\n" % stage_end, 1)[0]))
    candidates = []
    for n in range(values[core["mm_extent_count"]]):
        k = core["mm_extents"] + 2 * n
        if values[k] & 0o777777 == 0o120000:
            candidates.append(k + 1)
    if len(candidates) != 1:
        raise ValueError("original physical sole target descriptor missing")
    target_meta_addr = candidates[0]
    target_meta = values[target_meta_addr]
    p3 = actual["original_proc_table"] + 3 * 3
    published = dict((int(a, 8), int(b, 8)) for a, b in re.findall(
        r"(?m)^([0-7]+):\s*([0-7]{12})$",
        original.split("V1893_ORIGINAL_RECOVERED_FULL_RETURN\n", 1)[1].split(
            "V1893_STAGE_RESTORED\n", 1)[0]))
    if target_meta != 0o000001000003 or not 0 <= published[p3] < (1 << 36):
        raise ValueError("original source free metadata not expected")
    mutants = [
        ("real-free-did-not-succeed",
         field(original, first, second, 1, 0, 0o777777777773),
         "original physical mm_free did not genuinely succeed"),
        ("sole-target-still-pinned",
         field(original, second, stage_end, target_meta_addr, target_meta,
               target_meta + (1 << 21)),
         "real mm_free did not retain sole complete PROCESS owner"),
        ("sole-target-has-foreign-owner",
         field(original, second, stage_end, target_meta_addr, target_meta,
               target_meta + 1),
         "real mm_free did not retain sole complete PROCESS owner"),
        ("failed-reply-not-injected",
         field(original, "FORGED_FAILED_REPLY", "END_FORGED_REPLY", 1,
               0o777777777773, 0),
         "source-free AC1 did not carry injected MM_ERR_BUSY"),
        ("lost-reply-caused-false-rejection",
         field(original, "ORIGINAL_RECOVERED_FULL_RETURN", "STAGE_RESTORED",
               1, 0, 0o777777777773),
         "original v1839 falsely refused successfully freed source"),
        ("published-slot3-still-TRANSITION",
         field(original, "ORIGINAL_RECOVERED_FULL_RETURN", "STAGE_RESTORED",
               p3, published[p3], published[p3] | (1 << 16)),
         "physically recovered slot3 not RESIDENT or still TRANSITION"),
    ]
    for label, forged, diagnostic in mutants:
        trace.write_text(forged, encoding="ascii")
        try:
            result = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-source-free-reply-physical-v1893/"
                    "verify-v1893.py"), str(kit), str(build), str(work)],
                capture_output=True, text=True)
        finally:
            trace.write_text(original, encoding="ascii")
        if result.returncode == 0 or diagnostic not in result.stderr:
            raise ValueError("v1893 forged %s not rejected at intended check: %s"
                             % (label, result.stderr.strip()))
        print("PASS v1893: physical %s negative trace rejected" % label)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1893.py kit build evidence")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1893 negative physical free reply oracle: " + str(exc))

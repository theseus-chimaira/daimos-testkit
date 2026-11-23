#!/usr/bin/env python3
"""Reject four forged original physical quarantined process-table words."""

from pathlib import Path
import re
import subprocess
import sys


def change(trace, start, stop, address, old, new):
    first = "V1891_%s\n" % start
    last = "V1891_%s\n" % stop
    if trace.count(first) != 1 or trace.count(last) != 1:
        raise ValueError("missing original physical process evidence markers")
    left, rest = trace.split(first, 1)
    body, right = rest.split(last, 1)
    a = "%o:\t%012o" % (address, old)
    b = "%o:\t%012o" % (address, new)
    if body.count(a) != 1:
        raise ValueError("physical process mutation word is not unique")
    return left + first + body.replace(a, b, 1) + last + right


def run(kit, build, work):
    original_path = work / "physical.clean"
    original = original_path.read_text(encoding="ascii")
    expected = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-process-v1891.txt").read_text(encoding="ascii")))
    core = {}
    for line in (build / "kcore.map").read_text(encoding="ascii").splitlines():
        fields = line.split()
        if len(fields) == 2 and re.fullmatch("[0-7]+", fields[1]):
            core[fields[0]] = int(fields[1], 8)
    begin, end = "ORIGINAL_PROCESS_SLOTS", "END_PROCESS_SLOTS"
    piece = original.split("V1891_%s\n" % begin, 1)[1].split(
        "V1891_%s\n" % end, 1)[0]
    words = dict((int(addr, 8), int(value, 8)) for addr, value in re.findall(
        r"(?m)^([0-7]+):\s*([0-7]{12})$", piece))
    slot3 = expected["physical_slot3"]
    slot4 = expected["physical_table"] + 4 * 3
    v3 = words[slot3]
    vm3 = words[slot3 + 1]
    v4 = words[slot4]
    if not v3 & (1 << 16) or v4 & (1 << 16) or vm3 & 0o777777:
        raise ValueError("original physical source process state not accepted")
    cases = (
        ("lost-slot3-TRANSITION",
         change(original, begin, end, slot3, v3, v3 & ~(1 << 16)),
         "original physical slot3 TRANSITION bit missing"),
        ("slot3-false-VM-publication",
         change(original, begin, end, slot3 + 1, vm3, vm3 | 1),
         "original physical slot3 unexpectedly published runnable APR"),
        ("healthy-peer-false-TRANSITION",
         change(original, begin, end, slot4, v4, v4 | (1 << 16)),
         "healthy physical bystander acquired TRANSITION"),
        ("wrong-process-table-pointer",
         change(original, "ORIGINAL_PROCESS_PTR", "END_PROCESS_PTR",
                core["proc_table"], expected["physical_table"], 0),
         "physical process-table pointer changed after the clock"),
    )
    for label, mutant, diagnostic in cases:
        original_path.write_text(mutant, encoding="ascii")
        try:
            result = subprocess.run([sys.executable,
                str(kit / "tests/validation/pure-k05-physical-overpin-v1890/"
                    "verify-process-v1891.py"), str(kit), str(build), str(work)],
                capture_output=True, text=True)
        finally:
            original_path.write_text(original, encoding="ascii")
        if result.returncode == 0 or diagnostic not in result.stderr:
            raise ValueError("physical process mutant not rejected at intended "
                             "oracle: %s (%s)" % (label, result.stderr.strip()))
        print("PASS v1891: original physical %s mutation rejected" % label)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-process-v1891.py kit build work")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (KeyError, OSError, ValueError, AssertionError) as exc:
        raise SystemExit("FAIL v1891 negative physical quarantine: " + str(exc))

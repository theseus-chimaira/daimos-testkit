#!/usr/bin/env python3
"""Reject a forged clock opcode and a fake unpinned owner in PI6 trace."""

from pathlib import Path
import re
import subprocess
import sys


def section(data, start, end):
    if data.count(start) != 1 or data.count(end) != 1:
        raise ValueError("missing original physical PI6 markers")
    prefix, rest = data.split(start, 1)
    middle, suffix = rest.split(end, 1)
    return prefix, middle, suffix


def verify(kit, build, work):
    path = work / "physical.clean"
    original = path.read_text(encoding="ascii")
    expect = dict((name, int(value, 8)) for name, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work / "expected-pi6-v1847.txt").read_text(encoding="ascii")))
    prefix, body, suffix = section(original,
                                  "V1847_ORIGINAL_PI6_CLOCK\n",
                                  "V1847_STAGE_PI6_POSTFAIL\n")
    addr, code = expect["pi6_pc"], expect["pi6_opcode"]
    old = "%o:\t%012o" % (addr, code)
    new = "%o:\t%012o" % (addr, code ^ 1)
    if body.count(old) != 1:
        raise ValueError("no original physical PI6 opcode to corrupt")
    wrong_pi6 = prefix + "V1847_ORIGINAL_PI6_CLOCK\n" + \
        body.replace(old, new, 1) + "V1847_STAGE_PI6_POSTFAIL\n" + suffix

    prefix, body, suffix = section(original,
                                  "V1847_STAGE_PI6_POSTFAIL\n",
                                  "V1847_END_PI6_POSTFAIL\n")
    core = (build / "kcore.map").read_text(encoding="ascii")
    extent = re.search(r"(?m)^mm_extents\s+([0-7]+)$", core)
    count = re.search(r"(?m)^mm_extent_count\s+([0-7]+)$", core)
    if not extent or not count:
        raise ValueError("source-linked original MM map unavailable")
    origin, naddr = int(extent[1], 8), int(count[1], 8)
    records = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^([0-7]+):\s*([0-7]{12})$", body)}
    pin_addr = None
    for i in range(records[naddr]):
        addr = origin + 2 * i + 1
        meta = records[addr]
        if (meta >> 18) & 7 == 4 and (meta & 0o777777) == 3:
            pin_addr = addr
            break
    if pin_addr is None:
        raise ValueError("no original PACKED source metadata to corrupt")
    pin = records[pin_addr]
    if (pin >> 21) & 255:
        raise ValueError("original PACKED source was already pinned")
    before = "%o:\t%012o" % (pin_addr, pin)
    after = "%o:\t%012o" % (pin_addr, pin | (1 << 21))
    if body.count(before) != 1:
        raise ValueError("original MM owner record ambiguous")
    wrong_pin = prefix + "V1847_STAGE_PI6_POSTFAIL\n" + \
        body.replace(before, after, 1) + "V1847_END_PI6_POSTFAIL\n" + suffix

    for label, modified, exact in (
        ("PI6-instruction", wrong_pi6, "physical PI6 instruction differs"),
        ("PACKED-pin", wrong_pin, "PI6 entry changed a retained physical MM owner")):
        path.write_text(modified, encoding="ascii")
        try:
            proc = subprocess.run([sys.executable,
                str(kit / "tests/validation/pure-k05-postfault-pi6-v1847/"
                          "verify-v1847.py"), str(kit), str(build), str(work)],
                capture_output=True, text=True)
        finally:
            path.write_text(original, encoding="ascii")
        if proc.returncode == 0 or exact not in proc.stderr:
            raise ValueError("mutant not rejected by expected source oracle: " + label)
        print("PASS v1847: forged original %s rejected" % label)


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: negative-v1847.py kit build original-trace")
    try:
        verify(*(Path(x) for x in argv[1:]))
    except (AssertionError, ValueError, OSError, KeyError) as e:
        raise SystemExit("FAIL v1847 negative PI6 test: " + str(e))


if __name__ == "__main__":
    main(sys.argv)

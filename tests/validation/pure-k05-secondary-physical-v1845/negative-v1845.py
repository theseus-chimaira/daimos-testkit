#!/usr/bin/env python3
"""Reject forged original MM pin and loader result in physical transcript."""

from pathlib import Path
import re
import subprocess
import sys


def stage(trace, first, last):
    assert trace.count(first) == trace.count(last) == 1
    prefix, rest = trace.split(first, 1)
    body, suffix = rest.split(last, 1)
    return prefix, body, suffix


def main(argv):
    if len(argv) != 5:
        raise SystemExit("usage: negative-v1845.py verifier testkit build evidence")
    verifier, kit, build, work = argv[1], Path(argv[2]), Path(argv[3]), Path(argv[4])
    original = (work / "physical.clean").read_text(encoding="ascii")
    prefix, body, suffix = stage(original, "V1845_STAGE_ROLLED_BACK\n",
                                 "V1845_END_ROLLED_BACK\n")
    # Retained PACKED owners must have zero pins; corrupt one original
    # physical MM descriptor by setting its live pin bit.
    from runpy import run_path
    symbols = run_path(str(kit / "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))["symbols"]
    core = symbols((build / "kcore.map").read_text(encoding="ascii"))
    records = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", body)}
    pin_addr = None
    for i in range(records[core["mm_extent_count"]]):
        addr = core["mm_extents"] + 2 * i + 1
        meta = records[addr]
        if ((meta >> 18) & 7) == 4 and (meta & 0o777777) in range(3, 7):
            pin_addr = addr
            break
    assert pin_addr is not None
    original_word = records[pin_addr]
    assert (original_word >> 21) & 255 == 0
    before = "%o:\t%012o" % (pin_addr, original_word)
    after = "%o:\t%012o" % (pin_addr, original_word | (1 << 21))
    assert body.count(before) == 1
    corruptions = {
        "pinned-source": prefix + "V1845_STAGE_ROLLED_BACK\n" +
            body.replace(before, after, 1) +
            "V1845_END_ROLLED_BACK\n" + suffix,
    }
    prefix, body, suffix = stage(original, "V1845_FAILED_FULL_RETURN\n",
                                 "V1845_STAGE_ROLLED_BACK\n")
    failure = re.sub(r"(?m)^(1:\s*)777777777774(\s*)$",
                     r"\g<1>000000000000\g<2>", body, count=1)
    assert failure != body
    corruptions["forged-success"] = (prefix +
        "V1845_FAILED_FULL_RETURN\n" + failure +
        "V1845_STAGE_ROLLED_BACK\n" + suffix)

    original_path = work / "physical.clean"
    for name, corrupted in corruptions.items():
        original_path.write_text(corrupted, encoding="ascii")
        try:
            result = subprocess.run([sys.executable, verifier, str(kit),
                                     str(build), str(work)], capture_output=True,
                                    text=True)
        finally:
            original_path.write_text(original, encoding="ascii")
        if result.returncode == 0 or not result.stderr.startswith(
                "FAIL v1845 physical K05 FULL source loss:"):
            raise ValueError("v1845 oracle accepted " + name)
        print("PASS v1845: physical %s transcript mutation rejected" % name)


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (AssertionError, ValueError, OSError, KeyError) as exc:
        raise SystemExit("FAIL v1845 negative physical oracle: " + str(exc))

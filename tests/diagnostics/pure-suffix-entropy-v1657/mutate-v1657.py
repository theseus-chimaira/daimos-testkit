#!/usr/bin/env python3
"""Create false/incomplete physical suffix witnesses for the real auditor."""

from pathlib import Path
import re
import sys


def mutate(path, out):
    data = Path(path).read_text(encoding="ascii")
    prefix, rest = data.split("V1657_BEGIN_SLOT_2\n", 1)
    body, suffix = rest.split("V1657_END_SLOT_2\n", 1)
    pattern = r"(?m)^([0-7]{1,7}:\s*)([0-7]{12})(\s*)$"
    hits = list(re.finditer(pattern, body))
    assert len(hits) == 3456
    first = hits[0]
    old = first.group(0)
    changed = "%s%012o%s" % (first.group(1),
                               int(first.group(2), 8) ^ 1,
                               first.group(3))
    assert changed != old
    altered = body[:first.start()] + changed + body[first.end():]
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    head = prefix + "V1657_BEGIN_SLOT_2\n"
    tail = "V1657_END_SLOT_2\n" + suffix
    (out / "wrong-word-v1657.trace").write_text(
        head + altered + tail, encoding="ascii")
    missing = body[:first.start()] + body[first.end():]
    (out / "missing-word-v1657.trace").write_text(
        head + missing + tail, encoding="ascii")
    (out / "missing-halt-v1657.trace").write_text(
        data.replace("HALT instruction, PC: 000000",
                     "HALT instruction, PC: 000001", 1),
        encoding="ascii")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: mutate-v1657.py original.trace outdir")
    mutate(*sys.argv[1:])

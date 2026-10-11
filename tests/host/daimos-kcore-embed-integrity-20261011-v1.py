#!/usr/bin/env python3
"""Verify that the boot stream embeds the intended KCORE words verbatim.

Usage: script KCORE.STREAM KINIT.WORDS KINIT.MAP
All addresses in map and image files are octal PDP-10 word values.
This deliberately checks the *final boot image*, not just the DXR link file.
"""
import pathlib
import sys


def words(path):
    lines = pathlib.Path(path).read_text(encoding="ascii").splitlines()
    if len(lines) < 3 or any(not s or any(c not in "01234567" for c in s)
                             for s in lines):
        raise ValueError(f"invalid octal word stream: {path}")
    return lines[2:]


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: check.py KCORE.STREAM KINIT.WORDS KINIT.MAP")
    kcore = words(sys.argv[1])
    kinit = words(sys.argv[2])
    symbols = {}
    for line in pathlib.Path(sys.argv[3]).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and all(ch in "01234567" for ch in fields[1]):
            symbols[fields[0]] = int(fields[1], 8)
    start = symbols["__kcore_load_begin"] - 0o30000
    end = symbols["__kcore_load_end"] - 0o30000
    if start < 0 or end != start + len(kcore) or end > len(kinit):
        raise ValueError("KCORE load extent disagrees with stream length")
    for index, (expected, actual) in enumerate(zip(kcore, kinit[start:end])):
        if expected != actual:
            raise ValueError(f"KCORE mismatch at logical {index + 0o60:06o}: "
                             f"{expected} != {actual}")
    print(f"PASS: {len(kcore)} KCORE words agree with final KINIT boot image")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Verify production KCC MAKE main-frame savings against v1813 source."""
import re
import subprocess
import sys


def frame(path):
    text = open(path, encoding="ascii").read()
    main = re.search(r"(?m)^main:\s*\n((?:[^\n]*\n){1,24})", text)
    if not main:
        raise ValueError("main label not found: " + path)
    match = re.search(r"(?i)\bADD\s+17,\[(0[0-7]+),,\1\]", main.group(1))
    if not match:
        raise ValueError("main frame adjustment not found: " + path)
    return int(match.group(1), 8)


def sections(path, objdump):
    out = subprocess.check_output([objdump, path], text=True)
    m = re.search(r"^sections: text=(\d+) data=(\d+) bss=(\d+)",
                  out, re.MULTILINE)
    if not m:
        raise ValueError("DOBJ section header not found: " + path)
    return tuple(map(int, m.groups()))


def main(argv):
    if len(argv) != 6:
        raise SystemExit("usage: check-make-frame-v1814.py "
                         "OLD.S NEW.S OLD.DOBJ NEW.DOBJ OBJDUMP")
    old_frame = frame(argv[1])
    new_frame = frame(argv[2])
    old_sections = sections(argv[3], argv[5])
    new_sections = sections(argv[4], argv[5])
    print("v1814 KCC MAKE frames: old=%o (%d) new=%o (%d) saved=%d" %
          (old_frame, old_frame, new_frame, new_frame,
           old_frame - new_frame))
    print("v1814 KCC MAKE object TEXT/BSS: old=%d/%d new=%d/%d" %
          (old_sections[0], old_sections[2],
           new_sections[0], new_sections[2]))
    if old_frame - new_frame < 400:
        raise SystemExit("FAIL v1814: insufficient native MAKE stack savings")
    if new_sections[2] > old_sections[2]:
        raise SystemExit("FAIL v1814: native MAKE BSS grew")
    print("PASS v1814: source-linked MAKE stack frame reduced >=400 words")


if __name__ == "__main__":
    main(sys.argv)

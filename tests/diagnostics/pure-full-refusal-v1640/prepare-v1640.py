#!/usr/bin/env python3
"""Derive a compressed-first 48K FULL-refusal guest from v1638.

Slot 2 uses the original compressed PURE DXR, and slot 3 uses
the original plain PURE DXR. This permits real NO-MEMORY FULL
refusal before slot 3 can free an APR using in-place restoration.
All user PIPE, writable-data, exact WAIT and EXIT tests remain.
"""

from pathlib import Path
import runpy
import sys


def generate(original):
    here = Path(__file__).resolve().parent.parent
    p1638 = runpy.run_path(str(here /
                           "pure-full-restore-v1638/prepare-v1638.py"))
    p1637 = runpy.run_path(str(here /
                           "pure-cache-pressure-v1637/prepare-v1637.py"))
    p1636 = runpy.run_path(str(here /
                           "pure-cache-low-v1636/prepare-v1636.py"))
    full = p1638["generate"](original, lambda s: p1637["generate"](
        s, p1636["generate"]))
    old = "pid[i] = p14_spawn(rd, i != 0U);"
    new = "pid[i] = p14_spawn(rd, i != 1U);"
    assert full.count(old) == 1
    return full.replace(old, new, 1)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1640.py original.c output.c")
    result = generate(Path(sys.argv[1]).read_text(encoding="ascii"))
    Path(sys.argv[2]).write_text(result, encoding="ascii")
    print("v1640: compressed slot2, plain slot3, four compressed successors")


if __name__ == "__main__":
    main()

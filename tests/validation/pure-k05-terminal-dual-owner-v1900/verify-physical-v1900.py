#!/usr/bin/env python3
"""Audit 48K physical PDP6 KCORE immutable with new terminal-only PURE."""

from pathlib import Path
import hashlib
import runpy
import sys

KCORE_SHA = "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b"
PURE_SHA = "09bcb71e4cbb172222f6389153c27293353fdaf6d3210eeef4630ed06de934f2"


def verify(kit, build, work):
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != KCORE_SHA:
        raise ValueError("fixed original KCORE grew or changed unexpectedly")
    if hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != PURE_SHA:
        raise ValueError("not exact v1900 updated terminal PURE MRES")
    terminal = (build / "pure-terminal-v1666.s").read_text(encoding="ascii")
    for part in ("ppure_detach_target_v1900:",
                 "camle   4,mm_extent_capacity",
                 "ppure_detach_postfree_scan_v1900:"):
        if terminal.count(part) != 1:
            raise ValueError("source-linked terminal guards absent")
    original = runpy.run_path(str(kit / "tests/validation/"
                        "pure-k05-persistent-source-pin-v1895/verify-v1895.py"))
    original["read"](kit, build, work, PURE_SHA)
    print("PASS v1900: original 48K installed PURE terminal + genuine KCORE -5 fault")
    print("v1900: retained exact two owners, parent HB*2, advancing original PCLK")
    print("NOT PROVEN: full physical terminal kill/EXIT, only the original native finalizer")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-physical-v1900.py kit original-build physical-work")
    try:
        verify(*(Path(x) for x in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as e:
        raise SystemExit("FAIL v1900 original PDP6 physical terminal build: " + str(e))

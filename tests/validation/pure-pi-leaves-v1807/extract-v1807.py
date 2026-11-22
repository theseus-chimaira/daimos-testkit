#!/usr/bin/env python3
"""Extract the production PDP-6 PI save/disable/restore leaf pair."""

from pathlib import Path
import sys


def main():
    if len(sys.argv) != 3:
        raise ValueError("usage: extract-v1807.py DAIMOS OUTPUT")
    kernel = Path(sys.argv[1]) / "system/kernel"
    output = Path(sys.argv[2])
    source = (kernel / "core/kcore_pi_pdp6.s").read_text(encoding="ascii")
    start = "mach_pi_disable:\n"
    end = "        popj 017,\n"
    if source.count(start) != 1:
        raise ValueError("production PI disable anchor drifted")
    tail = source.split(start, 1)[1]
    if tail.count("mach_pi_restore:\n") != 1:
        raise ValueError("production PI restore anchor drifted")
    disable, restore = tail.split("mach_pi_restore:\n", 1)
    if end not in disable or end not in restore:
        raise ValueError("production PI return tail drifted")
    # Only two real production functions, not the rest of the permanent
    # PI dispatcher (which owns shared scheduler symbols in these fixtures).
    disable = disable.split(end, 1)[0] + end
    restore = restore.split(end, 1)[0] + end
    if "coni 0004,1" not in disable or "cono 0004,000400" not in disable:
        raise ValueError("production PI disable instruction drifted")
    if "cono 0004,000200" not in restore:
        raise ValueError("production PI restore instruction drifted")
    output.write_text(
        ".text\n.globl mach_pi_disable\n.globl mach_pi_restore\n"
        + start + disable + "mach_pi_restore:\n" + restore,
        encoding="ascii")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1807 source PI extraction: " + str(exc))

#!/usr/bin/env python3
"""Extend source-linked v1890 physical pin2 test with real proc-table bits."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def run(kit, build, probe, old, accepted, out, dxrcheck):
    base = runpy.run_path(str(kit / "tests/validation/"
                 "pure-k05-physical-overpin-v1890/prepare-v1890.py"))
    base["make"](kit, build, probe, old, out, dxrcheck)
    previous = accepted.read_text(encoding="ascii")
    if hashlib.sha256(previous.encode("ascii")).hexdigest() != \
            "fa522cdbd0c1dfa8c429ba551d12db84d4671784928204f729c73eb8a0bb8b1e":
        raise ValueError("v1890 original physical source trace changed")
    core = runpy.run_path(str(kit / "tests/validation/"
                 "pure-k05-secondary-physical-v1845/prepare-v1845.py"))[
                     "symbols"](build / "kcore.map")
    section = previous.split("V1890_REAL_CLOCK_AFTER_FAILURE\n", 1)[1].split(
        "V1890_STAGE_CLOCK_LATER\n", 1)[0]
    physical = re.findall(r"(?m)^%o:\s*([0-7]{12})$" % core["proc_table"],
                          section)
    if len(physical) != 1:
        raise ValueError("original physical v1890 process pointer absent")
    ptr = int(physical[0], 8)
    if not 0o40000 <= ptr <= 0o120000 or ptr + 6 * 3 + 2 > 0o140000:
        raise ValueError("invalid actual original process-table location")
    ini = (out / "physical.ini").read_text(encoding="ascii")
    marker = "echo V1890_END_CLOCK_LATER\nexit\n"
    if ini.count(marker) != 1:
        raise ValueError("source-linked v1890 postfault clock anchor drift")
    suffix = ("echo V1890_END_CLOCK_LATER\n" +
              "echo V1891_ORIGINAL_PROCESS_PTR\n" +
              "examine %06o\n" % core["proc_table"] +
              "echo V1891_END_PROCESS_PTR\n" +
              "echo V1891_ORIGINAL_PROCESS_SLOTS\n" +
              "examine %06o-%06o\n" % (ptr, ptr + 6 * 3 + 2) +
              "echo V1891_END_PROCESS_SLOTS\nexit\n")
    (out / "physical.ini").write_text(ini.replace(marker, suffix, 1),
                                       encoding="ascii")
    (out / "expected-process-v1891.txt").write_text(
        "physical_table %06o\nphysical_slot3 %06o\n" %
        (ptr, ptr + 3 * 3), encoding="ascii")
    print("v1891: source-matched original runtime proc_table=%06o, slot3=%06o"
          % (ptr, ptr + 3 * 3))


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-process-v1891.py kit build probe v1848work v1890trace out dxrcheck")
    run(*(Path(a) for a in sys.argv[1:]))

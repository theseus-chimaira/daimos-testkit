#!/usr/bin/env python3
"""Instrument original source-linked physical FULL then two live HB events."""

from pathlib import Path
import re
import runpy
import sys


def prepare(kit, build, probe, prior, previous, out, dxrcheck):
    init = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if init.count("(void)p14_char('H');") != 1 or \
            init.count("(void)p14_char('B');") != 1 or \
            init.count("#define P14_CHILDREN         5U") != 1:
        raise ValueError("v1892 must boot exactly one test-only parent heartbeat")
    if init.count("dsys_close(wr)") != 1 or \
            init.index("(void)p14_char('L');") > init.index(
                "(void)p14_char('H');"):
        raise ValueError("v1892 original BRK/PIPE release is not retained")
    parent = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-physical-overpin-v1890/prepare-process-v1891.py"))
    parent["run"](kit, build, probe, prior, previous, out, dxrcheck)
    module = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = module["symbols"](build / "kcore.map")
    ini = (out / "physical.ini").read_text(encoding="ascii")
    tail = "echo V1891_END_PROCESS_SLOTS\nexit\n"
    if ini.count(tail) != 1:
        raise ValueError("missing original source-linked process-table boundary")
    exp = (out / "expected-process-v1891.txt").read_text(encoding="ascii")
    proc = re.findall(r"(?m)^physical_table\s+([0-7]+)$", exp)
    if len(proc) != 1:
        raise ValueError("missing actual physical process table address")
    ptr = int(proc[0], 8)

    def snapshot(label):
        original = module["snapshot"](core, label).replace(
            "V1845_", "V1892_")
        end = "echo V1892_END_%s\n" % label
        if not original.endswith(end):
            raise ValueError("original physical MM snapshot contract changed")
        result = (original[:-len(end)] +
                  "examine %06o\n" % core["proc_table"] +
                  "examine %06o-%06o\n" % (ptr, ptr + 6 * 3 + 2) +
                  "examine %06o\n" % core["proc_timer_clock"] + end)
        return result + "echo V1892_END_STAGE_%s\n" % label

    extension = ("echo V1891_END_PROCESS_SLOTS\n" +
                 "echo V1892_OBSERVED_PARENT_READY\n" +
                 "nobreak\n" +
                 'expect "HB"\ncont\n' +
                 "echo V1892_ACTUAL_USER_HEARTBEAT_1\n" +
                 snapshot("HEARTBEAT_1") +
                 'expect "HB"\ncont\n' +
                 "echo V1892_ACTUAL_USER_HEARTBEAT_2\n" +
                 snapshot("HEARTBEAT_2") +
                 "exit\n")
    if extension.count('expect "HB"\ncont\n') != 2:
        raise ValueError("v1892 two physical user-mode markers are required")
    (out / "physical.ini").write_text(ini.replace(tail, extension, 1),
                                      encoding="ascii")
    print("v1892: original pinned FULL -> pin2 -> -5 -> PI6 -> "
          "physical process quarantine -> 2 new resident parent HB markers")


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1892.py kit build probe v1848work v1890trace work dxrcheck")
    prepare(*(Path(a) for a in sys.argv[1:]))

#!/usr/bin/env python3
"""Audit actual 48K PDP-6 slot3 TRANSITION quarantine and peers."""

from pathlib import Path
import re
import runpy
import sys


def process_section(trace, first, last):
    start = "V1891_%s\n" % first
    end = "V1891_%s\n" % last
    if trace.count(start) != 1 or trace.count(end) != 1:
        raise ValueError("physical trace missing stage " + first)
    return trace.split(start, 1)[1].split(end, 1)[0]


def run(kit, build, work):
    oracle = runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-physical-overpin-v1890/verify-v1890.py"))
    oracle["read"](kit, build, work)
    trace = (work / "physical.clean").read_text(encoding="ascii")
    symbols = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))[
                        "symbols"](build / "kcore.map")
    expected = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-process-v1891.txt").read_text(encoding="ascii")))
    names = ["V1890_END_CLOCK_LATER\n",
             "V1891_ORIGINAL_PROCESS_PTR\n", "V1891_END_PROCESS_PTR\n",
             "V1891_ORIGINAL_PROCESS_SLOTS\n",
             "V1891_END_PROCESS_SLOTS\n"]
    if any(trace.count(k) != 1 for k in names) or \
            [trace.index(k) for k in names] != sorted(trace.index(k) for k in names):
        raise ValueError("v1891 original process-table markers missing/out of order")
    clock = oracle["section"](trace, "REAL_CLOCK_AFTER_FAILURE",
                               "STAGE_CLOCK_LATER")
    pointer = oracle["address_word"](clock, symbols["proc_table"])
    if pointer != expected["physical_table"] or \
            oracle["address_word"](process_section(
                trace, "ORIGINAL_PROCESS_PTR", "END_PROCESS_PTR"),
                symbols["proc_table"]) != pointer:
        raise ValueError("physical process-table pointer changed after the clock")
    body = process_section(trace, "ORIGINAL_PROCESS_SLOTS",
                           "END_PROCESS_SLOTS")
    proc = lambda slot: [oracle["address_word"](body, pointer + 3 * slot + i)
                         for i in range(3)]
    p3 = proc(3)
    if not (p3[0] & (1 << 16)):
        raise ValueError("original physical slot3 TRANSITION bit missing")
    if p3[1] & 0o777777:
        raise ValueError("original physical slot3 unexpectedly published runnable APR")
    if ((p3[2] >> 33) & 7) != 2:
        raise ValueError("original physical slot3 scheduler record changed")
    for slot in (4, 5, 6):
        p = proc(slot)
        if p[0] & (1 << 16):
            raise ValueError("healthy physical bystander acquired TRANSITION")
        if p[1] & 0o777777 or ((p[2] >> 33) & 7) != 2:
            raise ValueError("healthy physical bystander state/VM changed")
    if ((proc(1)[2] >> 33) & 7) != 3:
        raise ValueError("physical parent no longer in original WAIT sleep")
    print("PASS v1891: original 48K slot3 physically TRANSITION-held, VM base 0")
    print("v1891: original slots 4..6 remain distinct nontransition SRUN peers")
    print("NOT PROVEN: any bystander user-level EXIT/WAIT after the held error")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-process-v1891.py kit build evidence")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1891 actual physical process quarantine: " + str(exc))

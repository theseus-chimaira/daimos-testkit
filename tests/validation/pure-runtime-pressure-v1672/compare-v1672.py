#!/usr/bin/env python3
"""Compare native 48K/64K process MM lifecycle on general/strict TSFS."""

import json
import sys
from pathlib import Path


def load(path, core):
    report = json.loads(Path(path).read_text(encoding="ascii"))
    if report["core_kwords"] != core:
        raise ValueError("incorrect physical core in process report")
    expected = 4 if core == 48 else 7
    if report["children_requested"] != expected:
        raise ValueError("unexpected number of RUN children")
    checkpoints = ("baseline", "pressure", "reaped")
    if len(report["samples"]) != 3:
        raise ValueError("not exactly three native pressure samples")
    for i, name in enumerate(checkpoints):
        state = report[name]
        if report["samples"][i] != state:
            raise ValueError("forged/reordered MM checkpoint " + name)
        if state["free_words"] + state["mm_allocated_words"] > \
                state["physical_core_words"] or \
                state["physical_core_words"] != core * 1024 or \
                state["largest_free_words"] > state["free_words"] or \
                state["managed_words"] != (state["free_words"] +
                                           state["mm_allocated_words"]):
            raise ValueError("impossible MM accounting in " + name)
        aprs = state["process_aprs"]
        if len(aprs) != state["process_apr_count"] or \
                len({apr["owner"] for apr in aprs}) != len(aprs) or \
                any(apr["pins"] != 0 or apr["words"] <= 0 for apr in aprs) or \
                sum(apr["words"] for apr in aprs) != \
                state["process_apr_words"]:
            raise ValueError("invalid physical process APR extent accounting")
    if [report[name]["process_apr_count"] for name in checkpoints] != \
            [1, 1 + expected, 1]:
        raise ValueError("real native RUN/WAIT process owners not conserved")
    if report["baseline"]["resident_words"] != \
            report["pressure"]["resident_words"] or \
            report["pressure"]["resident_words"] != \
            report["reaped"]["resident_words"]:
        raise ValueError("fixed resident words changed during workload")
    if report["pressure"]["free_words"] >= \
            report["baseline"]["free_words"] or \
            report["reaped"]["free_words"] <= \
            report["pressure"]["free_words"]:
        raise ValueError("physical pressure/recovery not demonstrated")
    if report["baseline"]["pinned_extents"] != \
            report["pressure"]["pinned_extents"] or \
            report["baseline"]["pinned_extents"] != \
            report["reaped"]["pinned_extents"]:
        raise ValueError("original baseline pins changed or leaked")
    for field in ("free_words", "largest_free_words",
                  "mm_allocated_words", "process_aprs", "by_type"):
        if report["baseline"][field] != report["reaped"][field]:
            raise ValueError("post-WAIT physical MM did not restore " + field)
    return report


def compare(g, s, core):
    if g["baseline"]["resident_words"] != \
            s["baseline"]["resident_words"]:
        raise ValueError("general/strict installed permanent MRES differs")
    for state in ("baseline", "pressure", "reaped"):
        gg = g[state]
        ss = s[state]
        if gg["process_apr_count"] != ss["process_apr_count"]:
            raise ValueError("general/strict actual APR owner mismatch")
        for field in ("free_words", "largest_free_words",
                      "mm_allocated_words", "process_aprs", "by_type",
                      "pinned_extents"):
            if gg[field] != ss[field]:
                raise ValueError("general/strict MM differs at %dK %s: %s" %
                                 (core, state, field))
        print("v1672 %dK %s: general free=%d largest=%d; "
              "strict free=%d largest=%d; APR owners=%d, pins=%d/%d" %
              (core, state, gg["free_words"],
               gg["largest_free_words"], ss["free_words"],
               ss["largest_free_words"], gg["process_apr_count"],
               gg["pinned_count"], ss["pinned_count"]))
    print("PASS v1672 %dK: real %d-child RUN, EXIT and WAIT APR ownership "
          "1 -> %d -> 1; no leaked MM pins" %
          (core, g["children_requested"],
           1 + g["children_requested"]))


def main(args):
    if len(args) != 5:
        raise ValueError("usage: compare-v1672.py general48 strict48 "
                         "general64 strict64")
    compare(load(args[1], 48), load(args[2], 48), 48)
    compare(load(args[3], 64), load(args[4], 64), 64)
    print("SCOPE: three physical stable RUN/WAIT checkpoints only; "
          "not all-time CPU micropeak or mode3 compression")


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit("FAIL v1672 paired native pressure: " + str(exc))

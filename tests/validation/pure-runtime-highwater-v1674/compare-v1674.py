#!/usr/bin/env python3
"""Compare independently replayed 48K general/strict MM write traces."""

import json
import sys
from pathlib import Path


def load(path):
    report = json.loads(Path(path).read_text(encoding="ascii"))
    if report["core_kwords"] != 48 or report["watches"] != 71 or \
            report["event_count"] < 25 or \
            report["committed_events"] < 10 or \
            report["baseline_free"] != 27441 or \
            report["pressure_free"] != 2794 or \
            report["reaped_free"] != 27441 or \
            report["max_event_nonfree"] != 49152-report["min_event_free"]:
        raise ValueError("invalid 48K physical write-watch report")
    if len(report["phases"]) != 2 or [x["phase"] for x in
           report["phases"]] != ["A-to-B", "B-to-C"]:
        raise ValueError("missing physical write-watch interval")
    if sum(p["observed"] for p in report["phases"]) != \
            report["event_count"]:
        raise ValueError("lost MM mutation events in summary")
    if sum(p["commits"] for p in report["phases"]) != \
            report["committed_events"]:
        raise ValueError("forged MM commit counter")
    if sum(p["resizes"] for p in report["phases"]) != \
            report["resize_events"] or \
            sum(p["staging_writes"] for p in report["phases"]) != \
            report["staging_writes"]:
        raise ValueError("forged MM write classification")
    if sum(len(p["stable"]) for p in report["phases"]) != \
            report["committed_events"] + report["resize_events"] or \
            report["committed_events"] + report["resize_events"] + \
            report["staging_writes"] != report["event_count"]:
        raise ValueError("MM trace omitted physical write classification")
    samples = [x for p in report["phases"] for x in p["stable"]]
    if min(x["free"] for x in samples) != report["min_event_free"] or \
            max(x["occupied_or_reserved"] for x in samples) != \
            report["max_event_nonfree"] or \
            sum(1 for x in samples if x["committed"]) != \
            report["committed_events"]:
        raise ValueError("forged MM high-water summary")
    return report


def run(args):
    if len(args) != 3:
        raise ValueError("usage: compare-v1674.py general.json strict.json")
    a, b = load(args[1]), load(args[2])
    for key in ("min_event_free", "max_event_nonfree", "watches",
                "baseline_free", "pressure_free", "reaped_free"):
        if a[key] != b[key]:
            raise ValueError("physical general/strict %s differ" % key)
    print("PASS v1674: GENERAL / STRICT original-MM physical write-watch "
          "min free %d, max nonfree %d, events %d/%d" %
          (a["min_event_free"], a["max_event_nonfree"],
           a["event_count"], b["event_count"]))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit("FAIL v1674 paired original-MM high-water: " + str(exc))

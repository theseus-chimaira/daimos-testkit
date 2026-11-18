#!/usr/bin/env python3
"""Compare two PDP-6 KINIT allocator event envelopes at 48K and 64K."""

import json
import sys
from pathlib import Path


def load(path, core):
    report = json.loads(Path(path).read_text(encoding="ascii"))
    if report["core_kwords"] != core:
        raise ValueError("mislabelled physical core trace")
    samples = report["samples"]
    if not samples or samples[0]["event"] != "mres_init" or \
            samples[-1]["event"] != "vm_enter_initial_user" or \
            len(samples) != report["event_count"]:
        raise ValueError("missing event start or terminal sample")
    core_words = core * 1024
    for index, sample in enumerate(samples):
        if sample["order"] != index or \
                sample["free"] + sample["occupied_or_reserved"] != core_words or \
                sample["allocated"] > sample["occupied_or_reserved"]:
            raise ValueError("invalid physical per-event conservation")
    if min(s["free"] for s in samples) != report["min_sampled_free"] or \
            max(s["occupied_or_reserved"] for s in samples) != \
            report["max_sampled_nonfree"]:
        raise ValueError("forged event high-water summary")
    if report["min_sampled_free"] != core_words - \
            report["max_sampled_nonfree"]:
        raise ValueError("sampled physical peak/free mismatch")
    if report["terminal"] != samples[-1]:
        raise ValueError("forged terminal MM snapshot")
    return report


def compare(g, s, core):
    image_delta = int(g["image_end_octal"], 8) - \
        int(s["image_end_octal"], 8)
    if image_delta <= 0:
        raise ValueError("no strict swapless image reduction")
    for field in ("allocated", "free", "by_type", "permanent_resident",
                  "extents", "largest_free"):
        if g["terminal"][field] != s["terminal"][field]:
            raise ValueError("%dK final VM entry MM differs: %s (%s/%s)" %
                             (core, field, g["terminal"][field],
                              s["terminal"][field]))
    delta = g["max_sampled_nonfree"] - s["max_sampled_nonfree"]
    if delta != image_delta:
        raise ValueError("%dK observed nonfree high-water delta %d "
                         "disagrees with linked image reduction %d" %
                         (core, delta, image_delta))
    if g["samples"][0]["event"] != g["high_water_event"] or \
            s["samples"][0]["event"] != s["high_water_event"] or \
            g["high_water_order"] != 0 or s["high_water_order"] != 0:
        raise ValueError("actual sampled peak moved from MM-ready start")
    print("PASS v1670 %dK: sampled peak nonfree general=%d strict=%d "
          "(-%d), terminal free both=%d, permanent low=%d" %
          (core, g["max_sampled_nonfree"], s["max_sampled_nonfree"],
           delta, g["terminal"]["free"],
           g["terminal"]["permanent_resident"]))
    print("  physical mutation entry events general=%d strict=%d; "
          "INIT user-entry extents=%d" %
          (g["event_count"], s["event_count"],
           g["terminal"]["extents"]))
    return delta


def main(argv):
    if len(argv) != 5:
        raise ValueError("usage: compare-v1670.py g48 s48 g64 s64")
    d48 = compare(load(argv[1], 48), load(argv[2], 48), 48)
    d64 = compare(load(argv[3], 64), load(argv[4], 64), 64)
    if d48 != d64:
        raise ValueError("memory size changed source-matched image delta")
    print("SCOPE: stable KINIT MM mutation entries through first "
          "vm_enter_initial_user; no all-instruction micropeak or runtime "
          "pressure claim.")


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit("FAIL v1670 paired physical peak: " + str(exc))

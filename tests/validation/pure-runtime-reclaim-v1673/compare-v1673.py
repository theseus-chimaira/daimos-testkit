#!/usr/bin/env python3
"""Compare physical 48K general/strict RAW PURE eviction and restoration."""

import json
import os
import sys
from pathlib import Path


PHASES = ("baseline", "pressure", "reaped")


def resident_bound():
    # Do not erase the historical source-specific RAM budget. The v1807
    # mainline K01-K04 merge has a different independently measured resident
    # low footprint; require an explicit, versioned integration profile.
    profile = os.environ.get("V1673_SOURCE_PROFILE_V1807", "historical")
    expected = {"historical": 17729, "integration": 18173}
    if profile not in expected:
        raise ValueError("unknown source-matched resident profile")
    return expected[profile]


def load(path):
    report = json.loads(Path(path).read_text(encoding="ascii"))
    expected_resident = resident_bound()
    if report["core_kwords"] != 48 or report["children_requested"] != 9:
        raise ValueError("v1673 requires physical 48K and nine real children")
    if len(report["samples"]) != 3 or any(
            report["samples"][i] != report[name]
            for i, name in enumerate(PHASES)):
        raise ValueError("missing, reordered or forged MM checkpoints")

    for name in PHASES:
        state = report[name]
        if state["physical_core_words"] != 49152 or \
                state["resident_words"] != expected_resident or \
                state["managed_words"] != (state["free_words"] +
                                           state["mm_allocated_words"]) or \
                state["largest_free_words"] > state["free_words"]:
            raise ValueError("impossible physical core/MM accounting: " + name)
        aprs = state["process_aprs"]
        packed = state["packed_aprs"]
        if len(aprs) != state["process_apr_count"] or \
                len(packed) != state["packed_apr_count"] or \
                len({x["owner"] for x in aprs + packed}) != \
                len(aprs) + len(packed) or \
                any(x["pins"] != 0 or x["words"] <= 0
                    for x in aprs + packed):
            raise ValueError("invalid APR/PACKED owner or pin in " + name)
        if report["native_meminfo"]["PROCESS-WORDS"][PHASES.index(name)] != \
                state["resident_process_words"]:
            raise ValueError("native MEMINFO must count resident, not RAW VM")

    base = report["baseline"]
    press = report["pressure"]
    done = report["reaped"]
    if [state["process_apr_count"] for state in (base, press, done)] != \
            [1, 1, 1] or \
            [state["packed_apr_count"] for state in (base, press, done)] != \
            [0, 9, 0]:
        raise ValueError("nine physical RAW PURE reclaims not observed")
    if press["process_high_slot"] >= press["process_capacity"] or \
            press["largest_free_words"] >= 2048 or \
            press["free_words"] < 2048:
        raise ValueError("pressure RUN did not refuse with free slot/gap")
    if [p["slot"] for p in press["process_states"]] != list(range(1, 11)) or \
            [p["storage_mode"] for p in press["process_states"]] != \
            [0] + [2] * 9 or \
            sum(p["vm_words"] - p["physical"]["words"]
                for p in press["process_states"][1:]) != 1152:
        raise ValueError("no exact nine-owner 128-word PURE release")
    if (base["pinned_extents"] != press["pinned_extents"] or
            base["pinned_extents"] != done["pinned_extents"]):
        raise ValueError("baseline pin changed or leaked under reclaim")
    for key in ("free_words", "largest_free_words", "mm_allocated_words",
                "process_aprs", "packed_aprs", "process_states", "by_type",
                "pinned_extents"):
        if base[key] != done[key]:
            raise ValueError("WAIT did not restore physical MM " + key)
    return report


def main(argv):
    if len(argv) != 3:
        raise ValueError("usage: compare-v1673.py general48.json strict48.json")
    general, strict = load(argv[1]), load(argv[2])
    for phase in PHASES:
        g, s = general[phase], strict[phase]
        for key in ("resident_words", "free_words", "largest_free_words",
                    "mm_allocated_words", "process_aprs", "packed_aprs",
                    "process_states", "by_type", "pinned_extents"):
            if g[key] != s[key]:
                raise ValueError("general/strict physical %s differed at %s" %
                                 (key, phase))
        print("v1673 48K %s: free %d, largest %d, APR %d, PACKED %d" %
              (phase, g["free_words"], g["largest_free_words"],
               g["process_apr_count"], g["packed_apr_count"]))
    print("PASS v1673 48K: nine native RAW PURE evictions, 1152 text words "
          "released, exact post-WAIT MM recovery, general/strict match")
    print("SCOPE: source-matched 48K physical stable CTY checkpoints; "
          "not 64K, mode3, or continuous instruction-level memory peak")


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (ValueError, OSError, KeyError, TypeError) as exc:
        raise SystemExit("FAIL v1673 paired physical RAW PURE: " + str(exc))

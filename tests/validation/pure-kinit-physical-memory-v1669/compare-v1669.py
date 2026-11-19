#!/usr/bin/env python3
"""Check paired live 48K/64K MM snapshots against linked KINIT deltas."""

import json
import sys
from pathlib import Path


def load(path, size):
    obj = json.loads(Path(path).read_text(encoding="ascii"))
    if obj["core_kwords"] != size:
        raise ValueError("mislabelled physical core snapshot")
    return obj


def compare(general, strict, size):
    for field in ("core_words", "descriptor_capacity",
                  "allocated_mm_words", "extent_count",
                  "resident_low_words", "owner_type_words"):
        if general[field] != strict[field]:
            raise ValueError("%dK general/strict differ in %s: %s vs %s" %
                             (size, field, general[field], strict[field]))

    image_delta = int(general["image_end_octal"], 8) - \
        int(strict["image_end_octal"], 8)
    late_delta = int(general["late_begin_octal"], 8) - \
        int(strict["late_begin_octal"], 8)
    actual_delta = strict["free_mm_words"] - general["free_mm_words"]
    reserved_delta = general["unmanaged_reserved_words"] - \
        strict["unmanaged_reserved_words"]
    largest_delta = strict["largest_free_words"] - \
        general["largest_free_words"]
    if image_delta <= 0 or late_delta <= 0 or \
            actual_delta != late_delta or reserved_delta != late_delta or \
            largest_delta != image_delta:
        raise ValueError("%dK: MM free/reserved/contiguous deltas "
                         "(%d/%d/%d) do not match actual late/image "
                         "linker displacement (%d/%d)" %
                         (size, actual_delta, reserved_delta,
                          largest_delta, late_delta, image_delta))
    if general["free_mm_words"] <= 0 or strict["free_mm_words"] <= 0:
        raise ValueError("no free managed core at KINIT handoff")

    print("PASS v1669 %dK: general %d free, strict %d free, "
          "+%d LIVE checkpoint free words (KINIT image -%d)" %
          (size, general["free_mm_words"], strict["free_mm_words"],
           actual_delta, image_delta))
    print("  identical live MM allocation %d, low resident %d, "
          "largest contiguous general/strict %d/%d (+%d)" %
          (general["allocated_mm_words"], general["resident_low_words"],
           general["largest_free_words"],
           strict["largest_free_words"], largest_delta))
    print("  pre-reclaim late KINIT text shift %d words; "
          "middle arena shrinks %d words" %
          (late_delta, image_delta - actual_delta))
    return (image_delta, actual_delta)


def main(args):
    if len(args) != 5:
        raise ValueError("usage: compare-v1669.py g48 s48 g64 s64")
    g48, s48 = load(args[1], 48), load(args[2], 48)
    g64, s64 = load(args[3], 64), load(args[4], 64)
    delta48 = compare(g48, s48, 48)
    delta64 = compare(g64, s64, 64)
    if delta48 != delta64:
        raise ValueError("physical memory size changed linker image delta")
    print("NOTE: snapshots are at kinit_late_start before source-image "
          "reclamation and INIT loading; they are NOT continuous peaks.")


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (OSError, ValueError, KeyError) as exc:
        raise SystemExit("FAIL v1669 source-matched physical MM: " + str(exc))

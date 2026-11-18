#!/usr/bin/env python3
"""Compare independently measured PDP-6 KINIT stack watermarks."""

import json
import sys
from pathlib import Path


def load(path, core):
    item = json.loads(Path(path).read_text(encoding="ascii"))
    if item["core_kwords"] != core or item["stack_reserve_words"] != 256:
        raise ValueError("wrong physical PDP-6 core or stack reserve")
    if not (0 < item["stored_highwater_offset"] < 256) or \
            item["physical_last_touched_offset"] != \
            item["stored_highwater_offset"] or \
            item["minimum_untouched_suffix_words"] != \
            255 - item["stored_highwater_offset"]:
        raise ValueError("inconsistent stored and physical stack proof")
    return item


def compare(general, strict, core):
    if general["low_resident_words"] != strict["low_resident_words"]:
        raise ValueError("%dK instrumented KCORE resident changed" % core)
    image_saved = int(general["image_end_octal"], 8) - \
        int(strict["image_end_octal"], 8)
    if image_saved <= 0:
        raise ValueError("%dK strict KINIT failed to shrink" % core)
    general_hwm = general["stored_highwater_offset"]
    strict_hwm = strict["stored_highwater_offset"]
    print("PASS v1671 %dK: general/strict stack highwater offsets "
          "%d/%d, reserve 256, untouched top %d/%d, "
          "instrumented KINIT shrink %d" %
          (core, general_hwm, strict_hwm,
           general["minimum_untouched_suffix_words"],
           strict["minimum_untouched_suffix_words"], image_saved))
    return image_saved


def main(argv):
    if len(argv) != 5:
        raise ValueError("usage: compare-v1671.py g48 s48 g64 s64")
    delta48 = compare(load(argv[1], 48), load(argv[2], 48), 48)
    delta64 = compare(load(argv[3], 64), load(argv[4], 64), 64)
    if delta48 != delta64:
        raise ValueError("physical core size shifted source-matched images")
    print("SCOPE: native diagnostic KINIT watermark, not production "
          "stack allocation or post-user process pressure.")


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit("FAIL v1671 stack comparison: " + str(exc))

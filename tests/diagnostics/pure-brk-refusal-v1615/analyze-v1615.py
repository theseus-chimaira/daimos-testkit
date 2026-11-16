#!/usr/bin/env python3
"""Read-only physical MM extent decoder for a halted PDP-6 SIMH trace.

All addresses and words are parsed in octal from actual SIMH examine
output, with symbol addresses obtained from the matching KCORE map.
The decoder never treats MEMINFO's unmapped PACKED processes as free.
"""
import re
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: analyze-v1615.py KCORE.map TRACE.clean")
    symbols = {}
    for line in Path(sys.argv[1]).read_text().splitlines():
        parts = line.split()
        if (len(parts) >= 2 and
                all(c in "01234567" for c in parts[1])):
            symbols[parts[0]] = int(parts[1], 8)
    needed = ("mm_arena_count", "mm_arenas", "mm_extent_count",
              "mm_extents", "proc_current_slot")
    if any(name not in symbols for name in needed):
        raise SystemExit("v1615: missing MM map symbols")

    words = {}
    text = Path(sys.argv[2]).read_text()
    for address, value in re.findall(
            r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", text):
        words[int(address, 8)] = int(value, 8)

    def get(address):
        if address not in words:
            raise ValueError("missing SIMH memory %06o" % address)
        return words[address]

    try:
        arena_count = get(symbols["mm_arena_count"])
        extent_count = get(symbols["mm_extent_count"])
        current = get(symbols["proc_current_slot"])
        if not (0 < arena_count <= 3 and 0 <= extent_count <= 136):
            raise ValueError("unreasonable MM descriptor counts")
        arenas = []
        for i in range(arena_count):
            w = get(symbols["mm_arenas"] + i)
            arenas.append((w & 0o777777, (w >> 18) & 0o777777))
        extents = []
        for i in range(extent_count):
            span = get(symbols["mm_extents"] + 2 * i)
            meta = get(symbols["mm_extents"] + 2 * i + 1)
            extents.append({
                "base": span & 0o777777,
                "words": (span >> 18) & 0o777777,
                "type": (meta >> 18) & 0o7,
                "pins": (meta >> 21) & 0o377,
                "owner": meta & 0o777777,
            })
    except ValueError as error:
        print("v1615: INCOMPLETE physical MM snapshot:", error)
        return 2

    names = {0: "FREE", 1: "PROCESS", 2: "MODULE",
             3: "DYNAMIC", 4: "PACKED"}
    print("v1615 MM: %d arenas, %d extents, current slot %o" %
          (arena_count, extent_count, current))
    total_packed = 0
    for i, e in enumerate(extents):
        print("  %2d  %06o..%06o words=%06o type=%-7s owner=%03o pin=%o" %
              (i, e["base"], e["base"] + e["words"],
               e["words"], names.get(e["type"], "INVALID"),
               e["owner"], e["pins"]))
        if e["type"] == 4:
            total_packed += e["words"]

    # This is an exact physical gap calculation for the captured instant,
    # NOT a claim about success after future MM movement or new allocations.
    best_aligned = 0
    for low, size in arenas:
        high = low + size
        inside = sorted((e for e in extents
                         if low <= e["base"] < high),
                        key=lambda e: e["base"])
        cursor = low
        print("  arena %06o..%06o size=%06o" % (low, high, size))
        for e in inside + [{"base": high, "words": 0}]:
            if e["base"] < cursor:
                raise SystemExit("v1615: OVERLAPPING physical MM owners")
            aligned = (cursor + 0o1777) & ~0o1777
            available = max(0, e["base"] - aligned)
            best_aligned = max(best_aligned, available)
            if e["base"] > cursor:
                print("    gap %06o..%06o raw=%06o aligned=%06o" %
                      (cursor, e["base"], e["base"] - cursor,
                       available))
            cursor = e["base"] + e["words"]
            if cursor > high:
                raise SystemExit("v1615: extent exceeds managed arena")
    print("v1615 MM: retained PACKED suffix total=%06o words" %
          total_packed)
    print("v1615 MM: largest currently aligned free run=%06o words" %
          best_aligned)
    print("v1615: this snapshot alone does not establish net RAM benefit")
    return 0


if __name__ == "__main__":
    sys.exit(main())

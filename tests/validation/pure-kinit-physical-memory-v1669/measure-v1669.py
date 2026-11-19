#!/usr/bin/env python3
"""Decode SIMH PDP-6 live MM state at the pre-reclaim KINIT handoff.

The SIMH executable breaks on the unmodified kinit_late_start entry.
Its examine results are real physical memory words, not a KINIT
source-size estimate or a synthetic allocator model.
"""

import json
import re
import sys
from pathlib import Path

HALF = (1 << 18) - 1
MAX_EXTENTS = 136


def one_symbol(path, name):
    text = Path(path).read_text(encoding="ascii")
    values = re.findall(r"^" + re.escape(name) + r"\s+([0-7]+)\s*$",
                        text, re.M)
    if len(values) != 1:
        raise ValueError("missing/duplicate map symbol " + name)
    return int(values[0], 8)


def collect_words(path):
    text = Path(path).read_text(encoding="ascii")
    words = {}
    for address, data in re.findall(r"^([0-7]{3,7}):\s+([0-7]{12})\s*$",
                                    text, re.M):
        addr = int(address, 8)
        if addr in words:
            raise ValueError("duplicate SIMH examine address " + address)
        words[addr] = int(data, 8)
    return text, words


def measured(mapfile, coremap, logfile, expected_core):
    late = one_symbol(mapfile, "kinit_late_start")
    late_begin = one_symbol(mapfile, "__kinit_late_begin")
    image_end = one_symbol(mapfile, "__kinit_image_end")
    core_count = one_symbol(coremap, "mm_core_words")
    arenas_base = one_symbol(coremap, "mm_arenas")
    arena_count = one_symbol(coremap, "mm_arena_count")
    extent_count = one_symbol(coremap, "mm_extent_count")
    extent_capacity = one_symbol(coremap, "mm_extent_capacity")
    extents_base = one_symbol(coremap, "mm_extents")
    resident_imm = one_symbol(coremap, "sys_resident_words_immediate")
    text, words = collect_words(logfile)

    if not re.search(r"Breakpoint, PC:\s+0*%o\b" % late, text):
        raise ValueError("guest did not stop at actual late KINIT")
    if not re.search(r"^MEM\s+%d K\s*$" % expected_core, text, re.M):
        raise ValueError("guest did not detect requested physical core")
    if not re.search(r"^PURE\s+LOADED\s*$", text, re.M):
        raise ValueError("PURE backend not installed before checkpoint")
    if re.search(r"^SWAP\s+FAIL\s*$", text, re.M):
        raise ValueError("unexpected SWAP fatal before checkpoint")

    def word(address):
        if address not in words:
            raise ValueError("missing physical word %o" % address)
        return words[address]

    core_words = word(core_count)
    if core_words != expected_core * 1024:
        raise ValueError("physical core word count mismatches CPU")
    capacity = word(extent_capacity)
    n_arenas = word(arena_count)
    n_extents = word(extent_count)
    if capacity != ((core_words >> 13) * 4 + 8):
        raise ValueError("MM descriptor capacity not actual core policy")
    if not (1 <= n_arenas <= 3) or not (0 <= n_extents <= capacity):
        raise ValueError("MM count/capacity outside physical limits")
    if capacity > MAX_EXTENTS:
        raise ValueError("MM capacity exceeds physical descriptor table")

    arenas = []
    for i in range(n_arenas):
        packed = word(arenas_base + i)
        size, base = (packed >> 18) & HALF, packed & HALF
        if not size or base + size > core_words:
            raise ValueError("MM arena out of actual installed core")
        if arenas and base < arenas[-1][1]:
            raise ValueError("overlapping/unsorted physical arenas")
        arenas.append((base, base + size))

    extents = []
    allocated = 0
    owners = {}
    for i in range(n_extents):
        span = word(extents_base + 2 * i)
        meta = word(extents_base + 2 * i + 1)
        size, base = (span >> 18) & HALF, span & HALF
        owner_type = (meta >> 18) & 7
        pins = (meta >> 21) & 255
        if not size or owner_type not in (1, 2, 3, 4):
            raise ValueError("invalid physical MM allocation descriptor")
        if not any(a <= base and base + size <= b for a, b in arenas):
            raise ValueError("MM allocation is outside managed arenas")
        if extents and base < extents[-1][1]:
            raise ValueError("overlapping/unsorted MM extent descriptors")
        extents.append((base, base + size, owner_type, pins))
        allocated += size
        key = str(owner_type)
        owners[key] = owners.get(key, 0) + size

    free_words = 0
    largest_free = 0
    for start, end in arenas:
        cursor = start
        for base, after, _, _ in extents:
            if base < start or base >= end:
                continue
            gap = base - cursor
            if gap < 0:
                raise ValueError("invalid arena gap")
            free_words += gap
            largest_free = max(largest_free, gap)
            cursor = after
        gap = end - cursor
        if gap < 0:
            raise ValueError("invalid trailing arena gap")
        free_words += gap
        largest_free = max(largest_free, gap)
    managed_words = sum(end - start for start, end in arenas)
    if managed_words != free_words + allocated:
        raise ValueError("physical MM accounting does not conserve words")
    if word(resident_imm) & HALF >= core_words:
        raise ValueError("invalid permanent resident immediate")

    return dict(core_kwords=expected_core, core_words=core_words,
                image_end_octal="%06o" % image_end,
                late_begin_octal="%06o" % late_begin,
                descriptor_capacity=capacity, arena_count=n_arenas,
                extent_count=n_extents, managed_words=managed_words,
                allocated_mm_words=allocated, owner_type_words=owners,
                free_mm_words=free_words, largest_free_words=largest_free,
                unmanaged_reserved_words=core_words - managed_words,
                occupied_or_reserved_words=core_words - free_words,
                resident_low_words=word(resident_imm) & HALF,
                arenas=[dict(base=a, end=b) for a, b in arenas],
                extents=[dict(base=a, end=b, kind=t, pins=p)
                         for a, b, t, p in extents])


def run(argv):
    if len(argv) != 6:
        raise ValueError("usage: measure-v1669.py kinit.map kcore.map "
                         "console.log core_kwords report.json")
    result = measured(argv[1], argv[2], argv[3], int(argv[4]))
    Path(argv[5]).write_text(json.dumps(result, indent=2, sort_keys=True)
                             + "\n", encoding="ascii")
    print("PHYSICAL v1669 %dK: free=%d allocated=%d "
          "reserved=%d largest=%d extents=%d" %
          (result["core_kwords"], result["free_mm_words"],
           result["allocated_mm_words"],
           result["unmanaged_reserved_words"],
           result["largest_free_words"], result["extent_count"]))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1669 physical MM proof: " + str(exc))

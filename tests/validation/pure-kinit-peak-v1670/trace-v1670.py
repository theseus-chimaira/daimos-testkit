#!/usr/bin/env python3
"""Prove physical allocator-event samples from an unchanged PDP-6 KINIT.

SIMH breakpoints sample every known KINIT MM mutation entry and the
final user-entry handoff. The reported high water is the largest
*stable sampled* nonfree total, not a claim about every instruction
inside an allocator transaction or the later running user processes.
"""

import json
import re
import sys
from pathlib import Path

HALF = (1 << 18) - 1
MAX_EXTENTS = 136
EVENT_NAMES = (
    "mres_init", "mm_extent_insert", "mm_boot_reserve", "mm_add_free",
    "mm_free", "mm_process_shrink_pinned", "mm_process_grow_pinned",
    "mm_compact", "vm_enter_initial_user",
)
GLOBALS = (
    "mm_core_words", "mm_extent_capacity", "mm_extent_count",
    "mm_arena_count", "sys_resident_words_immediate",
)


def symbol(paths, name):
    values = []
    for path in paths:
        source = Path(path).read_text(encoding="ascii")
        values.extend(int(v, 8) for v in re.findall(
            r"^" + re.escape(name) + r"\s+([0-7]+)\s*$", source, re.M))
    if not values or len(set(values)) != 1:
        raise ValueError("missing/mismatched symbol " + name)
    return values[0]


def locations(kinit, kcore):
    paths = (kinit, kcore)
    names = EVENT_NAMES + GLOBALS + ("mm_arenas", "mm_extents",
                                     "__kinit_image_end")
    return {name: symbol(paths, name) for name in names}


def raw_events(path, lookup):
    source = Path(path).read_text(encoding="ascii", errors="replace")
    events = []
    current = None
    for line in source.splitlines():
        match = re.match(r"^Breakpoint, PC:\s+([0-7]+)\b", line)
        if match:
            if current is not None:
                events.append(current)
            pc = int(match.group(1), 8)
            candidates = [name for name in EVENT_NAMES if lookup[name] == pc]
            if len(candidates) != 1:
                raise ValueError("unexpected/ambiguous breakpoint PC %o" % pc)
            current = {"event": candidates[0], "words": {}}
            continue
        match = re.match(r"^([0-7]{3,7}):\s+([0-7]{12})\s*$", line)
        if match and current is not None:
            address, value = int(match.group(1), 8), int(match.group(2), 8)
            if address in current["words"]:
                raise ValueError("duplicate physical word %o" % address)
            current["words"][address] = value
    if current is not None:
        events.append(current)
    if not events:
        raise ValueError("no genuine SIMH breakpoint events")
    starts = [i for i, event in enumerate(events)
              if event["event"] == "mres_init"]
    ends = [i for i, event in enumerate(events)
            if event["event"] == "vm_enter_initial_user"]
    if len(starts) != 1 or len(ends) != 1 or \
            starts[0] >= ends[0] or ends[0] != len(events) - 1:
        raise ValueError("no unique complete KINIT-to-user trace interval")
    if "INIT V1" in source:
        raise ValueError("trace ran into normal user execution")
    if "HALT instruction" in source or "SWAP FAIL" in source:
        raise ValueError("KINIT failed during physical event trace")
    if not source.rstrip().endswith("Log file closed\nProcess exited with code 0."):
        # Some SIMH builds omit the final host-process wording; a
        # successful simulator goodbye is the portable positive marker.
        if "Goodbye" not in source or "Log file closed" not in source:
            raise ValueError("SIMH did not complete terminal exit")
    return events[starts[0]:]


def decode(snapshot, addresses, expected_core, index):
    words = snapshot["words"]

    def read(name):
        addr = addresses[name]
        if addr not in words:
            raise ValueError("event %d missing live %s at %o" %
                             (index, name, addr))
        return words[addr]

    core_words = read("mm_core_words")
    if core_words != expected_core * 1024:
        raise ValueError("event %d core mismatch" % index)
    capacity = read("mm_extent_capacity")
    if capacity != 4 * (core_words >> 13) + 8 or capacity > MAX_EXTENTS:
        raise ValueError("event %d invalid physical MM capacity" % index)
    count = read("mm_extent_count")
    arenas_count = read("mm_arena_count")
    if not (0 <= count <= capacity) or not (1 <= arenas_count <= 3):
        raise ValueError("event %d impossible arena/extent counts" % index)

    def physical(addr):
        if addr not in words:
            raise ValueError("event %d missing physical address %o" %
                             (index, addr))
        return words[addr]

    arenas = []
    for slot in range(arenas_count):
        packed = physical(addresses["mm_arenas"] + slot)
        size, base = (packed >> 18) & HALF, packed & HALF
        if not size or base + size > core_words or \
                (arenas and base < arenas[-1][1]):
            raise ValueError("event %d impossible MM arena" % index)
        arenas.append((base, base + size))
    extents = []
    owners = {}
    allocated = 0
    for slot in range(count):
        span = physical(addresses["mm_extents"] + 2 * slot)
        meta = physical(addresses["mm_extents"] + 2 * slot + 1)
        size, base = (span >> 18) & HALF, span & HALF
        kind = (meta >> 18) & 7
        if not size or kind not in (1, 2, 3, 4) or \
                not any(a <= base and base + size <= b for a, b in arenas) or \
                (extents and base < extents[-1][1]):
            raise ValueError("event %d invalid MM extent/owner" % index)
        extents.append((base, base + size))
        allocated += size
        owners[kind] = owners.get(kind, 0) + size

    free = 0
    largest = 0
    for start, end in arenas:
        cursor = start
        for left, right in extents:
            if left < start or left >= end:
                continue
            gap = left - cursor
            if gap < 0:
                raise ValueError("event %d overlapping physical MM" % index)
            free += gap
            largest = max(largest, gap)
            cursor = right
        gap = end - cursor
        if gap < 0:
            raise ValueError("event %d bad final arena gap" % index)
        free += gap
        largest = max(largest, gap)
    managed = sum(end - start for start, end in arenas)
    if managed != free + allocated:
        raise ValueError("event %d physical MM words not conserved" % index)
    permanent = read("sys_resident_words_immediate") & HALF
    if permanent > core_words:
        raise ValueError("event %d invalid permanent resident patch" % index)
    return dict(event=snapshot["event"], order=index, free=free,
                occupied_or_reserved=core_words-free,
                allocated=allocated, largest_free=largest, managed=managed,
                extents=count, arenas=arenas_count,
                by_type={str(k): v for k, v in sorted(owners.items())},
                permanent_resident=permanent)


def run(argv):
    if len(argv) != 6:
        raise ValueError("usage: trace-v1670.py kinit.map kcore.map "
                         "simh.log physical_kwords report.json")
    maps = locations(argv[1], argv[2])
    core = int(argv[4])
    entries = [decode(event, maps, core, i)
               for i, event in enumerate(raw_events(argv[3], maps))]
    expected = ("mres_init", "mm_extent_insert", "mm_add_free",
                "mm_boot_reserve", "vm_enter_initial_user")
    counts = {name: sum(e["event"] == name for e in entries)
              for name in EVENT_NAMES}
    if any(counts[name] <= 0 for name in expected) or \
            counts["vm_enter_initial_user"] != 1 or \
            counts["mres_init"] != 1:
        raise ValueError("missing required KINIT mutation/terminal events")
    # No unexpected compaction or VM extent in-place size change may
    # evade the common insertion/free/boot arena accounting.
    for name in ("mm_compact", "mm_process_shrink_pinned",
                 "mm_process_grow_pinned"):
        if counts[name]:
            raise ValueError("unexpected KINIT size/movement path " + name)
    terminal = entries[-1]
    if terminal["event"] != "vm_enter_initial_user" or \
            terminal["permanent_resident"] <= 0:
        raise ValueError("no terminal VM entry with patched resident words")

    maximum = max(entries, key=lambda e: e["occupied_or_reserved"])
    smallest = min(entries, key=lambda e: e["free"])
    report = dict(core_kwords=core,
                  image_end_octal="%06o" % maps["__kinit_image_end"],
                  event_count=len(entries), events_by_type=counts,
                  max_sampled_nonfree=maximum["occupied_or_reserved"],
                  min_sampled_free=smallest["free"],
                  high_water_event=maximum["event"],
                  high_water_order=maximum["order"],
                  terminal=terminal, samples=entries)
    Path(argv[5]).write_text(json.dumps(report, indent=2, sort_keys=True)
                             + "\n", encoding="ascii")
    print("PASS v1670 %dK: %d physical events, min sampled free %d, "
          "max sampled nonfree %d, final free %d, final extents %d" %
          (core, len(entries), smallest["free"],
           maximum["occupied_or_reserved"], terminal["free"],
           terminal["extents"]))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1670 physical event trace: " + str(exc))

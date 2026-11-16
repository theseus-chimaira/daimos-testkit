#!/usr/bin/env python3
"""Audit three live original PDP-6 MM ownership snapshots in one guest.

Do not infer that the sampled resident usage is a transient peak or
that omitted PURE prefixes imply whole-system positive net savings.
"""

import argparse
from pathlib import Path
import re


def symbols_from_map(text):
    symbols = {}
    for line in text.splitlines():
        p = line.split()
        if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
            symbols[p[0]] = int(p[1], 8)
    for key in ("mm_arenas", "mm_arena_count", "mm_extents",
                "mm_extent_count", "proc_current_slot", "proc_high_slot"):
        assert key in symbols, "missing source map: " + key
    return symbols


def decode_stage(trace, symbols, stage):
    head = "V1628_STAGE_%s\n" % stage
    tail = "V1628_END_%s\n" % stage
    assert trace.count(head) == 1 and trace.count(tail) == 1, \
        "missing or repeated %s physical snapshot" % stage
    segment = trace.split(head, 1)[1].split(tail, 1)[0]
    words = {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", segment)}

    def get(name):
        address = symbols[name]
        assert address in words, "missing %s physical word %06o" % (
            stage, address)
        return words[address]

    arena_count = get("mm_arena_count")
    extent_count = get("mm_extent_count")
    assert arena_count == 1 and 1 <= extent_count <= 48
    current = get("proc_current_slot")
    assert current == 1, "snapshot no longer in parent slot 1"
    arena = get("mm_arenas")
    low, size = arena & 0o777777, (arena >> 18) & 0o777777
    high = low + size
    assert 0o40000 <= low <= 0o50000 and high == 0o200000
    extents = []
    for i in range(extent_count):
        address = symbols["mm_extents"] + 2 * i
        assert address in words and address + 1 in words
        span, meta = words[address], words[address + 1]
        base = span & 0o777777
        length = (span >> 18) & 0o777777
        kind = (meta >> 18) & 0o7
        pins = (meta >> 21) & 0o377
        owner = meta & 0o777777
        assert length and kind in (1, 2, 3, 4)
        assert low <= base and base + length <= high
        extents.append((base, base + length, kind, pins, owner))
    assert extents == sorted(extents), "unsorted physical extent owners"
    cursor = low
    total_free = 0
    best_aligned = 0
    for start, end, _, _, _ in extents + [(high, high, 0, 0, 0)]:
        assert cursor <= start, "overlapping physical MM extents"
        if start > cursor:
            total_free += start - cursor
            aligned = (cursor + 0o1777) & ~0o1777
            best_aligned = max(best_aligned, max(0, start - aligned))
        cursor = end
    packed = [e for e in extents if e[2] == 4]
    assert all(pin == 0 for _, _, _, pin, _ in packed), \
        "steady process PACKED owner has stranded pin"
    owners = [owner for _, _, _, _, owner in packed]
    assert len(set(owners)) == len(owners), "duplicate PACKED owner"
    packed_words = sum(end - start for start, end, _, _, _ in packed)
    occupied_words = sum(end - start for start, end, _, _, _ in extents)
    assert occupied_words + total_free == size
    return (low, high, extent_count, packed, packed_words,
            total_free, best_aligned, occupied_words)


def audit(map_text, trace):
    symbols = symbols_from_map(map_text)
    assert "MEM                                  64 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaa[B" in trace and "[A" in trace
    assert "LwwwwwwZ" in trace
    assert trace.index("V1628_STAGE_B") < trace.index("V1628_STAGE_A")
    assert trace.index("V1628_STAGE_A") < trace.index("V1628_STAGE_Z")
    assert "HALT instruction" in trace
    observations = {}
    arenas = set()
    for stage in "BAZ":
        low, high, count, packed, packed_words, free, aligned, occupied = (
            decode_stage(trace, symbols, stage))
        arenas.add((low, high))
        observations[stage] = packed
        print("v1628 %s: arena=%06o..%06o extents=%o PACKED=%d packed_words=%06o "
              "occupied=%06o free=%06o best_aligned=%06o" %
              (stage, low, high, count, len(packed), packed_words, occupied, free,
               aligned))
        for start, end, _, _, owner in packed:
            print("  PACKED owner %03o: %06o..%06o" % (owner, start, end))
    assert len(arenas) == 1, "MM arena changed across stable lifecycle"
    assert len(observations["Z"]) == 0, \
        "packed child owner survived six checked WAIT/EXIT calls"
    print("PASS v1628: original three-stage physical MM ownership checks")
    print("v1628: sampled RAM is not whole-system net/peak acceptance")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kcore_map", type=Path)
    parser.add_argument("physical_trace", type=Path)
    args = parser.parse_args()
    try:
        audit(args.kcore_map.read_text(encoding="ascii"),
              args.physical_trace.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1628 MM lifecycle audit: %s\n" % exc)


if __name__ == "__main__":
    main()

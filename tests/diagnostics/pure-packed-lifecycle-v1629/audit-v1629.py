#!/usr/bin/env python3
"""Audit genuine 48K PACKED->PROCESS->EXIT under live parent WAIT.

Use source-matched executable behavior plus live MM stage snapshots.
Do not convert gross omitted text into unproven peak/net RAM benefit.
"""

import argparse
from pathlib import Path
import re


def parse_symbols(text):
    result = {}
    for line in text.splitlines():
        p = line.split()
        if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
            result[p[0]] = int(p[1], 8)
    for name in ("mm_arenas", "mm_arena_count", "mm_extents",
                 "mm_extent_count", "proc_current_slot", "proc_high_slot"):
        assert name in result, "missing linked source symbol: " + name
    return result


def stage_owners(trace, symbols, stage):
    start = "V1629_STAGE_%s\n" % stage
    end = "V1629_END_%s\n" % stage
    assert trace.count(start) == 1 and trace.count(end) == 1
    s = trace.split(start, 1)[1].split(end, 1)[0]
    words = {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", s)}

    def get(name):
        assert symbols[name] in words, "missing %s machine word: %s" % (
            stage, name)
        return words[symbols[name]]

    assert get("proc_current_slot") == 1
    assert get("mm_arena_count") == 1
    count = get("mm_extent_count")
    assert 1 <= count <= 48
    arena = get("mm_arenas")
    low, size = arena & 0o777777, (arena >> 18) & 0o777777
    high = low + size
    assert (low, high) == (0o42562, 0o140000)
    extents = []
    for index in range(count):
        address = symbols["mm_extents"] + 2 * index
        assert address in words and address + 1 in words
        span, meta = words[address], words[address + 1]
        base = span & 0o777777
        length = (span >> 18) & 0o777777
        kind = (meta >> 18) & 0o7
        pin = (meta >> 21) & 0o377
        owner = meta & 0o777777
        assert length and low <= base and base + length <= high
        assert kind in (1, 2, 3, 4)
        extents.append((base, base + length, kind, pin, owner))
    assert extents == sorted(extents), "unordered MM owner table"
    cursor = low
    free = 0
    for base, end, _, _, _ in extents + [(high, high, 0, 0, 0)]:
        assert cursor <= base, "overlapping MM ownership"
        free += base - cursor
        cursor = end
    occupied = sum(end - start for start, end, _, _, _ in extents)
    assert occupied + free == size
    return extents, occupied, free


def audit(map_text, trace, source):
    assert re.search(r"(?m)^#define P14_CHILDREN\s+5U$", source)
    assert re.search(r"(?m)^#define P14_BRK_TARGET\s+010000UL$", source)
    assert re.search(r"(?m)^#define P14_STATUS\s+057U$", source)
    assert "denied = p14_spawn(rd);" in source
    assert "if (denied != -1)" in source
    assert "(void)p14_char('x');" in source
    assert "(void)p14_char('L');" in source
    assert "(void)p14_char('Z');" in source
    assert "dsys_wait((unsigned int)pid[i], &status, 0U)" in source
    assert "SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED" in source
    assert "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS" in source
    assert "p14_data[0] != 012345670123UL" in source
    assert "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL" in source
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaax[BV1629_STAGE_B" in trace
    assert "LwwwwwZV1629_STAGE_Z" in trace
    assert "HALT instruction" in trace
    symbols = parse_symbols(map_text)
    for stage in "BAZ":
        extents, occupied, free = stage_owners(trace, symbols, stage)
        packed = [(base, end, pin, owner)
                  for base, end, kind, pin, owner in extents if kind == 4]
        if stage in "BA":
            assert len(packed) == 5, \
                "live parent did not retain five PACKED children"
            assert {owner for _, _, _, owner in packed} == set(range(2, 7))
            assert all(end - base == 0o7000 and pin == 0
                       for base, end, pin, _ in packed)
        else:
            assert not packed, "PACKED child remains after all WAITs"
            assert all(not (kind == 1 and 2 <= owner <= 6)
                       for _, _, kind, _, owner in extents), \
                "finished child retains a PROCESS owner"
            assert sum(1 for _, _, kind, _, owner in extents
                       if kind == 1 and owner == 1) == 1
        print("v1629 %s: extents=%o PACKED=%d occupied=%06o free=%06o" %
              (stage, len(extents), len(packed), occupied, free))
        for base, end, pin, owner in packed:
            print("  owner %03o PACKED %06o..%06o pin=%o" %
                  (owner, base, end, pin))
    print("PASS v1629: five genuine 48K PACKED owners restored and reaped")
    print("v1629: whole-system peak/net RAM savings remain unverified")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kcore_map", type=Path)
    parser.add_argument("physical_trace", type=Path)
    parser.add_argument("guest_source", type=Path)
    args = parser.parse_args()
    try:
        audit(args.kcore_map.read_text(encoding="ascii"),
              args.physical_trace.read_text(encoding="ascii"),
              args.guest_source.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1629 physical PACKED audit: %s\n" % exc)


if __name__ == "__main__":
    main()

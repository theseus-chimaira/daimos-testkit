#!/usr/bin/env python3
"""Source-matched PDP-6 MM proof at sixth PURE RUN admission failure.

Decode only real simulator MM words and a matching DXR executable.
The DXR allocation is calculated using the original exec_load.s rules
and the original 02000-word APR quantum, not a guessed fixed image size.
"""

import argparse
from pathlib import Path
import re
import subprocess


def parse_map(text):
    result = {}
    for line in text.splitlines():
        p = line.split()
        if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
            result[p[0]] = int(p[1], 8)
    for name in ("mm_arenas", "mm_arena_count", "mm_extents",
                 "mm_extent_count", "proc_high_slot", "proc_slots"):
        assert name in result, "missing source map symbol: " + name
    return result


def parse_physical(text):
    return {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", text)}


def check_geometry(symbols, words, dxr_text, exec_source):
    def get(name):
        assert symbols[name] in words, "missing machine word: " + name
        return words[symbols[name]]

    assert "Breakpoint, PC: 017725" in words["trace_text"]
    assert "1:\t777777777776" in words["trace_text"]
    assert get("mm_arena_count") == 1
    count = get("mm_extent_count")
    assert count == 0o22
    assert get("proc_high_slot") == 0o10
    assert get("proc_slots") == 0o14
    arena_word = get("mm_arenas")
    low, size = arena_word & 0o777777, (arena_word >> 18) & 0o777777
    high = low + size
    assert (low, high) == (0o42562, 0o140000)

    e = []
    for index in range(count):
        address = symbols["mm_extents"] + 2 * index
        assert address in words and address + 1 in words
        span, meta = words[address], words[address + 1]
        base = span & 0o777777
        length = (span >> 18) & 0o777777
        kind = (meta >> 18) & 0o7
        pins = (meta >> 21) & 0o377
        owner = meta & 0o777777
        assert length > 0 and low <= base < high
        assert kind in (1, 2, 3, 4)
        e.append((base, base + length, kind, pins, owner))
    assert e == sorted(e)
    packed = [(start, end, pin, owner) for start, end, kind, pin, owner
              in e if kind == 4]
    assert len(packed) == 5
    assert [owner for _, _, _, owner in packed] == [6, 5, 4, 3, 2]
    assert all(end - start == 0o7000 and pin == 0
               for start, end, pin, _ in packed)
    assert sum(end - start for start, end, _, _ in packed) == 0o43000
    assert sum(1 for _, _, kind, _, owner in e
               if kind == 1 and owner == 1) == 1

    free = 0
    best = 0
    gaps = []
    cursor = low
    for start, end, _, _, _ in e + [(high, high, 0, 0, 0)]:
        assert start >= cursor, "overlap in physical MM owner table"
        if start > cursor:
            align = (cursor + 0o1777) & ~0o1777
            available = max(0, start - align)
            gaps.append((cursor, start, available))
            best = max(best, available)
            free += start - cursor
        cursor = end
    assert (free, best) == (0o16173, 0o7000)

    line = re.search(r"DXR magic=DXR entry=[0-7]+ image=([0-7]+) "
                     r"bss=([0-7]+) reloc=[0-7]+ words=[0-9]+ "
                     r"purity=PURE", dxr_text)
    assert line, "DXR image/header is not authenticated PURE"
    image, bss = (int(s, 8) for s in line.groups())
    assert (image, bss) == (0o1043, 0o4001)
    assert re.search(r"exec_load_create_vm:\s*\n"
                     r"\s*move\s+3,13\s*\n\s*add\s+3,16\s*\n"
                     r"\s*addi\s+3,02020", exec_source)
    requested = image + bss + 0o2020
    aligned = (requested + 0o1777) & ~0o1777
    assert aligned == 0o10000
    assert best < aligned
    print("v1626 physical: arena %06o..%06o, extents=%o" %
          (low, high, count))
    for start, end, available in gaps:
        print("  free %06o..%06o aligned=%06o" % (start, end, available))
    print("v1626 physical: 5 PACKED suffixes = %06o words" % 0o43000)
    print("v1626 physical: free=%06o, largest aligned=%06o" %
          (free, best))
    print("v1626 DXR PURE: image=%06o bss=%06o stack+origin=%06o" %
          (image, bss, 0o2020))
    print("v1626 initial VM: requested=%06o, aligned=%06o, no fit" %
          (requested, aligned))
    print("PASS v1626: sixth RUN physical fragmentation/capacity proof")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kcore_map", type=Path)
    parser.add_argument("simh_trace", type=Path)
    parser.add_argument("pure_dxr", type=Path)
    parser.add_argument("exec_load_source", type=Path)
    parser.add_argument("--dxrcheck", default="dxrcheck")
    args = parser.parse_args()
    try:
        symbols = parse_map(args.kcore_map.read_text(encoding="ascii"))
        trace = args.simh_trace.read_text(encoding="ascii")
        physical = parse_physical(trace)
        physical["trace_text"] = trace
        check_geometry(symbols, physical, subprocess.check_output(
            [args.dxrcheck, "-d", str(args.pure_dxr)],
            text=True, encoding="ascii"),
            args.exec_load_source.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError, subprocess.CalledProcessError) as exc:
        parser.exit(1, "FAIL v1626 physical MM proof: %s\n" % exc)


if __name__ == "__main__":
    main()

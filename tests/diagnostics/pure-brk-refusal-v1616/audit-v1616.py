#!/usr/bin/env python3
"""Verify pre-BRK and late interrupted physical MM snapshots from PDP-6.

The later SIGTERM MM view is NOT an atomic transaction-boundary sample
and must never be interpreted as a permanent pin leak or successful RUN.
"""
import re
import sys
from pathlib import Path


def load_symbols(path):
    symbols = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and not parts[1].strip("01234567"):
            symbols[parts[0]] = int(parts[1], 8)
    for name in ("mm_extent_count", "mm_extents", "mm_arena_count",
                 "mm_arenas", "proc_current_slot"):
        if name not in symbols:
            raise ValueError("missing KCORE symbol: " + name)
    return symbols


def load_snapshot(path, symbols):
    trace = Path(path).read_text()
    words = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", trace)}

    def word(address):
        if address not in words:
            raise ValueError("missing physical word %06o" % address)
        return words[address]

    if word(symbols["mm_arena_count"]) != 1:
        raise ValueError("unexpected managed arena count")
    arena_word = word(symbols["mm_arenas"])
    if ((arena_word & 0o777777) != 0o42562 or
            ((arena_word >> 18) & 0o777777) != 0o75216):
        raise ValueError("unexpected physical 48K arena")
    count = word(symbols["mm_extent_count"])
    if count > 136:
        raise ValueError("unreasonable MM extent count")
    extents = []
    for i in range(count):
        span = word(symbols["mm_extents"] + 2 * i)
        meta = word(symbols["mm_extents"] + 2 * i + 1)
        extents.append(((meta >> 18) & 0o7, meta & 0o777777,
                        span & 0o777777, (span >> 18) & 0o777777,
                        (meta >> 21) & 0o377))
    cursor = 0o42562
    for kind, owner, base, size, pins in extents:
        if base < cursor or base + size > 0o140000:
            raise ValueError("overlapping or outside physical MM owners")
        cursor = base + size
    return trace, word(symbols["proc_current_slot"]), extents


def main():
    if len(sys.argv) != 4:
        raise ValueError("usage: audit-v1616.py MAP BEFORE.clean AFTER.clean")
    symbols = load_symbols(sys.argv[1])
    before, current_before, b = load_snapshot(sys.argv[2], symbols)
    after, current_after, a = load_snapshot(sys.argv[3], symbols)
    expected_processes = {
        1: (0o50000, 0o16000), 5: (0o66000, 0o10000),
        4: (0o76000, 0o10000), 3: (0o106000, 0o10000),
        2: (0o116000, 0o10000),
    }
    process_before = {
        owner: (base, size) for kind, owner, base, size, pins in b
        if kind == 1
    }
    if ("<010000+020000>" not in before or current_before != 1 or
            process_before != expected_processes or
            any(e[0] == 4 for e in b)):
        raise ValueError("pre-BRK owner layout differs from physical trace")
    packed_after = {
        owner: (base, size, pins) for kind, owner, base, size, pins in a
        if kind == 4
    }
    expected_packed = {
        5: (0o67000, 0o7000, 0),
        4: (0o76000, 0o10000, 1),
    }
    if (current_after != 0 or
            "SIGTERM received, PC:" not in after or
            packed_after != expected_packed or
            any(e[0] == 1 for e in a) or
            "Breakpoint, PC: 020761" in after):
        raise ValueError("late interrupted RAW owner evidence differs")
    print("PASS v1616 physical BEFORE: 5 PROCESS, 0 PACKED")
    print("PASS v1616 late physical sample: 2 PACKED, 1 pin")
    print("OPEN v1616: no BRK return; interrupted pin is not a leak proof")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as exc:
        raise SystemExit("FAIL v1616 audit: " + str(exc))

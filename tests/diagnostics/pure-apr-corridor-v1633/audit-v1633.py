#!/usr/bin/env python3
"""Prove the physical 48K APR corridor bound from original MM owners.

This audit studies a *fixed* resident parent and nonmovable kernel
dynamic extents. It never assumes PACKED suffix relocation is safe,
nor that admission alone guarantees later runnable restoration.
All quantities are 36-bit PDP-6 words, printed in octal.
"""

import argparse
from pathlib import Path
import re
import runpy


ROOT = Path(__file__).resolve().parent.parent
ALIGN = 0o2000
FULL = 0o10000
PREFIX = 0o1000
CHILDREN = 6


def symbols(text):
    return {f[0]: int(f[1], 8) for line in text.splitlines()
            if len(f := line.split()) >= 2 and re.fullmatch(r"[0-7]+", f[1])}


def free_prefix(extents, low, high, start, words):
    end = start + words
    return low <= start < end <= high and all(
        end <= base or start >= limit
        for base, limit, _, _, _ in extents)


def align_up(value, quantum):
    return (value + quantum - 1) & ~(quantum - 1)


def analyse(on_case, off_case, on_trace, off_trace):
    # Reuse the source-backed owner-format auditors, which check the
    # original physical extent table and both guest/linker identities.
    matched = runpy.run_path(str(ROOT / "pure-equal-five-v1632/audit-v1632.py"))
    matched["audit"](on_case, off_case, on_trace, off_trace, ROOT)
    on = runpy.run_path(str(ROOT / "pure-packed-lifecycle-v1629/audit-v1629.py"))
    off = runpy.run_path(str(ROOT / "pure-capacity-baseline-v1631/audit-v1631.py"))
    mmap = (on_case / "build/kcore.map").read_text(encoding="ascii")
    on_symbols = on["parse_symbols"](mmap)
    on_extents, _, _ = on["stage_owners"](
        on_trace, on_symbols, "B")
    off_symbols = off["symbols"](mmap)
    _, _, _, off_process, _, _, _ = off["decode_off"](
        off_trace, off_symbols, "V1632_FIVE_READY", "V1632_END_FIVE", 6)
    off_extents = []
    # Reuse the same original physical snapshot, including the KERNEL
    # DYNAMIC descriptors not returned by decode_off's process filter.
    sub = off_trace.split("V1632_FIVE_READY\n", 1)[1].split(
        "V1632_END_FIVE\n", 1)[0]
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", sub)}
    for i in range(words[off_symbols["mm_extent_count"]]):
        address = off_symbols["mm_extents"] + 2 * i
        span, meta = words[address], words[address + 1]
        base = span & 0o777777
        off_extents.append((base, base + (span >> 18),
                            (meta >> 18) & 7,
                            (meta >> 21) & 255, meta & 0o777777))

    parent = [(a, b) for a, b, kind, _, owner in on_extents
              if kind == 1 and owner == 1]
    assert parent == [(0o126000, 0o136000)]
    assert any(a == parent[0][0] and b == parent[0][1] and
               kind == 1 and owner == 1
               for a, b, kind, _, owner in off_extents)
    assert len(off_process) == 6
    parent_base = parent[0][0]
    # An unrelated transient scratch owner can reside in the upper
    # tail. Only low-core DYNAMIC extents actually bound the process
    # corridor between KINIT and the still-resident parent.
    on_dynamic = max(b for a, b, kind, _, _ in on_extents
                     if kind == 3 and a < parent_base)
    off_dynamic = max(b for a, b, kind, _, _ in off_extents
                      if kind == 3 and a < parent_base)
    assert (on_dynamic, off_dynamic) == (0o46605, 0o43247), \
        "source-matched dynamic boundary drift"
    assert on_dynamic - off_dynamic == 0o3336

    packed = [(a, b, owner) for a, b, kind, pin, owner in on_extents
              if kind == 4 and pin == 0]
    assert len(packed) == 5
    assert {owner for _, _, owner in packed} == set(range(2, 7))
    for start, end, _ in packed:
        assert end - start == FULL - PREFIX
        assert (start - PREFIX) % ALIGN == 0
        assert free_prefix(on_extents, 0o42562, 0o140000,
                           start - PREFIX, PREFIX), \
            "original in-place restore prefix is obstructed"

    on_first, off_first = (align_up(x, ALIGN)
                           for x in (on_dynamic, off_dynamic))
    on_capacity = (parent_base - on_first) // FULL
    off_capacity = (parent_base - off_first) // FULL
    assert (on_first, off_first) == (0o50000, 0o44000)
    assert (on_capacity, off_capacity) == (5, 6)
    # With one fixed resident parent and the trailing tail smaller than
    # one full APR, six other runnable APRs must fit before the parent.
    assert 0o140000 - parent[0][1] < FULL
    last_permissible_top = parent_base - CHILDREN * FULL
    assert last_permissible_top == 0o46000
    deficit = on_dynamic - last_permissible_top
    assert deficit == 0o605
    assert (parent_base - on_dynamic) == 0o57173
    assert CHILDREN * FULL - (parent_base - on_dynamic) == deficit
    assert off_dynamic <= last_permissible_top

    print("v1633: parent APR 126000..136000; upper tail 002000")
    print("v1633: dynamic high ON=%06o OFF=%06o; delta=%06o" %
          (on_dynamic, off_dynamic, on_dynamic - off_dynamic))
    print("v1633: first APR-aligned ON=%06o OFF=%06o" %
          (on_first, off_first))
    print("v1633: runnable child APR cells ON=%d OFF=%d" %
          (on_capacity, off_capacity))
    print("v1633: 6 child APR cells require dynamic high <=%06o" %
          last_permissible_top)
    print("v1633: necessary corridor improvement >=%06o octal, %d decimal words" %
          (deficit, deficit))
    print("v1633: moving PACKED suffixes alone cannot make 6 full APRs fit")
    print("v1633: module shrink by that amount is a hypothesis, NOT a tested fix")
    print("PASS v1633: fixed-owner 48K APR corridor lower bound")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("on_case", type=Path)
    p.add_argument("off_case", type=Path)
    p.add_argument("on_trace", type=Path)
    p.add_argument("off_trace", type=Path)
    args = p.parse_args()
    try:
        analyse(args.on_case, args.off_case,
                args.on_trace.read_text(encoding="ascii"),
                args.off_trace.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError, KeyError, ValueError) as exc:
        p.exit(1, "FAIL v1633 APR corridor proof: %s\n" % exc)


if __name__ == "__main__":
    main()

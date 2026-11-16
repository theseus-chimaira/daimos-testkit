#!/usr/bin/env python3
"""Prove BCACHE's high 0201-word owner blocks first PDP-6 parent APR.

This is a read-only audit of the original 48K v1629 VM-entry
breakpoint and later known resident parent. It does not choose an
alternative placement or authorize changes to kernel allocator code.
"""

import argparse
from pathlib import Path
import re


def symbols(text):
    return {f[0]: int(f[1], 8) for line in text.splitlines()
            if len(f := line.split()) >= 2 and re.fullmatch(r"[0-7]+", f[1])}


def stage_words(trace):
    assert trace.count("V1635_BEFORE_FIRST_VM\n") == 1
    assert trace.count("V1635_END_FIRST_VM\n") == 1
    assert "Breakpoint, PC: 022472 (PUSH 17,10)" in trace
    segment = trace.split("V1635_BEFORE_FIRST_VM\n", 1)[1].split(
        "V1635_END_FIRST_VM\n", 1)[0]
    return {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", segment)}


def audit(map_text, physical, bcache_source, later_trace):
    symbols_map = symbols(map_text)
    for key in ("vm_space_create", "mm_extents", "mm_extent_count",
                "mm_arena_count", "mm_arenas", "proc_current_slot",
                "proc_high_slot"):
        assert key in symbols_map, "missing source-linked symbol: " + key
    assert symbols_map["vm_space_create"] == 0o22472
    assert re.search(r"\.equ\s+BCACHE_MM_OWNER,6", bcache_source)
    assert re.search(r"\.equ\s+BCACHE_SLAB_WORDS,0201", bcache_source)
    assert re.search(r"movei\s+1,1\s*\n"
                     r"\s*movem\s+1,\(17\)\s*; arg 5: MM_ALLOC_HIGH",
                     bcache_source)
    assert "mm_alloc_aligned_noreclaim" in bcache_source
    words = stage_words(physical)

    def w(key):
        assert symbols_map[key] in words, "missing real MM word " + key
        return words[symbols_map[key]]

    assert words[2] == 1, "first VM must belong to parent slot 1"
    assert words[3] == 0o7067, "guest VM request changed"
    assert w("proc_current_slot") == 0
    assert w("proc_high_slot") == 2
    assert w("mm_arena_count") == 3
    assert w("mm_extent_count") == 6
    arena = []
    for i in range(w("mm_arena_count")):
        value = words[symbols_map["mm_arenas"] + i]
        start = value & 0o777777
        arena.append((start, start + (value >> 18)))
    assert arena[-1] == (0o114222, 0o140000)
    owner = []
    for i in range(w("mm_extent_count")):
        address = symbols_map["mm_extents"] + i * 2
        span, meta = words[address], words[address + 1]
        start = span & 0o777777
        size = span >> 18
        owner.append((start, start + size,
                      (meta >> 18) & 7, (meta >> 21) & 255,
                      meta & 0o777777))
    assert owner == sorted(owner), "invalid original extent ordering"
    slab = [item for item in owner if item[4] == 6 and item[2] == 3]
    assert slab == [(0o137577, 0o140000, 3, 0, 6)]
    assert all(not (a <= 0o137577 < b) for a, b, _, _, _ in owner[:-1])
    assert all(item[2] != 1 for item in owner), \
        "original first VM was already resident"
    aligned_words = (words[3] + 0o1777) & ~0o1777
    assert aligned_words == 0o10000
    cache_top = slab[0][0]
    constrained_parent = (cache_top - aligned_words) & ~0o1777
    unobstructed_parent = (arena[-1][1] - aligned_words) & ~0o1777
    assert (constrained_parent, unobstructed_parent) == (0o126000,
                                                       0o130000)
    assert constrained_parent + aligned_words <= cache_top
    assert unobstructed_parent < slab[0][1] and \
        unobstructed_parent + aligned_words > slab[0][0]
    # Independent completed guest MM snapshot confirms the actual
    # parent was allocated at the predicted obstructed APR base.
    assert "V1629_STAGE_B\n" in later_trace
    stage = later_trace.split("V1629_STAGE_B\n", 1)[1].split(
        "V1629_END_B\n", 1)[0]
    physical_b = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", stage)}
    slot_owners = []
    for i in range(physical_b[symbols_map["mm_extent_count"]]):
        address = symbols_map["mm_extents"] + i * 2
        span, meta = physical_b[address], physical_b[address + 1]
        if (meta & 0o777777) == 1 and ((meta >> 18) & 7) == 1:
            slot_owners.append((span & 0o777777, span >> 18))
    assert slot_owners == [(constrained_parent, aligned_words)]
    print("v1635 first VM: slot 1, request=007067 -> 010000 APR")
    print("v1635 original high arena: 114222..140000")
    print("v1635 BCACHE owner 6: 137577..140000, 0201 words")
    print("v1635 original available high APR base=%06o" %
          constrained_parent)
    print("v1635 if cache were absent: high APR base=%06o" %
          unobstructed_parent)
    print("v1635: parent actually observed at 126000..136000 later")
    print("PASS v1635: source-matched high-cache initial-parent obstruction")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("kcore_map", type=Path)
    p.add_argument("physical_vm_trace", type=Path)
    p.add_argument("bcache_assembler", type=Path)
    p.add_argument("physical_packed_trace", type=Path)
    args = p.parse_args()
    try:
        audit(args.kcore_map.read_text(encoding="ascii"),
              args.physical_vm_trace.read_text(encoding="ascii"),
              args.bcache_assembler.read_text(encoding="ascii"),
              args.physical_packed_trace.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError, KeyError) as exc:
        p.exit(1, "FAIL v1635 physical parent-placement audit: %s\n" % exc)


if __name__ == "__main__":
    main()

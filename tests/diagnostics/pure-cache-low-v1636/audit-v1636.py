#!/usr/bin/env python3
"""Validate physical six-child MM admission and parent WAIT on 48K.

Read the exact linked MM extent table from each original SIMH sample.
Do not infer PACKED restoration unless actual PACKED owners were seen.
The test is independent of any claimed process-memory counter delta.
"""

import argparse
from pathlib import Path
import re


def linked_symbols(text):
    symbols = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
            symbols[parts[0]] = int(parts[1], 8)
    for name in ("mm_arenas", "mm_arena_count", "mm_extents",
                 "mm_extent_count", "proc_current_slot", "proc_high_slot"):
        assert name in symbols, "missing original linked MM symbol " + name
    return symbols


def read_stage(physical, symbols, name, version="V1636"):
    first = "%s_STAGE_%s\n" % (version, name)
    last = "%s_END_%s\n" % (version, name)
    assert physical.count(first) == 1 and physical.count(last) == 1
    text = physical.split(first, 1)[1].split(last, 1)[0]
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", text)}

    def get(symbol):
        address = symbols[symbol]
        assert address in words, "missing original physical " + symbol
        return words[address]

    assert get("proc_current_slot") == 1
    if name in "BA":
        assert get("proc_high_slot") >= 7
    else:
        assert get("proc_high_slot") == 2
    arenas = []
    for i in range(get("mm_arena_count")):
        address = symbols["mm_arenas"] + i
        assert address in words
        v = words[address]
        lo = v & 0o777777
        arenas.append((lo, lo + (v >> 18)))
    assert arenas and max(end for _, end in arenas) == 0o140000

    count = get("mm_extent_count")
    assert 1 <= count <= 48
    extents = []
    for i in range(count):
        address = symbols["mm_extents"] + i * 2
        assert address in words and address + 1 in words
        span = words[address]
        meta = words[address + 1]
        base, length = span & 0o777777, span >> 18
        kind, pin, owner = (meta >> 18) & 7, (meta >> 21) & 255, meta & 0o777777
        assert length and kind in (1, 2, 3, 4)
        assert any(lo <= base and base + length <= hi for lo, hi in arenas)
        extents.append((base, base + length, kind, pin, owner))
    assert extents == sorted(extents), "unsorted physical MM extents"
    assert all(a[1] <= b[0] for a, b in zip(extents, extents[1:])), \
        "overlapping MM owners"
    return extents


def audit(map_text, trace, source, cache_asm, dxrcheck):
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaa[BV1636_STAGE_B" in trace
    assert "LwwwwwwZV1636_STAGE_Z" in trace
    assert "HALT instruction" in trace
    assert re.search(r"(?m)^#define P14_CHILDREN\s+6U$", source)
    assert re.search(r"(?m)^#define P14_BRK_TARGET\s+010000UL$", source)
    for fragment in ("dsys_read_words(0, &word, 1U)",
                     "p14_data[0] != 012345670123UL",
                     "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
                     "dsys_wait((unsigned int)pid[i], &status, 0U)",
                     "SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('L');", "(void)p14_char('Z');"):
        assert fragment in source, "altered guest assertion: " + fragment
    assert "purity=PURE" in dxrcheck
    assert re.search(r"\.equ\s+BCACHE_SLAB_WORDS,0201", cache_asm)
    assert re.search(r"\.equ\s+BCACHE_MM_OWNER,6", cache_asm)
    assert re.search(r"setzm\s+\(17\)\s*; arg 5: MM_ALLOC_LOW", cache_asm)

    sym = linked_symbols(map_text)
    for stage in "BAZ":
        extent = read_stage(trace, sym, stage)
        parents = [(lo, hi) for lo, hi, kind, _, owner in extent
                   if kind == 1 and owner == 1]
        assert len(parents) == 1
        # Parent must start at highest APR without a cache slab above it.
        assert parents[0] == (0o130000, 0o140000), \
            "cache still displaced the long-lived parent"
        children = [(lo, hi, kind, pin, owner)
                    for lo, hi, kind, pin, owner in extent
                    if kind in (1, 4) and 2 <= owner <= 7]
        packed = [item for item in children if item[2] == 4]
        if stage in "BA":
            assert {item[4] for item in children} == set(range(2, 8)), \
                "six distinct children were not still MM-owned"
            assert len(children) == 6
            assert all(pin == 0 for _, _, _, pin, _ in children)
        else:
            assert not children, "child PACKED/PROCESS extent leaked after WAIT"
        cache = [(lo, hi, pin) for lo, hi, kind, pin, owner in extent
                 if kind == 3 and owner == 6 and hi - lo == 0o201]
        assert len(cache) <= 1
        if cache:
            assert cache[0][0] < 0o50000, "cache still at high arena"
            assert cache[0][2] == 0, "cache slab pin leaked"
        print("v1636 %s: parent=%06o..%06o, children=%d PACKED=%d "
              "BCACHE=%s, extents=%o" %
              (stage, parents[0][0], parents[0][1], len(children),
               len(packed), "low" if cache else "reclaimed", len(extent)))
    print("PASS v1636: six admitted 48K children, parent WAIT and MM release")
    print("v1636: PACKED-specific restore accepted only if B/A owner count > 0")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("map", type=Path)
    ap.add_argument("physical_trace", type=Path)
    ap.add_argument("guest_source", type=Path)
    ap.add_argument("bcache_asm", type=Path)
    ap.add_argument("dxrcheck_log", type=Path)
    a = ap.parse_args()
    try:
        audit(*(p.read_text(encoding="ascii") for p in
                (a.map, a.physical_trace, a.guest_source, a.bcache_asm,
                 a.dxrcheck_log)))
    except (AssertionError, UnicodeError, KeyError) as exc:
        ap.exit(1, "FAIL v1636 physical cache/MM audit: %s\n" % exc)


if __name__ == "__main__":
    main()

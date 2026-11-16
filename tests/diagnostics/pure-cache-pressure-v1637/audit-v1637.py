#!/usr/bin/env python3
"""Source-linked six-child PACKED restore after seventh RUN refusal.

This is a physical owner/lifecycle test, not a whole-system peak/net
RAM claim. The parent must survive the expected resource refusal.
"""

import argparse
from pathlib import Path
import re
import runpy


def audit(map_text, trace, source, cache_source, dxrcheck):
    helper = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                                "pure-cache-low-v1636/audit-v1636.py"))
    syms = helper["linked_symbols"](map_text)
    sample = helper["read_stage"]
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaax[BV1637_STAGE_B" in trace
    assert "LwwwwwwZV1637_STAGE_Z" in trace
    assert "HALT instruction" in trace
    assert "purity=PURE" in dxrcheck
    assert re.search(r"(?m)^#define P14_CHILDREN\s+6U$", source)
    assert re.search(r"(?m)^#define P14_BRK_TARGET\s+010000UL$", source)
    for fragment in ("denied = p14_spawn(rd);",
                     "if (denied != -1)",
                     "(void)p14_char('x');",
                     "dsys_read_words(0, &word, 1U)",
                     "p14_data[0] != 012345670123UL",
                     "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
                     "dsys_wait((unsigned int)pid[i], &status, 0U)",
                     "SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('L');", "(void)p14_char('Z');"):
        assert fragment in source, "source failure: " + fragment
    assert re.search(r"\.equ\s+BCACHE_SLAB_WORDS,0201", cache_source)
    assert re.search(r"\.equ\s+BCACHE_MM_OWNER,6", cache_source)
    assert re.search(r"setzm\s+\(17\)\s*; arg 5: MM_ALLOC_LOW",
                     cache_source)

    packed_sets = []
    for phase in "BAZ":
        extents = sample(trace, syms, phase, "V1637")
        parent = [(a, b) for a, b, kind, _, owner in extents
                  if kind == 1 and owner == 1]
        assert parent == [(0o130000, 0o140000)]
        children = [(a, b, kind, pin, owner)
                    for a, b, kind, pin, owner in extents
                    if kind in (1, 4) and 2 <= owner <= 7]
        packed = [(a, b, pin, owner) for a, b, kind, pin, owner in children
                  if kind == 4]
        cache = [(a, b, pin) for a, b, kind, pin, owner in extents
                 if kind == 3 and owner == 6 and b - a == 0o201]
        assert len(cache) <= 1
        assert all(a < 0o50000 and pin == 0 for a, b, pin in cache)
        if phase in "BA":
            assert len(children) == 6
            assert {owner for _, _, _, _, owner in children} == set(range(2, 8))
            assert all(pin == 0 for _, _, _, pin, _ in children)
            assert packed, "seventh RUN did not exercise actual PACKED owners"
            assert all(b - a == 0o7000 and pin == 0
                       for a, b, pin, _ in packed)
            packed_sets.append({(a, b, owner) for a, b, _, owner in packed})
        else:
            assert not children, "child MM owner leaked after six WAITs"
        print("v1637 %s: extents=%o, child owners=%d, PACKED=%d, "
              "cache=%s" % (phase, len(extents), len(children),
                             len(packed), "low" if cache else "reclaimed"))
        for a, b, pin, owner in packed:
            print("  PACKED owner %o: %06o..%06o pin=%o" %
                  (owner, a, b, pin))
    assert packed_sets[0] == packed_sets[1], \
        "PACKED physical owners changed during no-growth parent BRK"
    print("PASS v1637: six actual PACKED-to-user-EXIT/WAIT restorations")
    print("v1637: physical net/peak RAM and FULL relocation still OPEN")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("kcore_map", type=Path)
    p.add_argument("original_trace", type=Path)
    p.add_argument("guest_source", type=Path)
    p.add_argument("bcache_source", type=Path)
    p.add_argument("dxrcheck", type=Path)
    args = p.parse_args()
    try:
        audit(*(path.read_text(encoding="ascii") for path in
                (args.kcore_map, args.original_trace, args.guest_source,
                 args.bcache_source, args.dxrcheck)))
    except (AssertionError, UnicodeError, KeyError) as exc:
        p.exit(1, "FAIL v1637 physical PACKED pressure: %s\n" % exc)


if __name__ == "__main__":
    main()

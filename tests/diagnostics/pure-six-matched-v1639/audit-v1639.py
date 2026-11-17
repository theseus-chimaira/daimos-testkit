#!/usr/bin/env python3
"""Compare matched 48K six-child PURE-on/OFF physical MM snapshots.

Both guests execute identical INIT DXRs and the same fixed KCORE;
their seventh RUN must fail and parent WAITs must finish normally.
This is a sampled on/off net-free comparison, not a transient peak.
"""

import argparse
from pathlib import Path
import re
import runpy


BASE = Path(__file__).resolve().parent.parent
HELPER = runpy.run_path(str(BASE / "pure-cache-low-v1636/audit-v1636.py"))


def snapshot(trace, syms, phase, marker):
    extents = HELPER["read_stage"](trace, syms, phase, marker)
    begin = "%s_STAGE_%s\n" % (marker, phase)
    end = "%s_END_%s\n" % (marker, phase)
    part = trace.split(begin, 1)[1].split(end, 1)[0]
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", part)}
    count = words[syms["mm_arena_count"]]
    assert 1 <= count <= 3
    arenas = []
    for i in range(count):
        v = words[syms["mm_arenas"] + i]
        a = v & 0o777777
        arenas.append((a, a + (v >> 18)))
    assert arenas[0][0] < arenas[-1][1] == 0o140000
    occupied = sum(b - a for a, b, _, _, _ in extents)
    free = sum(b - a for a, b in arenas) - occupied
    assert free >= 0
    return extents, arenas, occupied, free


def audit(on_map, off_map, on_dxr, off_dxr, on_source,
          off_source, on_trace, off_trace):
    assert on_map == off_map, "fixed KCORE maps differ"
    assert on_dxr == off_dxr, "guest DXRs are not source-identical"
    assert on_source == off_source, "input C guest sources differ"
    for tag in ("#define P14_CHILDREN         6U",
                "denied = p14_spawn(rd);",
                "if (denied != -1)",
                "(void)p14_char('x');",
                "dsys_read_words(0, &word, 1U)",
                "dsys_wait((unsigned int)pid[i], &status, 0U)",
                "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                "(void)p14_char('Z');"):
        assert tag in on_source
    assert "MEM                                  48 K" in on_trace
    assert "MEM                                  48 K" in off_trace
    assert "PURE                              LOADED" in on_trace
    assert "PURE                              LOADED" not in off_trace
    assert "aaaaaax[BV1637_STAGE_B" in on_trace
    assert "aaaaaax[BV1639_STAGE_B" in off_trace
    assert "LwwwwwwZV1637_STAGE_Z" in on_trace
    assert "LwwwwwwZV1639_STAGE_Z" in off_trace
    assert "HALT instruction" in on_trace
    assert "HALT instruction" in off_trace
    syms = HELPER["linked_symbols"](on_map)
    for phase in "BAZ":
        on_e, on_a, on_o, on_f = snapshot(on_trace, syms, phase, "V1637")
        off_e, off_a, off_o, off_f = snapshot(off_trace, syms, phase, "V1639")
        assert on_a[0][0] - off_a[0][0] == 0o3336, \
            "installed optional 1758-word PURE MRES not counted"
        for table in (on_e, off_e):
            parents = [(a, b) for a, b, kind, pin, owner in table
                       if kind == 1 and owner == 1 and pin == 0]
            assert parents == [(0o130000, 0o140000)]
        on_children = [(a, b, kind, pin, owner)
                       for a, b, kind, pin, owner in on_e
                       if kind in (1, 4) and 2 <= owner <= 7]
        off_children = [(a, b, kind, pin, owner)
                        for a, b, kind, pin, owner in off_e
                        if kind in (1, 4) and 2 <= owner <= 7]
        if phase in "BA":
            assert len(on_children) == len(off_children) == 6
            assert {o for _, _, _, _, o in on_children} == set(range(2, 8))
            assert {o for _, _, _, _, o in off_children} == set(range(2, 8))
            assert all(k == 4 and b-a == 0o7000 and p == 0
                       for a, b, k, p, _ in on_children)
            assert all(k == 1 and b-a == 0o10000 and p == 0
                       for a, b, k, p, _ in off_children)
        else:
            assert not on_children and not off_children
        print("v1639 %s: ON occupied=%06o free=%06o; "
              "OFF occupied=%06o free=%06o; delta=%+d decimal" %
              (phase, on_o, on_f, off_o, off_f, on_f - off_f))
        if phase == "B":
            assert on_f > off_f, \
                "PURE had no measured six-PACKED free-word advantage"
    print("PASS v1639: source-identical six-owner 48K physical net-free snapshots")
    print("v1639: transient peak RAM and end-to-end throughput still unmeasured")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("on_case", type=Path)
    p.add_argument("off_case", type=Path)
    p.add_argument("on_trace", type=Path)
    p.add_argument("off_trace", type=Path)
    args = p.parse_args()
    on, off = args.on_case, args.off_case
    paths = (on / "build/kcore.map", off / "build/kcore.map",
             on / "user/init.dxr", off / "user/init.dxr",
             on / "user/init-v1614.c", off / "user/init-v1614.c",
             args.on_trace, args.off_trace)
    try:
        data = [path.read_bytes() if i in (2, 3) else
                path.read_text(encoding="ascii")
                for i, path in enumerate(paths)]
        audit(*data)
    except (AssertionError, KeyError, UnicodeError, ValueError) as exc:
        p.exit(1, "FAIL v1639 matched physical six-child audit: %s\n" % exc)


if __name__ == "__main__":
    main()

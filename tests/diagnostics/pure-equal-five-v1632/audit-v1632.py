#!/usr/bin/env python3
"""Measure source-identical five-child PURE-ON/OFF physical RAM.

Both snapshots include a live parent and five sleeping children.
One is pre-sixth-RUN PURE-OFF; the other is post-refusal PACKED ON.
The physical free difference is therefore a sampled net, NOT peak.
"""

import argparse
from pathlib import Path
import runpy


def aligned_gap(low, high, extents):
    cursor = low
    best = 0
    for start, end, _, _, _ in extents + [(high, high, 0, 0, 0)]:
        assert cursor <= start, "overlapping physical MM extent"
        aligned = (cursor + 0o1777) & ~0o1777
        best = max(best, max(0, start - aligned))
        cursor = end
    return best


def audit(on_case, off_case, on_trace, off_trace, scripts):
    off_code = runpy.run_path(str(scripts / "pure-capacity-baseline-v1631" /
                                "audit-v1631.py"))
    on_code = runpy.run_path(str(scripts / "pure-packed-lifecycle-v1629" /
                               "audit-v1629.py"))
    for name in ("user/init.dxr", "user/init-v1614.c",
                 "build/kcore.map"):
        assert (on_case / name).read_bytes() == \
            (off_case / name).read_bytes(), "not a matched guest: " + name
    on_kinit = (on_case / "build/kinit.map").read_text(encoding="ascii")
    off_kinit = (off_case / "build/kinit.map").read_text(encoding="ascii")
    assert "proc_pure_mres_package_v1612" in on_kinit
    assert "proc_pure_mres_package_v1612" not in off_kinit
    assert "MEM                                  48 K" in on_trace
    assert "MEM                                  48 K" in off_trace
    assert "PURE                              LOADED" in on_trace
    assert "PURE                              LOADED" not in off_trace
    assert "aaaaax[BV1629_STAGE_B" in on_trace
    assert "aaaaaV1632_FIVE_READY" in off_trace
    assert "!u" in off_trace and "HALT instruction" in off_trace
    assert "LwwwwwZ" in on_trace and "HALT instruction" in on_trace
    kmap = (on_case / "build/kcore.map").read_text(encoding="ascii")
    on_symbols = on_code["parse_symbols"](kmap)
    on_extents, on_occupied, on_free = on_code["stage_owners"](
        on_trace, on_symbols, "B")
    assert len(on_extents) == 0o22
    packed = [(start, end, pin, owner) for start, end, kind, pin, owner
              in on_extents if kind == 4]
    process_on = [owner for _, _, kind, _, owner in on_extents
                  if kind == 1]
    assert len(packed) == 5
    assert {owner for _, _, _, owner in packed} == set(range(2, 7))
    assert all(end - start == 0o7000 and pin == 0
               for start, end, pin, owner in packed)
    assert process_on == [1]
    assert on_occupied == 0o57023 and on_free == 0o16173
    best_on = aligned_gap(0o42562, 0o140000, on_extents)
    assert best_on == 0o7000

    off_symbols = off_code["symbols"](kmap)
    low, high, count, off_process, off_occupied, off_free, best_off = (
        off_code["decode_off"](
            off_trace, off_symbols, "V1632_FIVE_READY",
            "V1632_END_FIVE", 6))
    assert (low, high) == (0o37224, 0o140000)
    assert {owner for _, _, _, owner in off_process} == set(range(1, 7))
    on_total = (0o140000 - 0o42562)
    off_total = high - low
    assert on_total == on_occupied + on_free
    assert off_total == off_occupied + off_free
    mres = off_total - on_total
    assert mres == 0o3336  # exact installed 1758 decimal-word MRES
    net = on_free - off_free

    print("PASS v1632: same INIT DXR, KCORE map, five sleeping children")
    print("v1632 ON: arena 042562..140000, packed=5, resident=1")
    print("v1632 ON: occupied=%06o free=%06o best_aligned=%06o" %
          (on_occupied, on_free, best_on))
    print("v1632 OFF: arena %06o..%06o, packed=0, resident=6 extents=%o" %
          (low, high, count))
    print("v1632 OFF: occupied=%06o free=%06o best_aligned=%06o" %
          (off_occupied, off_free, best_off))
    print("v1632 installed PURE MRES cost=%06o octal (%d decimal)" %
          (mres, mres))
    print("v1632 sampled net free ON-OFF=%+d decimal (%+o octal)" %
          (net, net))
    print("v1632: source histories differ by rejected sixth RUN; not peak")
    print("v1632: contiguous-APR admission can still regress with more free")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pure_on_case", type=Path)
    parser.add_argument("pure_off_case", type=Path)
    parser.add_argument("on_physical_BAZ_trace", type=Path)
    parser.add_argument("off_physical_five_trace", type=Path)
    args = parser.parse_args()
    try:
        audit(args.pure_on_case, args.pure_off_case,
              args.on_physical_BAZ_trace.read_text(encoding="ascii"),
              args.off_physical_five_trace.read_text(encoding="ascii"),
              Path(__file__).resolve().parent.parent)
    except (AssertionError, UnicodeError) as e:
        parser.exit(1, "FAIL v1632 equal-five MM audit: %s\n" % e)


if __name__ == "__main__":
    main()

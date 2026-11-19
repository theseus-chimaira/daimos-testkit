#!/usr/bin/env python3
"""Audit matched PURE-on/off 48K process-admission and MM capacity.

Only source-identical guest/KCORE and actual SIMH owner snapshots count.
The compared stages contain different live child counts, so no claim
of an equal-load whole-system RAM saving is made here.
"""

import argparse
from pathlib import Path
import re


def symbols(text):
    result = {}
    for line in text.splitlines():
        p = line.split()
        if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
            result[p[0]] = int(p[1], 8)
    for key in ("mm_arenas", "mm_arena_count", "mm_extents",
                "mm_extent_count", "proc_current_slot",
                "proc_high_slot", "proc_slots"):
        assert key in result, "missing original KCORE symbol " + key
    return result


def decode_off(trace, mmap, marker="V1631_SIX_RUN_ACCEPTED",
               last="V1631_END_SIX_RUN", expected_owners=7):
    head, tail = marker + "\n", last + "\n"
    assert trace.count(head) == 1 and trace.count(tail) == 1
    segment = trace.split(head, 1)[1].split(tail, 1)[0]
    words = {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", segment)}

    def get(key):
        address = mmap[key]
        assert address in words, "missing physical word %06o" % address
        return words[address]

    assert get("mm_arena_count") == 1
    assert get("proc_current_slot") == 1
    assert get("proc_slots") == 0o14
    arena = get("mm_arenas")
    low, size = arena & 0o777777, (arena >> 18) & 0o777777
    high = low + size
    assert (low, high) == (0o37224, 0o140000), \
        "original PURE-disabled managed arena changed"
    n = get("mm_extent_count")
    assert 1 <= n <= 48
    extents = []
    for i in range(n):
        a = mmap["mm_extents"] + 2 * i
        assert a in words and a + 1 in words
        span, meta = words[a], words[a + 1]
        start = span & 0o777777
        length = (span >> 18) & 0o777777
        kind = (meta >> 18) & 0o7
        pin = (meta >> 21) & 0o377
        owner = meta & 0o777777
        assert length and kind in (1, 2, 3, 4)
        assert low <= start and start + length <= high
        extents.append((start, start + length, kind, pin, owner))
    assert extents == sorted(extents), "physical owners unsorted"
    cursor = low
    total_free = 0
    best = 0
    for start, end, _, _, _ in extents + [(high, high, 0, 0, 0)]:
        assert cursor <= start, "overlapping physical extents"
        total_free += start - cursor
        aligned = (cursor + 0o1777) & ~0o1777
        best = max(best, max(0, start - aligned))
        cursor = end
    process = [(start, end, pin, owner)
               for start, end, kind, pin, owner in extents if kind == 1]
    assert not any(kind == 4 for _, _, kind, _, _ in extents), \
        "PURE disabled guest has PACKED owner"
    assert {owner for _, _, _, owner in process} == set(
        range(1, expected_owners + 1)), \
        "live parent/children not all resident"
    assert all(end - start == 0o10000 and pin == 0
               for start, end, pin, owner in process), \
        "unexpected original process APR geometry"
    occupied = sum(end - start for start, end, _, _, _ in extents)
    assert occupied + total_free == size
    return (low, high, len(extents), process, occupied, total_free, best)


def audit(on, off, snapshot):
    assert (on / "user/init.dxr").read_bytes() == \
        (off / "user/init.dxr").read_bytes(), "guest DXRs differ"
    assert (on / "user/init-v1614.c").read_bytes() == \
        (off / "user/init-v1614.c").read_bytes(), "guest C source differs"
    assert (on / "build/kcore.map").read_bytes() == \
        (off / "build/kcore.map").read_bytes(), "KCORE maps differ"
    on_kinit = (on / "build/kinit.map").read_text(encoding="ascii")
    off_kinit = (off / "build/kinit.map").read_text(encoding="ascii")
    assert "proc_pure_mres_package_v1612" in on_kinit
    assert "proc_pure_mres_package_v1612" not in off_kinit
    on_guest = (on / "console.clean").read_text(encoding="ascii")
    off_guest = (off / "console.clean").read_text(encoding="ascii")
    assert "PURE                              LOADED" in on_guest
    assert "PURE                              LOADED" not in off_guest
    assert "MEM                                  48 K" in on_guest
    assert "MEM                                  48 K" in off_guest
    assert "aaaaax[B" in on_guest and "LwwwwwZ" in on_guest
    assert "aaaaa!uwwwwww" in off_guest, \
        "PURE-disabled sixth RUN must actually succeed"
    assert "HALT instruction" in on_guest
    assert "HALT instruction" in off_guest
    assert "aaaaa!u" in snapshot
    assert "PURE                              LOADED" not in snapshot
    assert "HALT instruction" in snapshot
    low, high, n, process, occupied, free, best = decode_off(
        snapshot, symbols((off / "build/kcore.map").read_text(
            encoding="ascii")))
    print("PASS v1631: compiled guest/DXR and linked KCORE match exactly")
    print("PASS v1631: same 48K guest, PURE ON sixth RUN refused, OFF admitted")
    print("v1631 PURE-OFF MM arena %06o..%06o extents=%o" % (low, high, n))
    print("v1631 PURE-OFF six children + parent PROCESS owners: ")
    for start, end, pin, owner in process:
        print("  owner %03o: %06o..%06o pin=%o" %
              (owner, start, end, pin))
    print("v1631 PURE-OFF occupied=%06o free=%06o max_aligned=%06o" %
          (occupied, free, best))
    print("v1631: equal-load transient peak and net RAM still unmeasured")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pure_on_case", type=Path)
    parser.add_argument("pure_off_case", type=Path)
    parser.add_argument("pure_off_physical_trace", type=Path)
    args = parser.parse_args()
    try:
        audit(args.pure_on_case, args.pure_off_case,
              args.pure_off_physical_trace.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1631 matched physical admission: %s\n" % exc)


if __name__ == "__main__":
    main()

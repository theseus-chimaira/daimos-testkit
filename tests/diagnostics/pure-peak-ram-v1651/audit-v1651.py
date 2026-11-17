#!/usr/bin/env python3
"""Exact occupied/free MM arena snapshots from accepted v1643 PDP-6 48K.

The original source-linked v1638/v1643 owner and read-failure checks
run separately. This auditor checks the physical MM occupancy, dynamic
allocations and contiguity at six untouched original checkpoints.
It DOES NOT claim a continuous peak monitor or 32K/64K acceptance.
"""

from pathlib import Path
import runpy
import sys


EXPECTED_V1651 = {
    # phase: (occupied decimal, free decimal, extent count,
    #         PROCESS count, PACKED count, KERNEL_DYNAMIC count)
    "B": (27163, 4212, 20, 1, 6, 13),
    "A": (27163, 4212, 20, 1, 6, 13),
    "FULL_PINNED": (27668, 3707, 20, 2, 5, 13),
    "ROLLED_BACK": (23572, 7803, 19, 1, 5, 13),
    "LATER_FULL": (27668, 3707, 20, 2, 5, 13),
    "Z": (4958, 26417, 8, 1, 0, 7),
}


def one_phase(trace, syms, stage, phase):
    words, extents = stage(trace, syms, phase)
    count = words[syms["mm_extent_count"]]
    assert count == len(extents)
    count_arenas = words[syms["mm_arena_count"]]
    assert count_arenas == 1, (phase, "not the original single arena")
    original = words[syms["mm_arenas"]]
    lo = original & 0o777777
    hi = lo + (original >> 18)
    assert (lo, hi) == (0o42561, 0o140000), (phase, "changed managed arena")
    assert hi - lo == 31375
    occupied = 0
    gaps = []
    prev = lo
    by_kind = {1: 0, 2: 0, 3: 0, 4: 0}
    words_by_kind = {1: 0, 2: 0, 3: 0, 4: 0}
    for start, end, kind, pin, owner in extents:
        assert lo <= prev <= start < end <= hi
        assert pin >= 0
        if prev < start:
            gaps.append((prev, start))
        size = end - start
        occupied += size
        by_kind[kind] += 1
        words_by_kind[kind] += size
        prev = end
    if prev < hi:
        gaps.append((prev, hi))
    free = sum(end - start for start, end in gaps)
    largest = max((end - start for start, end in gaps), default=0)
    aligned = max((max(0, end - ((start + 0o1777) & ~0o1777))
                   for start, end in gaps), default=0)
    actual = (occupied, free, count, by_kind[1], by_kind[4], by_kind[3])
    assert actual == EXPECTED_V1651[phase], (phase, actual)
    assert occupied + free == hi - lo
    assert by_kind[2] == 0
    assert words_by_kind[1] == by_kind[1] * 0o10000
    assert words_by_kind[4] == by_kind[4] * 0o6600
    # Preserve the original process geometry and pin truth, not only
    # the sum of occupied words. FULL uses two pins on ONE owner.
    owned = [(start, end, kind, pin, owner)
             for start, end, kind, pin, owner in extents
             if kind in (1, 4)]
    assert sum(owner == 1 and kind == 1 and pin == 0
               and start == 0o130000 and end == 0o140000
               for start, end, kind, pin, owner in owned) == 1
    if phase in ("B", "A"):
        assert {(kind, pin, owner) for _, _, kind, pin, owner in owned
                if owner != 1} == {(4, 0, owner) for owner in range(2, 8)}
    elif phase in ("FULL_PINNED", "LATER_FULL"):
        pairs = [(kind, pin, owner, end - start)
                 for start, end, kind, pin, owner in owned if pin]
        assert len(pairs) == 2
        assert {(kind, pin) for kind, pin, _, _ in pairs} == {(1, 1), (4, 1)}
        assert len({owner for _, _, owner, _ in pairs}) == 1
        assert {size for _, _, _, size in pairs} == {0o10000, 0o6600}
    elif phase == "ROLLED_BACK":
        assert all(pin == 0 for _, _, _, pin, _ in owned)
    else:
        assert len(owned) == 1
    if phase in ("B", "A"):
        assert words_by_kind[3] == 2331
    elif phase in ("FULL_PINNED", "ROLLED_BACK", "LATER_FULL"):
        assert words_by_kind[3] == 2196
    else:
        assert words_by_kind[3] == 862
    return {"occupied": occupied, "free": free, "largest": largest,
            "aligned": aligned, "kdynamic": words_by_kind[3],
            "process": words_by_kind[1], "packed": words_by_kind[4],
            "extents": extents, "words": words}


def audit(kmap, trace, testkit):
    kit = Path(testkit)
    old = runpy.run_path(str(kit /
        "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    symbols = old["symbols"](Path(kmap).read_text(encoding="ascii"))
    actual_trace = Path(trace).read_text(encoding="ascii")
    assert "MEM                                  48 K" in actual_trace
    assert "PURE                              LOADED" in actual_trace
    assert "DTFS                              LOADED" in actual_trace
    assert "HALT instruction, PC: 000000" in actual_trace
    normalized = actual_trace.replace("V1643_", "V1638_")
    stages = {}
    for phase in EXPECTED_V1651:
        stages[phase] = one_phase(normalized, symbols, old["stage"], phase)
        item = stages[phase]
        print("v1651 %-12s occupied=%5d free=%5d largest=%4d "
              "aligned=%4d dynamic=%4d" %
              (phase, item["occupied"], item["free"],
               item["largest"], item["aligned"], item["kdynamic"]))

    before, pinned = stages["A"], stages["FULL_PINNED"]
    rolled, next_full, ended = (stages["ROLLED_BACK"],
                                stages["LATER_FULL"], stages["Z"])
    assert before["process"] == 4096
    assert before["packed"] == 6 * 3456
    assert pinned["process"] == 2 * 4096
    assert pinned["packed"] == 5 * 3456
    assert pinned["kdynamic"] == before["kdynamic"] - 135
    assert pinned["occupied"] - before["occupied"] == \
        4096 - 3456 - 135 == 505
    assert pinned["occupied"] == next_full["occupied"]
    assert pinned["free"] == next_full["free"]
    assert rolled["free"] - pinned["free"] == 4096
    assert pinned["largest"] == 883 and pinned["aligned"] == 640
    assert pinned["largest"] < 0o2000
    assert ended["packed"] == 0 and ended["process"] == 4096
    assert ended["free"] == 26417
    print("v1651: observed max checkpoint occupancy=27668/31375 MM words")
    print("v1651: full checkpoint has 3707 free, max raw gap 883, "
          "max 02000-aligned remainder 640")
    print("v1651: six PACKED to FULL delta=4096-3456-135=+505 words")
    print("PASS v1651: source-linked 48K sampled MM occupancy/fragmentation")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: audit-v1651.py kcore.map trace.clean testkit")
    try:
        audit(*sys.argv[1:])
    except (AssertionError, ValueError, OSError, KeyError) as error:
        print("FAIL v1651 physical RAM accounting: %s" % error,
              file=sys.stderr)
        sys.exit(1)

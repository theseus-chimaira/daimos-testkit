#!/usr/bin/env python3
"""Read exact original PDP-6 64K B/A/Z MM descriptors for nine children.

No simulator deposit, invented MM count or host computed process map is
accepted. A valid lifecycle alone does not establish PACKED ownership.
"""

from pathlib import Path
import re
import runpy
import sys


def symbols(text):
    result = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
            result[parts[0]] = int(parts[1], 8)
    return result


def stage(trace, names, phase):
    first, last = ("V1652_STAGE_%s\n" % phase,
                   "V1652_END_%s\n" % phase)
    assert trace.count(first) == trace.count(last) == 1
    segment = trace.split(first, 1)[1].split(last, 1)[0]
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", segment)}
    for key in ("proc_current_slot", "proc_high_slot", "mm_extent_count",
                "mm_arena_count", "mm_arenas", "mm_extents",
                "vfs_namespace_root"):
        assert names[key] in words, (phase, key)
    assert words[names["proc_current_slot"]] == 1
    assert words[names["mm_arena_count"]] == 1
    assert words[names["vfs_namespace_root"]] >> 24 == (7 << 6) | 1
    arena = words[names["mm_arenas"]]
    lo = arena & 0o777777
    hi = lo + (arena >> 18)
    assert 0o40000 <= lo < hi == 0o200000
    count = words[names["mm_extent_count"]]
    assert 1 <= count <= 48
    prev = lo
    extents = []
    free = 0
    largest = 0
    for index in range(count):
        address = names["mm_extents"] + 2 * index
        assert address in words and address + 1 in words
        span, meta = words[address], words[address + 1]
        base, size = span & 0o777777, span >> 18
        kind = (meta >> 18) & 7
        pin = (meta >> 21) & 255
        owner = meta & 0o777777
        assert kind in (1, 2, 3, 4)
        assert 0 < size and prev <= base and base + size <= hi
        gap = base - prev
        largest = max(largest, gap)
        free += gap
        prev = base + size
        extents.append((base, prev, kind, pin, owner))
    largest = max(largest, hi - prev)
    free += hi - prev
    occupied = sum(end - start for start, end, _, _, _ in extents)
    assert occupied + free == hi - lo
    assert len(extents) == count
    return lo, hi, free, largest, extents


def audit(build, source, trace, testkit):
    build, source, trace, testkit = (Path(p) for p in
                                      (build, source, trace, testkit))
    txt = trace.read_text(encoding="ascii")
    assert "MEM                                  64 K" in txt
    assert "PURE                              LOADED" in txt
    assert "DTFS                              LOADED" in txt
    assert "HALT instruction, PC: 000000" in txt
    assert "aaaaaaaaax[B" in txt
    assert "LwwwwwwwwwZ" in txt
    assert "#define P14_CHILDREN         9U" in source.read_text(encoding="ascii")
    names = symbols((build / "kcore.map").read_text(encoding="ascii"))
    original = runpy.run_path(str(testkit /
        "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    image = original["dxr_words"]((build.parent / "user/init.dxr").read_bytes())
    compressed = original["dxr_words"](
        (build.parent / "user/comp-v1638.dxr").read_bytes())
    assert image[2] == compressed[2]
    text = compressed[2] >> 18
    skip = (text + 0o20) & ~0o177
    raw_size = 0o10000 - skip
    assert 0 < raw_size < 0o10000
    sections = dict((phase, stage(txt, names, phase))
                    for phase in ("B", "A", "Z"))
    original_children = {}
    for phase in ("B", "A"):
        lo, hi, free, largest, extents = sections[phase]
        children = [(start, end, kind, pin, owner)
                    for start, end, kind, pin, owner in extents
                    if kind in (1, 4) and 2 <= owner <= 10]
        assert len(children) == 9
        assert {owner for _, _, _, _, owner in children} == set(range(2, 11))
        assert all(pin == 0 and
                   (end - start == (0o10000 if kind == 1 else raw_size))
                   for start, end, kind, pin, owner in children)
        parent = [(start, end, pin)
                  for start, end, kind, pin, owner in extents
                  if kind == 1 and owner == 1]
        assert len(parent) == 1 and parent[0][1] - parent[0][0] == 0o10000
        assert parent[0][2] == 0
        original_children[phase] = children
        print("v1652 %s: arena %06o..%06o free=%d maxgap=%d "
              "PACKED=%d PROCESS=%d" %
              (phase, lo, hi, free, largest,
               sum(kind == 4 for _, _, kind, _, _ in children),
               sum(kind == 1 for _, _, kind, _, _ in children)))
    assert original_children["B"] == original_children["A"]
    assert any(kind == 4 for _, _, kind, _, _ in original_children["B"]), \
        "64K lifecycle ran without actual RAW PACKED owners"

    lo, hi, free, largest, extents = sections["Z"]
    assert not [1 for _, _, kind, _, owner in extents
                if kind in (1, 4) and 2 <= owner <= 10]
    assert any(kind == 1 and owner == 1 and pin == 0
               and end - start == 0o10000
               for start, end, kind, pin, owner in extents)
    print("v1652 Z: arena %06o..%06o free=%d maxgap=%d" %
          (lo, hi, free, largest))
    print("v1652: original compressed PURE text=%06o skip=%06o RAW=%06o" %
          (text, skip, raw_size))
    print("PASS v1652: real 64K nine-child physical PACKED owners and WAIT cleanup")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: audit-mm-v1652.py build source trace testkit")
    try:
        audit(*sys.argv[1:])
    except (AssertionError, KeyError, OSError, ValueError) as err:
        print("FAIL v1652 physical 64K MM owner audit: %s" % err,
              file=sys.stderr)
        sys.exit(1)

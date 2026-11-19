#!/usr/bin/env python3
"""Forge three harmless test-only physical MM accounting witnesses."""

from pathlib import Path
import re
import runpy
import sys


def change_word(text, address, old, new):
    original = "%o:\t%012o" % (address, old)
    changed = "%o:\t%012o" % (address, new)
    assert text.count(original) == 1, ("missing exact physical word", original)
    return text.replace(original, changed, 1)


def main(testkit, kmap, trace, output):
    testkit, kmap, trace, output = map(Path, (testkit, kmap, trace, output))
    kit = runpy.run_path(str(testkit /
        "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    names = kit["symbols"](kmap.read_text(encoding="ascii"))
    source = trace.read_text(encoding="ascii")
    first, last = "V1643_STAGE_FULL_PINNED\n", "V1643_END_FULL_PINNED\n"
    assert source.count(first) == source.count(last) == 1
    before, remaining = source.split(first, 1)
    block, after = remaining.split(last, 1)
    words = {int(addr, 8): int(value, 8)
             for addr, value in re.findall(
                 r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", block)}
    assert words[names["mm_arena_count"]] == 1
    arena_addr = names["mm_arenas"]
    arena = words[arena_addr]
    assert (arena & 0o777777) == 0o42561
    altered = change_word(block, arena_addr, arena,
                          (((arena >> 18) + 1) << 18) | 0o42560)
    output.mkdir(parents=True, exist_ok=True)
    (output / "false-arena-v1651.trace").write_text(
        before + first + altered + last + after, encoding="ascii")

    candidate = []
    target = []
    count = words[names["mm_extent_count"]]
    for index in range(count):
        address = names["mm_extents"] + 2 * index
        span, meta = words[address], words[address + 1]
        kind = (meta >> 18) & 7
        pin = (meta >> 21) & 255
        owner = meta & 0o777777
        size = span >> 18
        if kind == 3 and size == 0o201:
            candidate.append((address, span))
        if kind == 1 and pin == 1 and owner == 3 and size == 0o10000:
            target.append((address + 1, meta))
    assert len(candidate) == len(target) == 1
    address, span = candidate[0]
    shortened = change_word(block, address, span, span - (1 << 18))
    (output / "false-dynamic-v1651.trace").write_text(
        before + first + shortened + last + after, encoding="ascii")
    address, meta = target[0]
    unpinned = change_word(block, address, meta, meta - (1 << 21))
    (output / "false-full-pin-v1651.trace").write_text(
        before + first + unpinned + last + after, encoding="ascii")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: mutate-v1651.py testkit kcore.map trace outdir")
    main(*sys.argv[1:])

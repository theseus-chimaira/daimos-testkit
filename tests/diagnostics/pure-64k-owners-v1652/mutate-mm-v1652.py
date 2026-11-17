#!/usr/bin/env python3
"""Generate independently invalid copies of a physical 64K MM trace.

Do not edit production code or the original accepted simulator trace.
"""

from pathlib import Path
import re
import sys


def main(kmap, trace, outdir):
    kmap, trace, outdir = map(Path, (kmap, trace, outdir))
    outdir.mkdir(parents=True, exist_ok=True)
    names = {}
    for line in kmap.read_text(encoding="ascii").splitlines():
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
            names[parts[0]] = int(parts[1], 8)
    text = trace.read_text(encoding="ascii")
    first, last = "V1652_STAGE_B\n", "V1652_END_B\n"
    assert text.count(first) == text.count(last) == 1
    prefix, remainder = text.split(first, 1)
    original, suffix = remainder.split(last, 1)
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", original)}
    count = words[names["mm_extent_count"]]
    packed = []
    for i in range(count):
        addr = names["mm_extents"] + 2 * i
        span, meta = words[addr], words[addr + 1]
        if ((meta >> 18) & 7 == 4 and
                (meta & 0o777777) in range(2, 11)):
            packed.append((addr + 1, span, meta))
    assert packed, "no original PACKED owner"
    address, span, meta = packed[0]
    old = "%o:\t%012o" % (address, meta)
    new = "%o:\t%012o" % (address, meta - 3 * (1 << 18))
    assert original.count(old) == 1
    bad = original.replace(old, new, 1)
    (outdir / "false-packed-kind-v1652.trace").write_text(
        prefix + first + bad + last + suffix, encoding="ascii")

    wrong = next(((a, s, m) for a, s, m in packed
                  if (m & 0o777777) != 2), None)
    assert wrong is not None
    address, span, meta = wrong
    old = "%o:\t%012o" % (address, meta)
    new = "%o:\t%012o" % (
        address, (meta & ~0o777777) | 2)
    assert original.count(old) == 1
    bad = original.replace(old, new, 1)
    (outdir / "false-owner-v1652.trace").write_text(
        prefix + first + bad + last + suffix, encoding="ascii")

    marker = "LwwwwwwwwwZ"
    assert text.count(marker) == 1
    (outdir / "false-wait-v1652.trace").write_text(
        text.replace(marker, "LwwwwwwwwwY", 1), encoding="ascii")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: mutate-mm-v1652.py kcore.map trace outdir")
    main(*sys.argv[1:])

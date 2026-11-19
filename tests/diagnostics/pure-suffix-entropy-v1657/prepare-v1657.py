#!/usr/bin/env python3
"""Read-only physical PDP-6 v1654 PACKED suffix capture at six-owner B.

The saved v1654 trace defines the exact six original RAW ownership
intervals. The new independent PDP-6 simulation is forced to match
these source-linked MM dimensions and samples the 36-bit words.
No production instruction or executable image is modified.
"""

from pathlib import Path
import re
import runpy
import sys


def prepare(build, reference, kit, work):
    build, reference, kit, work = map(Path, (build, reference, kit, work))
    work.mkdir(parents=True, exist_ok=True)
    old = runpy.run_path(str(kit /
        "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    syms = old["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    reference_text = reference.read_text(encoding="ascii")
    words, extents = old["stage"](reference_text.replace(
        "V1643_", "V1638_"), syms, "B")
    assert words[syms["proc_current_slot"]] == 1
    packed = [(a, b, owner) for a, b, kind, pin, owner in extents
              if kind == 4]
    assert len(packed) == 6
    assert {owner for _, _, owner in packed} == set(range(2, 8))
    assert all(b - a == 0o6600 for a, b, _ in packed)
    assert all(pin == 0 for _, _, kind, pin, _ in extents if kind == 4)

    ini = (build / "boot.ini").read_text(encoding="ascii")
    assert ini.count("set cpu 48k\n") == 1
    (work / "media").mkdir(exist_ok=True)
    for unit in range(4):
        match = re.findall(r"(?m)^attach -q dtc%d (.+)$" % unit, ini)
        assert len(match) == 1
        dest = work / "media" / ("dtc%d.tap" % unit)
        dest.write_bytes(Path(match[0]).read_bytes())
        ini = ini.replace(match[0], str(dest))
    # No test requires auxiliary/drum providers. The original selected
    # TSFS root and genuine independent DTC3 media are unmodified.
    ini = "\n".join(s for s in ini.splitlines() if not
                    s.startswith(("attach -q dsk", "attach -q dr"))) + "\n"
    assert ini.count("go 020\nexit\n") == 1
    head = ini.replace("go 020\nexit\n", "")
    tail = 'expect "aaaaaax[B"\ngo 020\n'
    for a, b, slot in sorted(packed, key=lambda item: item[2]):
        tail += "echo V1657_BEGIN_SLOT_%d\n" % slot
        tail += "examine %06o-%06o\n" % (a, b - 1)
        tail += "echo V1657_END_SLOT_%d\n" % slot
    tail += 'expect "Z"\ncont\necho V1657_FINISHED_Z\ncont\nexit\n'
    (work / "sample.ini").write_text(head + tail, encoding="ascii")
    (work / "intervals-v1657.txt").write_text(
        "".join("%d %06o %06o\n" % (slot, a, b)
                for a, b, slot in sorted(packed, key=lambda x: x[2])),
        encoding="ascii")
    print("v1657: prepared six genuine source-derived PACKED 006600 suffixes")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: prepare-v1657.py build trace kit outdir")
    prepare(*sys.argv[1:])

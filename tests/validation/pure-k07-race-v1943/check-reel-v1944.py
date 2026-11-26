#!/usr/bin/env python3
"""Read-only verification of the retired native DTVOL2 COMP executable."""
import argparse
from pathlib import Path
import runpy
import struct

HERE = Path(__file__).resolve().parent
seal = runpy.run_path(str(HERE.parent.parent /
                         "diagnostics/pure-quiesce-run-v1646/check-v2-v1647.py"))["check"]
WORD = (1 << 36) - 1
HALF = (1 << 18) - 1
BLOCKS = 0o1102
DIR = 0o144
DATA = 0o177
NAME = 0o123


def read_reel(path):
    raw = path.read_bytes()
    assert len(raw) == BLOCKS * 128 * 8, "unexpected physical reel length"
    halves = struct.iter_unpack("<II", raw)
    return [(hi & HALF) << 18 | (lo & HALF) for hi, lo in halves]


def sixbit(s):
    w = 0
    for c in s.ljust(6):
        w = (w << 6) | (ord(c) - 32)
    return w


def verify(original, retired, expected):
    seal(original)
    seal(retired)
    old = read_reel(original)
    reel = read_reel(retired)
    assert old[:6] == reel[:6], "volume identity/seal changed"
    directory = reel[DIR * 128:(DIR + 1) * 128]
    assert directory[0o177] == 0o446446632021, "native directory magic"
    slots = [i for i in range(22) if directory[NAME+2*i] != 0]
    assert len(slots) == 1, "unexpected directory contents"
    slot = slots[0]
    assert directory[NAME+2*slot] == sixbit("COMP")
    assert directory[NAME+2*slot+1] >> 6 == 0, "unexpected second name word"
    assert directory[slot] & 1, "COMP not executable"
    tail = (directory[NAME+2*slot+1] & 0o77) | ((directory[0o26+slot] & 1) << 6)
    assert 1 <= tail <= DATA
    # Native owner map uses the physical RBN, unlike TENEX.
    def owner(rbn):
        return (directory[rbn // 7] >> (31 - 5*(rbn % 7))) & 0o37
    owned = {rbn for rbn in range(1, BLOCKS) if owner(rbn) == slot+1}
    assert owned and DIR not in owned
    def block(rbn):
        return reel[128*rbn:128*(rbn+1)]
    starts = [rbn for rbn in owned if (block(rbn)[0] >> 8) & 0o1777 == rbn]
    assert len(starts) == 1, "missing or ambiguous first block"
    first = rbn = starts[0]
    seen, payload = set(), []
    while rbn:
        assert rbn in owned and rbn not in seen, "foreign or cyclic block"
        seen.add(rbn)
        row = block(rbn)
        header = row[0]
        count = header & 0o377
        nxt = (header >> 18) & 0o1777
        assert (header >> 8) & 0o1777 == first
        assert header >> 28 == 0, "reserved header bits"
        assert count == (DATA if nxt else tail), "native count mismatch"
        payload.extend(row[1:count+1])
        rbn = nxt
    assert seen == owned, "unreachable owned blocks"
    raw = expected.read_bytes()
    assert len(raw) % 8 == 0
    wanted = [x[0] for x in struct.iter_unpack("<Q", raw)]
    assert all(x <= WORD for x in wanted)
    assert payload == wanted, "compressed executable data differs"
    print("PASS v1944: same sealed CLEAN DTVOL2, executable COMP, "
          "%d exact words in %d owned blocks" % (len(payload), len(seen)))
    return first, len(seen)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for name in ("original", "retired", "expected"):
        p.add_argument(name, type=Path)
    a = p.parse_args()
    try:
        verify(a.original, a.retired, a.expected)
    except (AssertionError, OSError, ValueError) as exc:
        p.exit(1, "FAIL v1944 physical reel: %s\n" % exc)

#!/usr/bin/env python3
"""Verify the current source-built physical FULL trace, not historical PCs."""
import argparse
import hashlib
from pathlib import Path
import re
import runpy
import subprocess

replay = runpy.run_path(str(Path(__file__).with_name("replay-v1941.py")))
symbols, words = replay["symbols"], replay["words"]


def section(trace, label):
    start, end = "V1941_STAGE_" + label, "V1941_END_" + label
    assert trace.count(start) == trace.count(end) == 1, label
    return trace.split(start, 1)[1].split(end, 1)[0]


def extents(snap, sym, core=48):
    count = snap[sym["mm_extent_count"]]
    capacity = snap[sym["mm_extent_capacity"]]
    na = snap[sym["mm_arena_count"]]
    assert 0 < count <= capacity <= 136, "invalid MM extent capacity"
    assert 1 <= na <= 3, "invalid MM arenas"
    arenas = []
    for i in range(na):
        v = snap[sym["mm_arenas"] + i]
        lo, size = v & 0o777777, v >> 18
        assert size and lo + size <= core*1024, "arena outside physical core"
        arenas.append((lo, lo + size))
    assert arenas == sorted(arenas)
    assert all(a[1] <= b[0] for a, b in zip(arenas, arenas[1:]))
    assert max(b for _, b in arenas) == core*1024
    out = []
    for i in range(count):
        addr = sym["mm_extents"] + 2*i
        span, meta = snap[addr], snap[addr+1]
        lo, size = span & 0o777777, span >> 18
        kind, pin = (meta >> 18) & 7, (meta >> 21) & 255
        owner = meta & 0o777777
        assert size and kind in (1, 2, 3, 4), "invalid typed extent"
        assert any(a <= lo and lo + size <= b for a, b in arenas)
        out.append((lo, lo + size, kind, pin, owner))
    assert out == sorted(out)
    assert all(a[1] <= b[0] for a, b in zip(out, out[1:])), "MM overlap"
    return out


def check_full(ac, ext, earlier, children=6):
    backing, target, uarea, cap = (ac[i] for i in range(1, 5))
    assert backing and uarea and cap == 0o10000
    assert target % 0o2000 == 0, "misaligned FULL APR"
    dst = [e for e in ext if e[0] == target and e[2] == 1]
    assert len(dst) == 1
    d = dst[0]
    assert d[1]-d[0] == cap and d[3] == 1, "FULL target pin/size"
    slot = d[4]
    assert slot in range(3, children+2), "not a compressed child owner"
    src = [e for e in ext if e[2] == 4 and e[4] == slot]
    assert len(src) == 1
    s = src[0]
    assert s[3] == 1 and s[1]-s[0] == 0o7000, "PACKED source pin/size"
    assert s[1] <= d[0] or d[1] <= s[0], "source/target overlap"
    # The original suffix must retain its exact physical identity,
    # not merely be another allocation carrying the same slot number.
    assert (s[0], s[1], 4, 0, slot) in earlier, "source identity changed"
    assert any(e[0] == uarea and e[1]-e[0] == 0o410 and
               e[2] == 3 and e[4] == 0o1000+slot for e in ext), "u-area owner"
    return slot, s, d


def verify(b, w, prefix, children, core=48):
    sym = symbols(b / "kcore.map")
    mres = symbols(b / "pure-mres-v1612.map")
    trace = (w / "physical.clean").read_text(encoding="ascii")
    hashes = {}
    for line in (w / "images.sha256").read_text().splitlines():
        digest, name = line.split()
        hashes[name] = digest
        assert hashlib.sha256((b / name).read_bytes()).hexdigest() == digest
    assert set(hashes) == {"kcore.dxr", "pure-mres-v1612.dxr",
                           "kinit.lowmem.words"}
    assert "MEM                                  %d K" % core in trace
    assert "PURE                              LOADED" in trace
    assert "a"*children+"x[BV1941_STAGE_B" in trace
    # The FULL breakpoint splits the continuous child-output stream
    # after the plain child exits. Strip only monitor-owned sections,
    # rather than count arbitrary occurrences of "w" in monitor text.
    before_full = trace.split("V1941_OPCODE_END", 1)[1].split(
        "Breakpoint, PC:", 1)[0]
    after_full = trace.split("V1941_END_FULL", 1)[1].split(
        "V1941_STAGE_Z", 1)[0]
    guest = re.sub(r"\s+", "", before_full + after_full)
    assert re.search(r"\]\{[0-7]+-[0-7]+\}L"+"w"*children+"Z$", guest), (
        "checked exits/waits missing")
    assert re.search(r"HALT instruction, PC: 000000", trace), "normal HALT"
    assert trace.count("HALT instruction") == 1
    labels = ("B", "A", "FULL", "Z")
    boundaries = [trace.index("V1941_" + side + "_" + label)
                  for label in labels for side in ("STAGE", "END")]
    assert boundaries == sorted(boundaries)
    snapshots, mm = {}, {}
    for label in labels:
        snapshots[label] = words(section(trace, label))
        assert snapshots[label][sym["mm_extent_capacity"]] == 4*(core//8)+8
        mm[label] = extents(snapshots[label], sym, core)
        assert snapshots[label][sym["proc_exec_resv_head_v1933"]] == 0, (
            "unexpected outstanding executable reservation at " + label)
    for label in ("B", "A", "Z"):
        assert snapshots[label][sym["proc_current_slot"]] == 1
    assert snapshots["FULL"][sym["proc_current_slot"]] == 0
    for label in ("B", "A"):
        packed = [e for e in mm[label] if e[2] == 4]
        assert len(packed) == children
        assert {e[4] for e in packed} == set(range(2, children+2))
        assert all(e[1]-e[0] == 0o7000 and e[3] == 0 for e in packed)
    assert mm["B"] == mm["A"], "no-growth BRK changed physical ownership"

    sb = snapshots["B"]
    service, reclaim = (sb[sym[x]] for x in
                        ("proc_swap_service_one", "proc_swap_reclaim"))
    assert service >> 18 == reclaim >> 18 == 0o254000
    base = (service & 0o777777)-mres["proc_pure_mres_service_v1612"]
    assert base > 0 and (reclaim & 0o777777) == \
        base+mres["proc_pure_mres_reclaim_v1612"]
    full_off = mres["exec_image_full_bounded_v1391"]
    full = base + full_off
    # KINIT mm_boot_reserve removes permanent MRES allocations from
    # the dynamic MM table. Check the reserved low-core interval,
    # not a nonexistent dynamic MODULE descriptor.
    assert base >= sym["__kcore_low_end"]
    dxr = subprocess.check_output(
        [str(prefix / "bin/dxrcheck"), "-d",
         str(b / "pure-mres-v1612.dxr")], text=True)
    hdr = re.search(r"DXR [^\n]*image=([0-7]+) bss=([0-7]+)", dxr)
    size = int(hdr.group(1), 8) + int(hdr.group(2), 8)
    assert 0 <= full_off < size
    for i in range(sb[sym["mm_arena_count"]]):
        span = sb[sym["mm_arenas"]+i]
        lo, hi = span & 0o777777, (span & 0o777777)+(span >> 18)
        assert base+size <= lo or hi <= base, "MRES intersects MM arena"
    opcode = int(re.search(r"(?m)^IMAGE  %06o ([0-7]{12})$" %
                           full_off, dxr).group(1), 8)
    assert trace.count("V1941_OPCODE_END") == 1
    opcode_section = trace.split("V1941_END_A", 1)[1].split(
        "V1941_OPCODE_END", 1)[0]
    assert words(opcode_section)[full] == opcode, "linked entry opcode"
    hit = trace.split("V1941_OPCODE_END", 1)[1].split(
        "V1941_STAGE_FULL", 1)[0]
    assert re.search(r"Breakpoint, PC: %06o\b" % full, hit)
    ac = words(hit.split("V1941_FULL_ENTRY", 1)[1])
    slot, src, dst = check_full(ac, mm["FULL"], mm["A"], children)
    for e in mm["Z"]:
        assert not (e[2] in (1, 4) and 2 <= e[4] <= children+1), "child VM leak"
        assert not (e[2] == 3 and 0o1002 <= e[4] <= 0o1000+children+1), "child u-area leak"
    assert any(e[2] == 1 and e[4] == 1 for e in mm["Z"])
    assert snapshots["Z"][sym["proc_timer_clock"]] > \
        snapshots["B"][sym["proc_timer_clock"]], "no clock progress"
    print("PASS v1941: installed FULL entry %06o opcode %012o" % (full, opcode))
    print("PASS v1941: child %o PACKED %06o..%06o and FULL %06o..%06o" %
          (slot, src[0], src[1], dst[0], dst[1]))
    print("PASS v1941: %d checked waits, no child VM/u-area leak, normal HALT" % children)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for name in ("build", "work", "prefix"):
        p.add_argument(name, type=Path)
    p.add_argument("--children", type=int, choices=(5, 6, 9), required=True)
    p.add_argument("--core", type=int, choices=(48, 64), default=48)
    a = p.parse_args()
    try:
        verify(a.build, a.work, a.prefix, a.children, a.core)
    except (AssertionError, KeyError, ValueError, OSError) as exc:
        p.exit(1, "FAIL v1941 physical FULL verification: %s\n" % exc)

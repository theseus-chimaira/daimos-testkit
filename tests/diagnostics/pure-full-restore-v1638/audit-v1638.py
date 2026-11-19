#!/usr/bin/env python3
"""Audit original PDP-6 FULL relocated PURE restoration and EXIT/WAIT.

Require two simultaneously pinned extents of the SAME process owner at
the actual bounded FULL-loader entry, not merely a claimed code path.
The compressed executable is created from the exact plain guest DXR.
"""

import argparse
from pathlib import Path
import re


def symbols(text):
    out = {}
    for line in text.splitlines():
        f = line.split()
        if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
            out[f[0]] = int(f[1], 8)
    return out


def stage(trace, syms, name):
    first = "V1638_STAGE_%s\n" % name
    last = "V1638_END_%s\n" % name
    assert trace.count(first) == 1 and trace.count(last) == 1
    text = trace.split(first, 1)[1].split(last, 1)[0]
    words = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", text)}
    for name in ("mm_arenas", "mm_arena_count", "mm_extents",
                 "mm_extent_count", "proc_current_slot", "proc_high_slot"):
        assert name in syms and syms[name] in words
    count = words[syms["mm_extent_count"]]
    assert 1 <= count <= 48
    arenas = []
    for i in range(words[syms["mm_arena_count"]]):
        v = words[syms["mm_arenas"] + i]
        lo = v & 0o777777
        arenas.append((lo, lo + (v >> 18)))
    assert max(hi for _, hi in arenas) == 0o140000
    extents = []
    for i in range(count):
        addr = syms["mm_extents"] + i * 2
        assert addr in words and addr + 1 in words
        span, meta = words[addr], words[addr + 1]
        lo, size = span & 0o777777, span >> 18
        kind = (meta >> 18) & 7
        pin = (meta >> 21) & 255
        owner = meta & 0o777777
        assert kind in (1, 2, 3, 4) and size
        assert any(a <= lo and lo + size <= b for a, b in arenas)
        extents.append((lo, lo + size, kind, pin, owner))
    assert extents == sorted(extents)
    assert all(a[1] <= b[0] for a, b in zip(extents, extents[1:])), \
        "overlapping MM ownership"
    return words, extents


def dxr_words(data):
    assert len(data) % 8 == 0
    return [int.from_bytes(data[i:i + 8], "little")
            for i in range(0, len(data), 8)]


def audit(map_text, mres_map, mres_dxrcheck, trace, original_source,
          plain_dxr, compressed_dxr, manifest):
    syms = symbols(map_text)
    mres = symbols(mres_map)
    assert mres["exec_image_full_bounded_v1391"] == 0o3224
    assert mres["proc_pure_ram_restore_v1391"] == 0o2207
    assert mres["mm_pure_commit_prefix_v1384"] == 0o2565
    full_pc = 0o32026 + mres["exec_image_full_bounded_v1391"]
    opcode = re.search(r"(?m)^IMAGE  003224 ([0-7]{12})$",
                       mres_dxrcheck)
    assert opcode, "linked bounded FULL callback missing"
    assert ("%o:\t%s" % (full_pc, opcode.group(1))) in trace, \
        "physical callback opcode differs from compiled PURE MRES"
    assert re.search(r"Breakpoint, PC: %06o " % full_pc, trace), \
        "physical FULL loader callback was never reached"
    assert trace.count("V1638_BOUNDED_FULL\n") == 1
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaax[BV1638_STAGE_B" in trace
    assert "wwwwwwZV1638_STAGE_Z" in trace or \
           "ZV1638_STAGE_Z" in trace
    assert "HALT instruction" in trace

    for required in ("#define P14_CHILDREN         6U",
                     "p14_spawn(rd, i != 0U)",
                     "denied = p14_spawn(rd, 1U);",
                     "(void)p14_char('x');",
                     "p14_compressed_path[3]",
                     "dsys_read_words(0, &word, 1U)",
                     "p14_data[0] != 012345670123UL",
                     "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
                     "dsys_wait((unsigned int)pid[i], &status, 0U)",
                     "SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('Z');"):
        assert required in original_source, "invalid guest source: " + required
    plain, compressed = dxr_words(plain_dxr), dxr_words(compressed_dxr)
    assert (plain[1] & 0o300000) == 0o200000
    assert (compressed[1] & 0o300000) == 0o300000
    assert plain[0] == compressed[0] and plain[2] == compressed[2]
    assert (plain[1] >> 18) == (compressed[1] >> 18)
    assert "F /SYSTEM/COMP " in manifest

    for phase in ("B", "A"):
        _, ext = stage(trace, syms, phase)
        packed = [(a, b, pin, owner)
                  for a, b, kind, pin, owner in ext if kind == 4]
        assert len(packed) == 6
        assert {owner for _, _, _, owner in packed} == set(range(2, 8))
        assert all(b-a == 0o7000 and pin == 0 for a, b, pin, _ in packed)
        assert any((a, b, k, pin, o) == (0o130000, 0o140000, 1, 0, 1)
                   for a, b, k, pin, o in ext)

    # The actual executable's bounded FULL callback receives a new
    # physical APR, allocated and pinned by v1391. AC2 is its base.
    details = trace.split("V1638_BOUNDED_FULL\n", 1)[1].split(
        "V1638_STAGE_FULL\n", 1)[0]
    ac = {int(a, 8): int(b, 8) for a, b in re.findall(
        r"(?m)^\s*([1-4]):\s*([0-7]{1,12})\s*$", details)}
    assert set(ac) == {1, 2, 3, 4}
    target = ac[2]
    assert ac[1] != 0 and ac[3] != 0 and ac[4] == 0o10000
    assert target % 0o2000 == 0 and 0o40000 <= target < 0o130000
    words, ext = stage(trace, syms, "FULL")
    assert words[syms["proc_current_slot"]] == 0, \
        "restore must be performed from scheduler slot zero"
    dst = [(a, b, pin, owner) for a, b, kind, pin, owner in ext
           if kind == 1 and a == target and b - a == 0o10000]
    assert len(dst) == 1 and dst[0][2] >= 1
    slot = dst[0][3]
    assert slot in range(3, 8), "FULL callback did not target compressed child"
    src = [(a, b, pin, owner) for a, b, kind, pin, owner in ext
           if kind == 4 and owner == slot]
    assert len(src) == 1 and src[0][2] >= 1
    assert src[0][1] - src[0][0] == 0o7000
    assert src[0][0] != target + 0o1000, \
        "FULL loader unexpectedly overwrote original writable suffix"
    _, after = stage(trace, syms, "Z")
    assert all(not (kind in (1, 4) and 2 <= owner <= 7)
               for _, _, kind, _, owner in after)
    assert any(a == 0o130000 and b == 0o140000 and kind == 1
               and pin == 0 and owner == 1
               for a, b, kind, pin, owner in after)
    print("v1638: source-matched compressed PURE full loader %06o" % full_pc)
    print("v1638: slot %o pinned PACKED source %06o..%06o" %
          (slot, src[0][0], src[0][1]))
    print("v1638: slot %o separate pinned FULL APR %06o..%06o" %
          (slot, target, target + 0o10000))
    print("PASS v1638: physical FULL relocated callback, owner cleanup and 6 WAITs")
    print("v1638: physical failure-atomic source-loss and peak/net RAM still OPEN")


def main():
    p = argparse.ArgumentParser()
    for name in ("kcore_map", "mres_map", "mres_dxrcheck", "trace",
                 "guest_source", "plain_dxr", "compressed_dxr", "manifest"):
        p.add_argument(name, type=Path)
    args = p.parse_args()
    files = [getattr(args, key) for key in ("kcore_map", "mres_map",
             "mres_dxrcheck", "trace", "guest_source", "plain_dxr",
             "compressed_dxr", "manifest")]
    try:
        items = [(f.read_bytes() if i in (5, 6) else
                  f.read_text(encoding="ascii"))
                 for i, f in enumerate(files)]
        audit(*items)
    except (AssertionError, UnicodeError, KeyError, ValueError) as exc:
        p.exit(1, "FAIL v1638 physical FULL restore audit: %s\n" % exc)


if __name__ == "__main__":
    main()

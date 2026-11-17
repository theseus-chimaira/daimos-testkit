#!/usr/bin/env python3
"""Validate genuine root TSFS I/O failure during 48K RAW FULL restore.

The original v1538 selected-root policy must HALT. It would be wrong
to assert ordinary FULL loader rollback/retry after critical root loss.
"""

import argparse
from pathlib import Path
import re
import runpy


def audit(kmap, mmap, mres_dxr, trace, guest, backing,
          provider, critical):
    h = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                           "pure-full-restore-v1638/audit-v1638.py"))
    syms, ms = h["symbols"](kmap), h["symbols"](mmap)
    assert syms["kcore_root_fs_io_failure_v1538"] == 0o3761
    assert syms["kcore_critical_device_lost_v1515"] == 0o3773
    assert ms["exec_image_full_bounded_v1391"] == 0o3224
    assert "IMAGE  003224 200000000004" in mres_dxr
    assert "kcore_root_fs_io_failure_v1538:" in critical
    assert "jrst    kcore_root_fs_io_halt_v1538" in critical
    assert "kcore_critical_media_root_halt_v1515:" in critical
    assert "halt    ." in critical
    assert "tsfs_read_words_io_error_v1538:" in provider
    assert "pushj   17,kcore_root_fs_io_failure_v1538" in provider
    assert "pushj   17,dtfs_dtc_read" in provider
    assert "pid[i] = p14_spawn(rd, i != 0U);" in guest
    assert "F /SYSTEM/COMP " in backing
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaax[BV1642_STAGE_B" in trace
    assert "[AV1642_STAGE_A" in trace
    for mark in ("V1642_BOUNDED_FULL_PRE_OFFLINE",
                 "V1642_ROOT_FAILURE_CLASSIFIER",
                 "V1642_TERMINAL_ROOT_HALT"):
        assert trace.count(mark + "\n") == 1, mark
    for unit in (0, 1, 2):
        assert trace.count("V1642_DETACHED_DTC%d\n" % unit) == 1
        assert trace.count("V1642_END_DETACH_DTC%d\n" % unit) == 1
    assert trace.index("V1642_END_FULL_PINNED\n") < trace.index(
        "V1642_DETACHED_DTC0\n")
    assert trace.index("V1642_END_DETACH_DTC2\n") < trace.index(
        "V1642_ROOT_FAILURE_CLASSIFIER\n")
    assert trace.index("V1642_ROOT_FAILURE_CLASSIFIER\n") < trace.index(
        "V1642_TERMINAL_ROOT_HALT\n")
    assert "LwwwwwwZ" not in trace, "root loss somehow completed all WAITs"

    def stage(tag):
        # v1642 deliberately snapshots exact original MM descriptors,
        # root identity and scheduler slot. The source-linked optional
        # arena table is checked when recorded; physical 48K bounds and
        # sorted nonoverlap remain mandatory on every snapshot.
        begin = "V1642_STAGE_%s\n" % tag
        end = "V1642_END_%s\n" % tag
        assert trace.count(begin) == 1 and trace.count(end) == 1
        segment = trace.split(begin, 1)[1].split(end, 1)[0]
        words = {int(a, 8): int(b, 8) for a, b in re.findall(
            r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$",
            segment)}
        for name in ("mm_extent_count", "mm_arena_count",
                     "proc_current_slot", "vfs_namespace_root"):
            assert syms[name] in words, "missing source-linked " + name
        count = words[syms["mm_extent_count"]]
        assert 1 <= count <= 48
        assert words[syms["mm_arena_count"]] == 1
        arenas = None
        if syms["mm_arenas"] in words:
            v = words[syms["mm_arenas"]]
            arenas = (v & 0o777777,
                      (v & 0o777777) + (v >> 18))
            assert arenas[1] == 0o140000
        extents = []
        for i in range(count):
            addr = syms["mm_extents"] + 2 * i
            assert addr in words and addr + 1 in words
            span, meta = words[addr], words[addr + 1]
            lo, size = span & 0o777777, span >> 18
            kind = (meta >> 18) & 7
            pin = (meta >> 21) & 255
            owner = meta & 0o777777
            assert kind in (1, 2, 3, 4) and size
            assert 0o40000 <= lo < lo + size <= 0o140000
            if arenas:
                assert arenas[0] <= lo and lo + size <= arenas[1]
            extents.append((lo, lo + size, kind, pin, owner))
        assert extents == sorted(extents)
        assert all(a[1] <= b[0] for a, b in
                   zip(extents, extents[1:])), "overlapping MM owners"
        return words, extents

    for phase in ("B", "A"):
        words, ext = stage(phase)
        assert words[syms["proc_current_slot"]] == 1
        child = [(a, b, kind, pin, owner) for a, b, kind, pin, owner
                 in ext if kind in (1, 4) and 2 <= owner <= 7]
        assert len(child) == 6
        assert {owner for a, b, kind, pin, owner in child} == set(range(2, 8))
        assert all(kind == 4 and b-a == 0o7000 and pin == 0
                   for a, b, kind, pin, owner in child)
        assert any(a == 0o130000 and b == 0o140000 and kind == 1
                   and owner == 1 and pin == 0 for a, b, kind, pin, owner
                   in ext)

    full_words, full_ext = stage("FULL_PINNED")
    assert full_words[syms["proc_current_slot"]] == 0
    owner = [(a, b, kind, pin, o) for a, b, kind, pin, o in full_ext
             if kind in (1, 4) and 3 <= o <= 7 and pin > 0]
    assert len(owner) == 2
    assert owner[0][4] == owner[1][4]
    packed = [v for v in owner if v[2] == 4]
    target = [v for v in owner if v[2] == 1]
    assert len(packed) == len(target) == 1
    assert packed[0][1]-packed[0][0] == 0o7000
    assert target[0][1]-target[0][0] == 0o10000
    assert packed[0][3] == target[0][3] == 1
    assert target[0][1] <= packed[0][0] or packed[0][1] <= target[0][0]
    pc = 0o32026 + ms["exec_image_full_bounded_v1391"]
    assert re.search(r"Breakpoint, PC: %06o " % pc, trace)
    assert ("%o:\t200000000004" % pc) in trace

    failed_words, failed_ext = stage("REAL_IO_FAILURE")
    assert failed_words[syms["proc_current_slot"]] == 0
    # Before the selected-root classifier takes its fatal branch,
    # the transaction is legitimately still holding the two pins.
    assert failed_ext == full_ext, \
        "MM mutated between full loader entry and root I/O failstop"
    root = failed_words[syms["vfs_namespace_root"]]
    acs = trace.split("V1642_ROOT_FAILURE_CLASSIFIER\n", 1)[1].split(
        "V1642_STAGE_REAL_IO_FAILURE\n", 1)[0]
    registers = {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^\s*([12]):\s*([0-7]{1,12})\s*$", acs)}
    assert set(registers) == {1, 2}
    assert registers[1] == 7, "failed read was not from TSFS provider"
    assert 1 <= registers[2] <= 63
    assert (root >> 24) == ((7 << 6) | registers[2]), \
        "actual failing TSFS mount was not namespace ROOT"
    assert re.search(r"Breakpoint, PC: %06o " %
                     syms["kcore_root_fs_io_failure_v1538"], trace), \
        "actual root I/O failure classifier was not executed"
    expected_halt = syms["kcore_critical_device_lost_v1515"] + 3
    assert re.search(r"HALT instruction, PC: %06o " % expected_halt,
                     trace), "must stop at source-linked ROOT HALT, not resume"
    print("v1642: compressed PURE slot%o FULL holds pinned source/target" %
          packed[0][4])
    print("v1642: physical Type-551 selected ROOT members DTC0/1/2 detached")
    print("v1642: real TSFS provider=%o mount=%o matches namespace root" %
          (registers[1], registers[2]))
    print("PASS v1642: genuine root read failure fail-stops at PC %06o" %
          expected_halt)
    print("v1642: root failstop is terminal; no FULL rollback or WAIT is claimed")


def main():
    parser = argparse.ArgumentParser()
    for key in ("kcore_map", "pure_map", "pure_dxrcheck", "trace",
                "guest_source", "manifest", "provider", "critical"):
        parser.add_argument(key, type=Path)
    args = parser.parse_args()
    names = ("kcore_map", "pure_map", "pure_dxrcheck", "trace",
             "guest_source", "manifest", "provider", "critical")
    try:
        audit(*(getattr(args, x).read_text(encoding="ascii") for x in names))
    except (AssertionError, ValueError, KeyError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1642 physical root FULL read: %s\n" % exc)


if __name__ == "__main__":
    main()

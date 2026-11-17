#!/usr/bin/env python3
"""Audit original two-PURE-child guest and REAL DTFS V2 unmount/RUN race.

The original kernel is modified only in a disposable build to sleep 768
real hardware-CLK ticks AFTER v1562 V2 quiescence, as v1565 accepted.
The actual owner barrier, PURE attach, EXEC, VFS retirement and MM are
unmodified; the challenged RUN and the later accepted RUN are real.
"""

import argparse
from pathlib import Path
import re
import runpy


STAGES = ("B", "A", "WAKE", "PI6_DONE", "RACE_START", "BARRIER",
          "RUN_REFUSED", "UNMOUNT_DONE", "REMOUNT", "RUN_OK",
          "RELEASED", "Z")


def audit(kmap, plain, comp, trace, guest, original_guest):
    here = Path(__file__).resolve().parent
    old = runpy.run_path(str(here.parent /
                               "pure-full-restore-v1638/audit-v1638.py"))
    generator = runpy.run_path(str(here / "prepare-v1646.py"))
    assert generator["generate"](original_guest) == guest, \
        "original guest source not exactly derived from accepted C89 source"
    for fragment in ("#define P14_CHILDREN         2U",
                     "p14_check_busy_v1644();",
                     "p14_quiesce_run_v1646();",
                     "p14_spawn_unmounter_v1646(control_rd)",
                     "dsys_unmount(p14_mount_v1643) != 0",
                     "result = dsys_fsinfo(1U, &info)",
                     "if (result < 0)",
                     "if (result == 0 || dsys_sleep(1U) != 0)",
                     "child = p14_spawn(restore_rd, 1U);",
                     "if (child != -1 || dsys_fsinfo(1U, &info) >= 0)",
                     "dsys_dtfs_mount(p14_device_v1643, p14_mount_v1643,",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('Q');", "(void)p14_char('R');",
                     "(void)p14_char('M');", "(void)p14_char('A');",
                     "(void)p14_char('Z');"):
        assert fragment in guest, "missing real v1646 source gate: " + fragment
    assert "denied = p14_spawn" not in guest, \
        "v1646 is NOT a six-child admission pressure test"
    plain_words, comp_words = (old["dxr_words"](x) for x in (plain, comp))
    assert plain_words[0] == comp_words[0]
    assert plain_words[2] == comp_words[2]
    assert plain_words[1] >> 18 == comp_words[1] >> 18
    assert (plain_words[1] & 0o300000) == 0o200000
    assert (comp_words[1] & 0o300000) == 0o300000
    text_words = comp_words[2] >> 18
    skipped = (text_words + 0o20) & ~0o177
    raw_size = 0o10000 - skipped
    assert 0 < raw_size < 0o10000

    syms = old["symbols"](kmap)
    for symbol in ("vfs_quiesce_sleep_done_v1646", "proc_swap_attach",
                   "vfs_dtfs_owner_admit_v1562",
                   "vfs_dtfs_quiesce_begin_v1562", "proc_swap_records",
                   "vfs_mount_policy", "vfs_namespace_root",
                   "clk_tick_count", "proc_timer_clock"):
        assert symbol in syms, "not compiled in KCORE: " + symbol
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "DTFS                              LOADED" in trace
    assert "HALT instruction, PC: 000000" in trace
    assert "HALT instruction, PC: 000001" not in trace
    assert "!" not in trace, "original user guest failed before acceptance"
    assert "aa[B" in trace and "[A" in trace
    for marker in STAGES:
        first, last = ("V1646_STAGE_%s\n" % marker,
                       "V1646_END_%s\n" % marker)
        assert trace.count(first) == 1 and trace.count(last) == 1, marker
        assert trace.index(first) < trace.index(last)
    for a, b in zip(STAGES, STAGES[1:]):
        assert trace.index("V1646_END_%s\n" % a) < \
            trace.index("V1646_STAGE_%s\n" % b), \
            "guest checkpoint order is invalid"

    snapshots = {}
    for marker in STAGES:
        words, extents = old["stage"](
            trace.replace("V1646_", "V1638_"), syms, marker)
        assert words[syms["vfs_namespace_root"]] >> 24 == \
            (7 << 6) | 1, "selected TSFS namespace root changed"
        assert words[syms["proc_current_slot"]] == 1
        assert (words[syms["vfs_mount_policy"]] & 1) == 1
        assert words[syms["clk_tick_count"]] >= 0
        snapshots[marker] = (words, extents)

    def children(marker):
        return [(a, b, kind, pin, owner) for a, b, kind, pin, owner
                in snapshots[marker][1]
                if kind in (1, 4) and 2 <= owner <= 7]

    expected = [(a, b, k, p, o) for a, b, k, p, o in children("B")]
    assert len(expected) == 2
    assert {owner for a, b, kind, pin, owner in expected} == {2, 3}
    assert all(kind == 4 and pin == 0 and b - a == raw_size
               for a, b, kind, pin, owner in expected)
    assert children("A") == expected
    assert children("WAKE") == expected
    assert children("PI6_DONE") == [row for row in expected if row[4] == 3], \
        "one token did not release exactly the root-backed child"

    # After two original PID/EXIT-057 WAITs there are no child RAW
    # owners. The new actor is an independent TSFS-backed process,
    # which might be resident or PACKED while its unmount sleeps.
    assert not children("RACE_START") or all(
        owner == 2 for a, b, kind, pin, owner in children("RACE_START"))

    q = snapshots["BARRIER"][0]
    r = snapshots["RUN_REFUSED"][0]
    v = snapshots["UNMOUNT_DONE"][0]
    m = snapshots["REMOUNT"][0]
    assert (q[syms["vfs_mount_policy"]] & 0o2) == 0
    assert (r[syms["vfs_mount_policy"]] & 0o2) == 0
    assert q[syms["vfs_mount_root_base"]] == \
        r[syms["vfs_mount_root_base"]], \
        "quiescing DTFS mount pointer changed across refused RUN"
    assert q[syms["dtfs_media_base"]] == r[syms["dtfs_media_base"]], \
        "live V2 media owner changed across refused RUN"
    assert (v[syms["vfs_mount_policy"]] & 0o2) == 0
    assert (m[syms["vfs_mount_policy"]] & 0o2) == 0
    # Both sides still running on the selected TSFS ROOT; the
    # quiescing mount is independently non-root, writable DTC3.
    assert q[syms["vfs_namespace_root"]] == r[syms["vfs_namespace_root"]]
    assert q[syms["vfs_namespace_root"]] == v[syms["vfs_namespace_root"]]
    assert q[syms["vfs_namespace_root"]] == m[syms["vfs_namespace_root"]]

    # The original v1565 real 768-tick sleep holds the V2 barrier
    # while the challenger observes FSINFO -1, attempts actual RUN,
    # then again observes FSINFO -1; no child PURE backing should
    # appear until the mount has been retired and REMOUNTed.
    original_records = [q[syms["proc_swap_records"] + i]
                        for i in range(16)]
    refused_records = [r[syms["proc_swap_records"] + i]
                       for i in range(16)]
    assert refused_records == original_records, \
        "refused PURE RUN left a new or corrupted process swap backing"
    assert children("RUN_REFUSED") == children("BARRIER"), \
        "failed RUN changed original process/MM owners"
    for marker in ("RUN_OK", "RELEASED", "Z"):
        assert not children(marker), "child MM owner leaked after final WAIT"

    def clk(name):
        return snapshots[name][0][syms["clk_tick_count"]]

    def epoch(name):
        return snapshots[name][0][syms["proc_timer_clock"]] & 0o377777

    assert clk("BARRIER") >= clk("RACE_START")
    assert clk("RUN_REFUSED") >= clk("BARRIER")
    assert clk("UNMOUNT_DONE") - clk("RACE_START") >= 0o1400, \
        "disposable v1565-style real clock interval did not occur"
    assert 0 < (epoch("UNMOUNT_DONE") - epoch("RACE_START")) & 0o377777
    assert clk("Z") >= clk("UNMOUNT_DONE")

    q_text = trace.split("V1646_STAGE_BARRIER\n", 1)[0]
    r_text = trace.split("V1646_STAGE_RUN_REFUSED\n", 1)[0]
    assert "Q" in q_text and "R" in r_text
    # The observed Q/R markers come from the EXACT generated C89
    # source and require FSINFO -1 both before and after a real PURE
    # dsys_run, not a detached/retired mount's empty FSINFO=0.
    print("v1646: original 48K two-owner ROOT+compressed PURE, RAW %06o" %
          raw_size)
    print("v1646: original V2 quiescence blocked real compressed RUN")
    print("v1646: real CLK PI6 advanced %d ticks across protected unmount" %
          (clk("UNMOUNT_DONE") - clk("RACE_START")))
    print("v1646: original PURE swap backing/MM unchanged through refusal")
    print("PASS v1646: same DTC3 remount and compressed RUN, final MM/HALT")


def main():
    ap = argparse.ArgumentParser()
    for field in ("kcore_map", "plain_dxr", "compressed_dxr", "trace",
                  "guest_source", "original_source"):
        ap.add_argument(field, type=Path)
    args = ap.parse_args()
    try:
        audit(args.kcore_map.read_text(encoding="ascii"),
              args.plain_dxr.read_bytes(), args.compressed_dxr.read_bytes(),
              args.trace.read_text(encoding="ascii"),
              args.guest_source.read_text(encoding="ascii"),
              args.original_source.read_text(encoding="ascii"))
    except (AssertionError, KeyError, ValueError, UnicodeError) as exc:
        ap.exit(1, "FAIL v1646 physical quiescence RUN: %s\n" % exc)


if __name__ == "__main__":
    main()

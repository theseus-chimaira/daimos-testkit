#!/usr/bin/env python3
"""Correlate original 48K FULL physical evidence with PI6 slot-0 gate.

The native v1650 instruction test is independent. This auditor proves
that the *actual* original v1643 two-pin checkpoint is within slot 0,
and that its MRES loader PC is outside the only PI6-switchable slot-0
idle interval. It does not manufacture a second executing process.
"""

from pathlib import Path
import re
import runpy
import sys


def section(source, first, last):
    assert source.count(first) == 1, first
    remaining = source.split(first, 1)[1]
    assert last in remaining, last
    return remaining.split(last, 1)[0]


def audit(repo, testkit, build, trace):
    root = Path(repo) / "system/kernel"
    kmap = Path(build, "kcore.map").read_text(encoding="ascii")
    mmap = Path(build, "pure-mres-v1612.map").read_text(encoding="ascii")
    recorded = Path(trace).read_text(encoding="ascii")
    oracle = runpy.run_path(str(Path(testkit) /
        "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    names = oracle["symbols"](kmap)
    mres = oracle["symbols"](mmap)
    assert "MEM                                  48 K" in recorded
    assert "PURE                              LOADED" in recorded
    assert "DTFS                              LOADED" in recorded
    assert "HALT instruction, PC: 000000" in recorded

    # The loader's original physical address is not a guessed symbol:
    # v1643 verified the exact MRES loaded base and bounded entry opcode.
    loader = 0o32026 + mres["exec_image_full_bounded_v1391"]
    assert loader == 0o35252
    idle = names["proc_idle_loop"]
    idle_end = names["proc_finish_backoff_advance_v885"]
    assert 0 < idle < idle_end < loader

    original = recorded.replace("V1643_", "V1638_")
    stage = oracle["stage"]
    before, prior = stage(original, names, "A")
    pinned, entries = stage(original, names, "FULL_PINNED")
    failed, after = stage(original, names, "ROLLED_BACK")
    later, restored = stage(original, names, "LATER_FULL")
    final, ends = stage(original, names, "Z")
    assert before[names["proc_current_slot"]] == 1
    assert pinned[names["proc_current_slot"]] == 0
    assert failed[names["proc_current_slot"]] == 0
    assert later[names["proc_current_slot"]] == 0
    assert final[names["proc_current_slot"]] == 1
    full = [(a, b, typ, pin, slot) for a, b, typ, pin, slot in entries
            if typ == 1 and pin == 1 and b - a == 0o10000
            and 2 <= slot <= 7]
    assert len(full) == 1
    slot = full[0][4]
    raw = [(a, b, typ, pin, owner) for a, b, typ, pin, owner in entries
           if typ == 4 and owner == slot]
    assert len(raw) == 1
    assert raw[0][3] == 1 and raw[0][1] - raw[0][0] == 0o6600
    assert full[0][1] <= raw[0][0] or raw[0][1] <= full[0][0]
    assert not any(typ == 1 and owner == slot for a, b, typ, pin, owner
                   in after)
    assert [(a, b, pin) for a, b, typ, pin, owner in after
            if typ == 4 and owner == slot] == [(raw[0][0], raw[0][1], 0)]
    assert not [(a, b, typ, pin, owner) for a, b, typ, pin, owner
                in ends if typ in (1, 4) and 2 <= owner <= 7]

    sched = (root / "proc/proc_pdp6.s").read_text(encoding="ascii")
    service = (root / "proc/proc_pure_service_pdp6_v1612.c").read_text(
        encoding="ascii")
    full_source = (root / "proc/proc_pure_ram_restore_v1391.c").read_text(
        encoding="ascii")
    vfs = (root / "fs/vfs.s").read_text(encoding="ascii")
    tick = section(sched, "proc_sched_tick_idle_check:\n",
                   "proc_sched_tick_ready:\n")
    for item in ("hrrz    1,pdp10_pi_level6",
                 "caige   1,proc_idle_loop",
                 "cail    1,proc_idle_loop_end",
                 "trne    1,0400"):
        assert item in tick, item
    resched = section(sched, "proc_sched_pi_resched:\n",
                      "; Called once per qualified line-clock")
    assert "caige   1,proc_idle_loop" in resched
    assert "cail    1,proc_idle_loop_end" in resched
    assert "trne    1,0400" in resched
    assert "skipn   proc_current_slot" in resched or \
           "move    1,proc_current_slot" in resched
    idle_source = section(sched, "proc_idle_loop:\n",
                          "proc_idle_loop_end:\n")
    assert "trnn    1,0400" in idle_source
    assert "pushj   17,proc_swap_service_one" in idle_source
    assert idle_source.index("trnn    1,0400") < idle_source.index(
        "pushj   17,proc_swap_service_one")
    assert "proc_current_slot != 0UL" in service
    assert "proc_pure_ram_restore_v1391(slot," in service
    assert "exec_image_full_bounded_v1391);" in service
    items = ("rc = mm_pin(source);",
             "rc = mm_pin(target);",
             "if (loader(backing, target, PROC_UAREA_BASE(p), words))",
             "fs_copy_words(PRAM_PTR(source), PRAM_PTR(target + skip),",
             "rc = mm_free(source, MM_TYPE_PACKED_PROCESS, slot);",
             "VM_PDP6_SET_BASE(p, target);")
    offsets = []
    for item in items:
        assert full_source.count(item) == 1
        offsets.append(full_source.index(item))
    assert offsets == sorted(offsets)
    unmount = section(vfs, "vfs_unmount:\n",
                      "vfs_unmount_owner_check_v1523:\n")
    assert unmount.index("pushj   17,vfs_unmount_owner_check_v1523") < \
           unmount.index("pushj   17,vfs_dtfs_quiesce_begin_v1562")
    print("v1650: original 48K MRES loader PC %06o; idle %06o..%06o" %
          (loader, idle, idle_end))
    print("v1650: FULL source %06o..%06o, target %06o..%06o, slot %o pin1" %
          (raw[0][0], raw[0][1], full[0][0], full[0][1], slot))
    print("v1650: original PI6 clock/software gates exclude MRES PC from slot-0 switch")
    print("v1650: original VFS mount owner scan precedes V2 quiescence without yield")
    print("PASS v1650: original physical dual-pin snapshot and slot-0 serialization")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        raise SystemExit("usage: audit-physical-v1650.py DAIMOS testkit build trace")
    try:
        audit(*sys.argv[1:])
    except (AssertionError, KeyError, ValueError, OSError) as error:
        print("FAIL v1650 physical/PI6 correlation: %s" % error,
              file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env python3
"""Extend v1910 through original orphan EXIT and last-user idle retries."""

from pathlib import Path
import os
import runpy
import sys


def prepare(kit, build, probe, work, prefix):
    parent = runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-parent-exit-v1910/prepare-physical-v1910.py"))
    parent["prepare"](kit, build, probe, work, prefix)
    link = runpy.run_path(str(kit / "tests/validation/"
                        "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = link["symbols"](build / "kcore.map")
    for name in ("proc_exit_current", "proc_idle_loop", "proc_sched_pi_tick",
                 "proc_finish_service_v881", "proc_has_live_user",
                 "proc_timer_clock",
                 "proc_current_slot", "proc_high_slot", "proc_table"):
        if name not in core:
            raise ValueError("original KCORE last-user symbol missing: " + name)
    # This historical local BSS label is not emitted in the linked map.
    # The fixed original assembler has exactly two clock words before it.
    source=(Path(os.environ["DAIMOS_REPO"]) /
            "system/kernel/proc/proc_pdp6.s")
    bss=source.read_text(encoding="ascii")
    if bss.count("proc_timer_clock:\n        .block 1\nproc_timer_next:\n"
                 "        .block 1\nproc_finish_last_tick_v881:\n")!=1:
        raise ValueError("original fixed clock/retry BSS placement drifted")
    pending=core["proc_timer_clock"]+2
    path = work / "physical.ini"
    script = path.read_text(encoding="ascii")
    old_tail = "echo V1910_OPERATOR_STOP_NO_GUEST_HALT\nexit\n"
    start = "echo V1910_STAGE_POST_EXIT_PI6\n"
    end = "echo V1910_END_POST_EXIT_PI6\n"
    if script.count(old_tail)!=1 or not script.endswith(old_tail) or \
       script.count(start)!=1 or script.count(end)!=1:
        raise ValueError("v1910 original parent/PI6 stage drifted")
    original = script.split(start,1)[1].split(end,1)[0]
    if not original.startswith("examine ") or any(
            not s.startswith("examine ") for s in original.splitlines()):
        raise ValueError("original parent post-EXIT MM read-only snapshot drift")
    extended = (original +
                "examine 045700-045726\n" +
                "examine %06o\n" % core["proc_high_slot"] +
                "examine %06o\n" % pending)

    def snapshot(label):
        return ("echo V1911_STAGE_%s\n" % label + extended +
                "echo V1911_END_%s\n" % label)

    new = ""
    # The three remaining non-quarantined children are slots 4/5/6
    # after original parent EXIT. Do not fake their state or SYS_EXIT.
    for i in range(1,4):
        new += ("nobreak all\nbreak %06o\ncont\n" %
                core["proc_exit_current"] +
                "echo V1911_REAL_CHILD_EXIT_%d\n" % i +
                snapshot("CHILD_EXIT_%d" % i) +
                # Reaching the real idle loop proves the child EXIT
                # continued and ran the native slot0 finalizer before
                # rearming the same EXIT breakpoint for another child.
                "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
                ("echo V1911_ORIGINAL_CHILD_DONE_%d\n" % i if i<3 else
                 "echo V1911_ORIGINAL_LAST_ORPHAN_IDLE\n") +
                snapshot("CHILD_DONE_%d" % i if i<3 else "ONLY_ORPHAN"))
    # Three real clock-governed slot0 retry scans while ONLY the
    # original foreign-claimed child remains. The source-linked
    # post-VM scan itself must not release a foreign target.
    for i in range(1,4):
        new += ("nobreak all\nbreak %06o\ncont\n" %
                core["proc_finish_service_v881"] +
                "echo V1911_ORIGINAL_IDLE_RETRY_%d\n" % i +
                snapshot("IDLE_RETRY_%d" % i) +
                "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
                "echo V1911_ORIGINAL_RETRY_COMPLETED_%d\n" % i +
                snapshot("RETRY_DONE_%d" % i))
    new += ("nobreak all\nbreak %06o\ncont\n" %
            core["proc_sched_pi_tick"] +
            "echo V1911_ORIGINAL_LAST_ORPHAN_PI6\n"
            "examine %06o\n" % core["pdp10_pi_level6"] +
            snapshot("LAST_PI6") +
            "echo V1911_OPERATOR_STOP_NO_CHILD_HALT\nexit\n")
    if new.count("break %06o\n" % core["proc_exit_current"])!=3 or \
       new.count("break %06o\n" % core["proc_finish_service_v881"])!=3 or \
       new.count("break %06o\n" % core["proc_idle_loop"])!=6:
        raise ValueError("last-child original exit/idle trace gates wrong")
    script = script[:-len(old_tail)] + new
    if "V1906_FOREIGN_TARGET_REPAIR" in script or \
       script.count("deposit 024725 000001000002\n")!=1 or \
       script.count("V1910_ORIGINAL_PARENT_EXIT_CURRENT")!=1:
        raise ValueError("last-child probe did not preserve original foreign fault")
    path.write_text(script,encoding="ascii")
    (work / "expected-v1911.txt").write_text(
        "table 045700\nchild_slot 000003\n"
        "child_exit_pc %06o\nidle_pc %06o\n"
        "retry_pc %06o\npi6_pc %06o\n"
        "pending %06o\nclock %06o\n"
        "live_check %06o\n" %
        (core["proc_exit_current"],core["proc_idle_loop"],
         core["proc_finish_service_v881"],core["proc_sched_pi_tick"],
         pending,core["proc_timer_clock"],
         core["proc_has_live_user"]),encoding="ascii")
    print("v1911: original nonquarantined child EXIT x3, then last-user idle x3")


if __name__=="__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1911.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1911 last-orphan physical setup: "+str(exc))

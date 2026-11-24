#!/usr/bin/env python3
"""Observe a genuine parent EXIT while an unrepaired child FULL remains foreign."""

from pathlib import Path
import runpy
import sys


def prepare(kit, build, probe, work, prefix):
    previous = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-foreign-term-v1907/prepare-physical-v1907.py"))
    previous["prepare"](kit, build, probe, work, prefix)
    linked = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    symbols = linked["symbols"]
    core = symbols(build / "kcore.map")
    user = symbols(build.parent / "user/init.map")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if guest.count("v1910_exit_gate == 065432107654UL") != 1 or \
       guest.count("rc_v1910 = dsys_exit(0);") != 1 or \
       guest.count("rc_v1910 == 0 ? 'A' : 'R'") != 1 or \
       guest.count("v1907_term_gate == 076543210123UL") != 1 or \
       guest.count("if (v1901_term_gate != 0UL)") != 1:
        raise ValueError("original parent source does not contain one real EXIT")
    for key in ("v1910_exit_gate", "v1907_term_gate", "v1901_term_gate"):
        if key not in user:
            raise ValueError("unlinked original USER APR gate " + key)
    for key in ("proc_exit_current", "proc_finish_slot_owner_v932",
                "proc_idle_loop", "proc_sched_pi_tick", "proc_table",
                "proc_current_slot", "pdp10_pi_level6"):
        if key not in core:
            raise ValueError("unlinked native KCORE exit symbol " + key)
    gate = 0o130000 + user["v1910_exit_gate"]
    term = 0o130000 + user["v1907_term_gate"]
    wait = 0o130000 + user["v1901_term_gate"]
    if len({gate, term, wait}) != 3 or not 0o130000 < gate < 0o140000:
        raise ValueError("original USER APR gates not physically isolated")
    path = work / "physical.ini"
    script = path.read_text(encoding="ascii")
    stop = "echo V1907_END_TERM_REFUSED\n"
    stage = "echo V1907_STAGE_TERM_REFUSED\n"
    if script.count(stop) != 1 or script.count(stage) != 1:
        raise ValueError("original TERM-refused MM stage no longer unique")
    snap = script.split(stage, 1)[1].split(stop, 1)[0]
    if not snap.startswith("examine ") or any(
            line and not line.startswith("examine ")
            for line in snap.splitlines()):
        raise ValueError("not the read-only original MM18 snapshot")
    script = script.split(stop, 1)[0] + stop
    # The parent uarea address comes from the original read-only v1906
    # physical process table, not a fabricated KCORE return. The exact
    # process-table pointer is verified again from the trace.
    table = 0o45700
    parent_uarea = 0o45761

    def snapshot(label, parent_live):
        s = "echo V1910_STAGE_%s\n" % label + snap
        s += "examine %06o\n" % (table + 3)
        if parent_live:
            s += "examine %06o\n" % (parent_uarea + 0o24)
            s += "examine %06o\n" % (parent_uarea + 0o67)
        return s + "echo V1910_END_%s\n" % label

    script += (
        "echo V1910_PARENT_EXIT_GATE_BEFORE\n"
        "examine %06o\n" % gate +
        "echo V1910_END_PARENT_EXIT_GATE_BEFORE\n"
        "deposit %06o %012o\n" % (gate, 0o65432107654) +
        "echo V1910_PARENT_EXIT_GATE_ARMED\n"
        "examine %06o\n" % gate +
        "echo V1910_END_PARENT_EXIT_GATE_ARMED\n"
        "nobreak all\nexpect \"E\"\ncont\n"
        "echo V1910_REAL_PARENT_USER_EXIT_REQUEST\n"
        "nobreak all\nbreak %06o\ncont\n" % core["proc_exit_current"] +
        "echo V1910_ORIGINAL_PARENT_EXIT_CURRENT\n" +
        snapshot("EXIT_ENTRY", True) +
        "nobreak all\nbreak %06o\ncont\n" % core["proc_finish_slot_owner_v932"] +
        "echo V1910_ORIGINAL_SLOT0_OWNER_FINALIZER\n" +
        snapshot("FINALIZER", True) +
        "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
        "echo V1910_ORIGINAL_PARENT_EXIT_IDLE\n" +
        snapshot("PARENT_GONE", False) +
        "nobreak all\nbreak %06o\ncont\n" % core["proc_sched_pi_tick"] +
        "echo V1910_ORIGINAL_POST_EXIT_PI6\n"
        "examine %06o\n" % core["pdp10_pi_level6"] +
        snapshot("POST_EXIT_PI6", False) +
        "echo V1910_OPERATOR_STOP_NO_GUEST_HALT\nexit\n")
    if script.count("deposit %06o %012o\n" % (gate, 0o65432107654)) != 1 or \
       script.count('expect "TR"\ncont\n') != 1 or \
       script.count('expect "E"\ncont\n') != 1 or \
       "V1906_FOREIGN_TARGET_REPAIR" in script or \
       "V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL" in script or \
       script.count("break %06o\n" % core["proc_exit_current"]) != 1:
        raise ValueError("parent test repaired owner or bypassed real EXIT")
    path.write_text(script, encoding="ascii")
    (work / "expected-v1910.txt").write_text(
        "exit_gate %06o\nterm_gate %06o\nwait_gate %06o\n"
        "exit_value %012o\nparent_meta %06o\nparent_uarea %06o\n"
        "exit_pc %06o\nowner_pc %06o\nidle_pc %06o\npi6_pc %06o\n" %
        (gate, term, wait, 0o65432107654, table + 3, parent_uarea,
         core["proc_exit_current"], core["proc_finish_slot_owner_v932"],
         core["proc_idle_loop"], core["proc_sched_pi_tick"]),
        encoding="ascii")
    print("v1910: source-linked parent USER EXIT gate %06o" % gate)
    print("v1910: original KCORE EXIT %06o finalizer %06o idle %06o" %
          (core["proc_exit_current"], core["proc_finish_slot_owner_v932"],
           core["proc_idle_loop"]))


if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: prepare-physical-v1910.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        raise SystemExit("FAIL v1910 physical parent EXIT setup: " + str(exc))

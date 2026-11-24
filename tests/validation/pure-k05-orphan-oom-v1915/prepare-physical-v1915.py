#!/usr/bin/env python3
"""Original 48K PDP-6: genuine parent capacity-OOM, foreign child survives."""

from pathlib import Path
import runpy
import shutil
import sys


PRESSURE_GATE = 0o76543012765
BRK_TARGET = 0o130000


def prepare(kit, build, probe, work, prefix):
    previous = runpy.run_path(str(kit / "tests/validation/"
                              "pure-k05-foreign-term-v1907/prepare-physical-v1907.py"))
    previous["prepare"](kit, build, probe, work, prefix)
    reader = runpy.run_path(str(kit / "tests/validation/"
                             "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    first = reader["values"](work / "expected-v1906.txt")
    linker = runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = linker["symbols"](build / "kcore.map")
    user = linker["symbols"](build.parent / "user/init.map")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    for label in ("mm_arena_fits_v1260", "proc_fatal_close_current_v879",
                  "proc_exit_current", "proc_idle_loop", "proc_sched_pi_tick",
                  "proc_finish_service_v881", "mm_extent_count", "proc_table",
                  "proc_current_slot", "proc_high_slot"):
        if label not in core:
            raise ValueError("original KCORE OOM/idle symbol absent: "+label)
    if guest.count("v1901_term_gate == 076543012765UL") != 1 or \
       guest.count("(void)dsys_brk(0130000UL);") != 1 or \
       guest.count("p14_fail('O');") != 1 or \
       guest.count("rc_v1907 == 0 ? 'A' : 'R'") != 1:
        raise ValueError("test-only user BRK/foreign TERM source is not unique")
    if "v1901_term_gate" not in user:
        raise ValueError("test-only parent gate omitted from linked user map")
    table_base=first["process_table"]
    if table_base != 0o45700 or core["proc_table"] == table_base:
        raise ValueError("original physical process table/pointer identity drift")
    pressure_gate = 0o130000 + user["v1901_term_gate"]
    if not 0o130000 < pressure_gate < 0o140000:
        raise ValueError("original parent USER APR gate not addressable")
    script_path = work / "physical.ini"
    script = script_path.read_text(encoding="ascii")
    old_cut = "echo V1907_END_TERM_REFUSED\n"
    old_start = "echo V1907_STAGE_TERM_REFUSED\n"
    if script.count(old_cut)!=1 or script.count(old_start)!=1:
        raise ValueError("v1907 physically refused TERM stage missing")
    snapshot = script.split(old_start,1)[1].split(old_cut,1)[0]
    if not snapshot.startswith("examine ") or any(
            line and not line.startswith("examine ")
            for line in snapshot.splitlines()):
        raise ValueError("v1907 original MM snapshot not read-only")
    shutil.copyfile(script_path, work / "physical-v1907.ini")

    def stage(name):
        return ("echo V1915_STAGE_%s\n" % name + snapshot +
                # v1907 observed only through slot5. The KCORE
                # symbol proc_table names a POINTER (at 024635),
                # not the physical table itself. Use the actual
                # original source-linked base at 045700 to include
                # slot6's descriptor through word 045726.
                "examine %06o-%06o\n" %
                (table_base,table_base+0o26) +
                "examine %06o\n" % core["proc_high_slot"] +
                "examine %06o\n" % core["proc_timer_clock"] +
                "echo V1915_END_%s\n" % name)

    # v1907's later TERM/WAIT/HALT suffix belongs to a REPAIRED target.
    # Cut it before adding the never-repaired user-requester OOM test.
    script = script.split(old_cut,1)[0] + old_cut
    appended=(
        "echo V1915_USER_PRESSURE_GATE_BEFORE\n"
        "examine %06o\n" % pressure_gate +
        "echo V1915_END_USER_PRESSURE_GATE_BEFORE\n"
        "deposit %06o %012o\n" % (pressure_gate,PRESSURE_GATE) +
        "echo V1915_USER_PRESSURE_GATE_ARMED\n"
        "examine %06o\n" % pressure_gate +
        "echo V1915_END_USER_PRESSURE_GATE_ARMED\n"
        "nobreak all\nexpect \"P\"\ncont\n"
        "echo V1915_ACTUAL_PARENT_USER_BRK_REQUEST\n" +
        "nobreak all\nbreak %06o\ncont\n" % core["mm_arena_fits_v1260"] +
        "echo V1915_ORIGINAL_MM_ARENA_FITS\n"
        "examine 1\nexamine 2\n" + stage("MM_ARENA_FITS") +
        "nobreak all\nbreak %06o\ncont\n" %
        core["proc_fatal_close_current_v879"] +
        "echo V1915_ORIGINAL_REQUESTER_ONLY_OOM\n"
        "examine 1\n" + stage("OOM_REQUESTER") +
        "nobreak all\nbreak %06o\ncont\n" % core["proc_exit_current"] +
        "echo V1915_REAL_PARENT_FATAL_EXIT\n" + stage("PARENT_EXIT") +
        "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
        "echo V1915_ORIGINAL_PARENT_OOM_RELEASED\n" +
        stage("PARENT_GONE"))
    # All other real sleeping child users must EXIT after the OOM
    # requester closed its write end; these are NOT synthetic exits.
    for i in range(1,4):
        appended += (
            "nobreak all\nbreak %06o\ncont\n" % core["proc_exit_current"] +
            "echo V1915_REAL_PEER_EXIT_%02d\n" % i +
            stage("PEER_EXIT_%02d" % i) +
            "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
            "echo V1915_REAL_PEER_DONE_%02d\n" % i +
            stage("PEER_DONE_%02d" % i))
    for i in range(1,4):
        appended += (
            "nobreak all\nbreak %06o\ncont\n" %
            core["proc_finish_service_v881"] +
            "echo V1915_ORIGINAL_IDLE_RETRY_%02d\n" % i +
            stage("IDLE_RETRY_%02d" % i) +
            "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
            "echo V1915_ORIGINAL_RETRY_DONE_%02d\n" % i +
            stage("RETRY_DONE_%02d" % i))
    appended += (
        "nobreak all\nbreak %06o\ncont\n" % core["proc_sched_pi_tick"] +
        "echo V1915_ORIGINAL_LAST_ORPHAN_PI6\n"
        "examine %06o\n" % core["pdp10_pi_level6"] +
        stage("LAST_PI6") +
        "echo V1915_OPERATOR_STOP_WITH_FOREIGN_OWNER\nexit\n")
    if appended.count("deposit ")!=1 or \
       appended.count("break %06o\n"%core["proc_exit_current"])!=4 or \
       appended.count("break %06o\n"%core["proc_idle_loop"])!=7 or \
       appended.count("break %06o\n"%core["proc_finish_service_v881"])!=3 or \
       script.count("deposit %06o %012o\n" %
                    (0o24725,0o1000002))!=1 or \
       "V1906_FOREIGN_TARGET_REPAIR" in script:
        raise ValueError("OOM physical script lost original owner fault/exit structure")
    script_path.write_text(script+appended,encoding="ascii")
    (work/"expected-v1915.txt").write_text(
        "pressure_gate %06o\npressure_value %012o\n"
        "brk_target %06o\nmm_fits_pc %06o\n"
        "fatal_pc %06o\nexit_pc %06o\nidle_pc %06o\n"
        "retry_pc %06o\npi6_pc %06o\n" %
        (pressure_gate,PRESSURE_GATE,BRK_TARGET,
         core["mm_arena_fits_v1260"],
         core["proc_fatal_close_current_v879"],
         core["proc_exit_current"],core["proc_idle_loop"],
         core["proc_finish_service_v881"],core["proc_sched_pi_tick"]),
        encoding="ascii")
    print("v1915: original parent BRK impossible request and requester-only native OOM")
    print("v1915: USER gate %06o; MM fits %06o; fatal %06o" %
          (pressure_gate,core["mm_arena_fits_v1260"],
           core["proc_fatal_close_current_v879"]))


if __name__=="__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1915.py kit build probe work prefix")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1915 OOM physical preparation: "+str(exc))

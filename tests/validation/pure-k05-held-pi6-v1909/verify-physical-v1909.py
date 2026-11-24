#!/usr/bin/env python3
"""Genuine fixed-KCORE PCLK PI6 under v1906 foreign FULL quarantine."""

from pathlib import Path
import re
import runpy
import sys


def verify(kit, build, work):
    prior=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-permanent-owner-v1908/verify-physical-v1908.py"))
    prior["verify"](kit,build,work)
    old=runpy.run_path(str(kit/"tests/validation/"
                       "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    base=runpy.run_path(str(kit/"tests/validation/"
                        "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit=runpy.run_path(str(kit/"tests/diagnostics/"
                         "pure-full-restore-v1638/audit-v1638.py"))
    core=base["symbols"](build/"kcore.map")
    e=old["values"](work/"expected-v1906.txt")
    pi=old["values"](work/"expected-v1909.txt")
    trace=(work/"physical.clean").read_text(encoding="ascii")
    ini=(work/"physical.ini").read_text(encoding="ascii")
    section=old["section"]
    word=old["word"]
    if pi["pi6_pc"]!=core["proc_sched_pi_tick"] or \
       pi["pi6_save"]!=core["pdp10_pi_level6"] or \
       pi["idle_start"]!=core["proc_idle_loop"] or \
       pi["pi6_opcode"]!=(0o350040000000|core["proc_timer_clock"]) or \
       ini.count("break %06o\n"%pi["pi6_pc"])!=1 or \
       ini.count("examine %06o\n"%pi["pi6_save"])!=1:
        raise ValueError("PI6 event is not the original source-linked clock")
    names=("V1908_END_LONG_HELD_HB_4",
           "V1909_ORIGINAL_CLOCK_PI6_HELD",
           "V1909_STAGE_PI6_HELD",
           "V1909_END_PI6_HELD",
           "V1908_LONG_HELD_HB_5",
           "V1908_OPERATOR_STOP_NO_GUEST_HALT")
    points=[trace.find(name+"\n") for name in names]
    if any(p<0 or trace.count(name+"\n")!=1 for name,p in zip(names,points)) or \
       points!=sorted(points):
        raise ValueError("real PI6 entry not between original HB4 and HB5")
    if len(re.findall(r"Breakpoint, PC: %06o " %pi["pi6_pc"],trace))!=1:
        raise ValueError("actual original PI6 handler entry absent/duplicated")
    intro=section(trace,"V1909_ORIGINAL_CLOCK_PI6_HELD",
                  "V1909_STAGE_PI6_HELD")
    if word(intro,pi["pi6_pc"])!=pi["pi6_opcode"]:
        raise ValueError("physical PCLK opcode not original first AOS")
    saved=word(intro,pi["pi6_save"])
    resume=saved&0o777777
    if saved&(0o10000<<18) or not \
       core["proc_idle_loop"]<=resume<core["proc_finish_backoff_advance_v885"]:
        raise ValueError("PI6 did not interrupt the original slot-0 idle loop")
    # A PI6 occurring inside the idle loop is a REAL CPU interruption,
    # not an externally forged mm_free return, a timer deposit or a
    # simulator-synthesized recovery status.
    first,mm_first=audit["stage"](
        trace.replace("V1908_","V1638_"),core,"LONG_HELD_HB_4")
    pi_data,pi_mm=audit["stage"](
        trace.replace("V1909_","V1638_"),core,"PI6_HELD")
    after,mm_after=audit["stage"](
        trace.replace("V1908_","V1638_"),core,"LONG_HELD_HB_5")
    if pi_data[core["proc_current_slot"]]!=0 or \
       first[core["proc_current_slot"]]!=1 or \
       after[core["proc_current_slot"]]!=1 or \
       pi_data[core["mm_extent_count"]]!=18 or \
       mm_first!=pi_mm or mm_first!=mm_after or \
       pi_data[core["vfs_namespace_root"]]!=first[core["vfs_namespace_root"]] or \
       pi_data[core["vfs_namespace_root"]]!=after[core["vfs_namespace_root"]]:
        raise ValueError("real PI6 lost original MM18/ROOT/slot0 quarantine")
    pi_block=section(trace,"V1909_STAGE_PI6_HELD",
                     "V1909_END_PI6_HELD")
    hb4=section(trace,"V1908_STAGE_LONG_HELD_HB_4",
                "V1908_END_LONG_HELD_HB_4")
    hb5=section(trace,"V1908_STAGE_LONG_HELD_HB_5",
                "V1908_END_LONG_HELD_HB_5")
    for addr in (e["process_table"]+9,e["process_table"]+10,
                 e["process_table"]+11,e["uarea"]+0o20,
                 e["uarea"]+0o24,e["uarea"]+0o67,e["parent_gate"]):
        if not (word(pi_block,addr)==word(hb4,addr)==word(hb5,addr)):
            raise ValueError("original interrupt corrupted escrow/context at %06o"%addr)
    if word(pi_block,e["uarea"]+0o67)!=(1<<32)|0o120000 or \
       not (word(pi_block,e["process_table"]+9)&(1<<16)) or \
       (word(pi_block,e["process_table"]+10)&0o777777):
        raise ValueError("original slot3 transitioned during real PCLK PI6")
    clock=pi_data[core["proc_timer_clock"]]
    previous=first[core["proc_timer_clock"]]
    following=after[core["proc_timer_clock"]]
    interval=(word(pi_block,core["proc_timer_clock"]+2)>>18)&0o377777
    if not previous<=clock<=following or interval not in \
       (0o100,0o200,0o400,0o1000) or \
       word(intro,core["proc_sched_cursor"])&0o400:
        raise ValueError("PI6 clock/backoff/swap cursor no longer safe")
    print("PASS v1909: original PCLK PI6 %06o opcode %012o"%
          (pi["pi6_pc"],pi["pi6_opcode"]))
    print("PASS v1909: interrupted real slot-0 idle PC %06o"%resume)
    print("PASS v1909: MM18, target escrow, CTX/FDCTL and TRANSITION unchanged")
    print("PASS v1909: parent HBs 5-10 continue, retry cap, no native HALT")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1909.py kit build work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,AssertionError,KeyError,UnicodeError) as exc:
        raise SystemExit("FAIL v1909 native held-owner PI6: "+str(exc))

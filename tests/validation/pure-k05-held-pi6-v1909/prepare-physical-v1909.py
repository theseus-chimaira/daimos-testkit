#!/usr/bin/env python3
"""Observe one genuine PCLK PI6 during the v1908 held-owner window."""

from pathlib import Path
import os
import re
import runpy
import sys


def prepare(kit, build, probe, work, prefix):
    old = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-permanent-owner-v1908/prepare-physical-v1908.py"))
    old["prepare"](kit, build, probe, work, prefix)
    linked = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = linked["symbols"](build / "kcore.map")
    for label in ("proc_sched_pi_tick", "pdp10_pi_level6",
                  "proc_timer_clock", "proc_sched_cursor",
                  "proc_idle_loop", "proc_current_slot"):
        if label not in core:
            raise ValueError("missing original fixed KCORE PI6 symbol " + label)
    src=(Path(os.environ["DAIMOS_REPO"]) /
         "system/kernel/proc/proc_pdp6.s").read_text(encoding="ascii")
    if src.count("proc_sched_pi_tick:")!=1 or not re.search(
            r"(?m)^proc_sched_pi_tick:\n\s*;[^\n]*\n"
            r"(?:\s*;[^\n]*\n)*\s*aos\s+1,proc_timer_clock\s*$",src):
        raise ValueError("physical clock handler/source first opcode drifted")
    pi6=core["proc_sched_pi_tick"]
    opcode=0o350040000000|core["proc_timer_clock"]
    path=work/"physical.ini"
    script=path.read_text(encoding="ascii")
    start="echo V1908_STAGE_LONG_HELD_HB_4\n"
    end="echo V1908_END_LONG_HELD_HB_4\n"
    if script.count(start)!=1 or script.count(end)!=1:
        raise ValueError("v1908 held-owner HB4 read-only snapshot missing")
    commands=script.split(start,1)[1].split(end,1)[0]
    if not commands.startswith("examine ") or any(
            not line.startswith("examine ") for line in commands.splitlines()):
        raise ValueError("original MM snapshot not read-only")
    tick=("nobreak all\n"
          "break %06o\ncont\n"%pi6+
          "echo V1909_ORIGINAL_CLOCK_PI6_HELD\n"
          "examine %06o\n"%pi6+
          "examine %06o\n"%core["pdp10_pi_level6"]+
          "examine %06o\n"%core["proc_sched_cursor"]+
          "echo V1909_STAGE_PI6_HELD\n"+
          commands+
          "echo V1909_END_PI6_HELD\n"
          "nobreak all\n")
    script=script.replace(end,end+tick,1)
    if script.count("break %06o\n"%pi6)!=1 or \
       script.count("V1909_ORIGINAL_CLOCK_PI6_HELD")!=1 or \
       script.count('expect "TR"\ncont\n')!=1 or \
       script.count('expect "HB"\ncont\n')!=11:
        raise ValueError("PI6 probe alters original long-held physical workflow")
    path.write_text(script,encoding="ascii")
    (work/"expected-v1909.txt").write_text(
        "pi6_pc %06o\npi6_opcode %012o\npi6_save %06o\n"
        "idle_start %06o\n"%
        (pi6,opcode,core["pdp10_pi_level6"],core["proc_idle_loop"]),
        encoding="ascii")
    print("v1909: real PI6 %06o expected AOS %012o, saved PC %06o"%
          (pi6,opcode,core["pdp10_pi_level6"]))


if __name__=="__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1909.py kit build probe work prefix")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1909 PI6 probe preparation: "+str(exc))

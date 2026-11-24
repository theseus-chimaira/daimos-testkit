#!/usr/bin/env python3
"""Source-linked 17-bit wrap proof with genuine PCLK ticks and idle retries."""

from pathlib import Path
import os
import runpy
import shutil
import sys


REBASE_CLOCK = 0o377770
CAP = 0o1000
WRAP = 0o400000
ACTUAL_PI6 = 7
AFTER_WRAP_RETRIES = 3


def prepare(kit, build, probe, work, prefix):
    previous = runpy.run_path(str(kit / "tests/validation/"
                              "pure-k05-permanent-orphan-v1913/prepare-physical-v1913.py"))
    previous["prepare"](kit, build, probe, work, prefix)
    linked = runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = linked["symbols"](build / "kcore.map")
    source = (Path(os.environ["DAIMOS_REPO"]) /
              "system/kernel/proc/proc_pdp6.s").read_text(encoding="ascii")
    header = (Path(os.environ["DAIMOS_REPO"]) /
              "system/kernel/proc/proc.h").read_text(encoding="ascii")
    if source.count(".equ    PROC_TIMER_CLOCK_MASK,0377777") != 1 or \
       header.count("#define PROC_TIMER_CLOCK_MASK         0377777UL") != 1 or \
       source.count("        aos     1,proc_timer_clock\n") != 1 or \
       source.count("        andi    1,PROC_TIMER_CLOCK_MASK ; wrapping elapsed interval\n") != 1 or \
       source.count("        hrrm    1,proc_finish_last_tick_v881\n") != 1 or \
       REBASE_CLOCK + 1 + ACTUAL_PI6 != WRAP or \
       core["proc_timer_clock"] != 0o24530:
        raise ValueError("original 17-bit clock/epoch or fixed map drifted")
    path = work / "physical.ini"
    script = path.read_text(encoding="ascii")
    footer = "echo V1913_OPERATOR_STOP_UNREPAIRED_ORPHAN\nexit\n"
    start = "echo V1913_STAGE_PI6_12\n"
    end = "echo V1913_END_PI6_12\n"
    if not script.endswith(footer) or script.count(footer) != 1 or \
       script.count(start) != 1 or script.count(end) != 1:
        raise ValueError("original v1913 physical last PI6/controller drifted")
    shutil.copyfile(path, work / "physical-v1913.ini")
    snapshot = script.split(start,1)[1].split(end,1)[0]
    if not snapshot.startswith("examine ") or any(
            not line.startswith("examine ") for line in snapshot.splitlines()):
        raise ValueError("original v1913 MM10 snapshot not read-only")

    def witness(name):
        return ("echo V1914_STAGE_%s\n" % name + snapshot +
                "examine %06o\n" % (core["proc_timer_clock"]+1) +
                "echo V1914_END_%s\n" % name)

    clock = core["proc_timer_clock"]
    pending = clock + 2
    # Controlled simulator-time leap: both existing timer AND pending
    # retry epoch receive the same new low 17-bit clock. This preserves
    # the original 01000-tick interval and pending tag, but deliberately
    # changes time, so it is NOT a natural-run 36-minute observation.
    # No code, MM descriptor, per-process state or AC is deposited.
    append = (
        "echo V1914_REBASE_BEFORE\n" + witness("REBASE_BEFORE") +
        "deposit %06o %012o\n" % (clock,REBASE_CLOCK) +
        "deposit %06o %012o\n" %
        (pending,((0o401000<<18)|REBASE_CLOCK)) +
        "echo V1914_REBASE_AFTER\n" + witness("REBASE_AFTER") +
        "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
        "echo V1914_ORIGINAL_PI6_REBASED_IDLE\n" +
        witness("PI6_REBASED_IDLE"))
    # The previous v1913 PI6 instruction MUST first execute and
    # increment the original timer from 0377770 to 0377771.
    # Then seven distinct original PI6/idle completions straddle
    # the real 17-bit 0377777 -> 000000 wrap in hardware ticks.
    for i in range(1,ACTUAL_PI6+1):
        append += (
            "nobreak all\nbreak %06o\ncont\n" % core["proc_sched_pi_tick"] +
            "echo V1914_REAL_PI6_BEFORE_%02d\n" % i +
            "examine %06o\n" % core["pdp10_pi_level6"] +
            witness("PI6_BEFORE_%02d" % i) +
            "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
            "echo V1914_REAL_PI6_DONE_%02d\n" % i +
            witness("PI6_DONE_%02d" % i))
    # Three original capped retry scans after the physical wrap;
    # each must complete through a different idle-loop return.
    for i in range(1,AFTER_WRAP_RETRIES+1):
        append += (
            "nobreak all\nbreak %06o\ncont\n" % core["proc_finish_service_v881"] +
            "echo V1914_ORIGINAL_POST_WRAP_RETRY_%02d\n" % i +
            witness("POST_WRAP_RETRY_%02d" % i) +
            "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
            "echo V1914_ORIGINAL_POST_WRAP_RETRY_DONE_%02d\n" % i +
            witness("POST_WRAP_DONE_%02d" % i))
    append += "echo V1914_OPERATOR_STOP_WITH_FOREIGN_OWNER\nexit\n"
    if append.count("deposit ")!=2 or \
       append.count("break %06o\n" % core["proc_sched_pi_tick"])!=ACTUAL_PI6 or \
       append.count("break %06o\n" % core["proc_finish_service_v881"])!=AFTER_WRAP_RETRIES or \
       append.count("break %06o\n" % core["proc_idle_loop"])!=1+ACTUAL_PI6+AFTER_WRAP_RETRIES or \
       "024707" in append or "V1912_OWNER_REPAIR" in script:
        raise ValueError("v1914 clock-only rebase or original breakpoints invalid")
    path.write_text(script[:-len(footer)]+append,encoding="ascii")
    (work / "expected-v1914.txt").write_text(
        "clock %06o\nepoch %06o\ntimer_next %06o\npi6_pc %06o\n"
        "idle_pc %06o\nretry_pc %06o\nrebase_clock %06o\n"
        "cap %06o\nwrap %06o\nactual_pi6 %06o\npost_wrap_retries %06o\n" %
        (clock,pending,clock+1,core["proc_sched_pi_tick"],
         core["proc_idle_loop"],core["proc_finish_service_v881"],
         REBASE_CLOCK,CAP,WRAP,ACTUAL_PI6,AFTER_WRAP_RETRIES),
        encoding="ascii")
    print("v1914: synchronized timer+retry epoch -> %06o; genuine PI6 across 17-bit wrap" %
          REBASE_CLOCK)


if __name__=="__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1914.py kit build probe work prefix")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1914 clock wrap preparation: "+str(exc))

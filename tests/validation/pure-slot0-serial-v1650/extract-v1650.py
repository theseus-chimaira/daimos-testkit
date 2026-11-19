#!/usr/bin/env python3
"""Extract original slot-0 PI6 range/owner gate; make native mutants.

The passing leaf contains unmodified original scheduler instructions.
Mutations deliberately remove one security-relevant branch each.
"""

from pathlib import Path
import sys


def extract(path, output, mutation):
    source = Path(path).read_text(encoding="ascii")
    start = "proc_sched_tick_idle_check:\n"
    stop = "proc_sched_tick_ready:\n"
    assert source.count(start) == 1
    tail = source.split(start, 1)[1]
    assert tail.count(stop) == 1
    leaf = start + tail.split(stop, 1)[0]
    if mutation == "lower":
        old = "        caige   1,proc_idle_loop"
        new = "        move    1,1    ; TEST: no lower bound"
    elif mutation == "upper":
        old = "        cail    1,proc_idle_loop_end"
        new = "        move    1,1    ; TEST: no upper bound"
    elif mutation == "swap":
        old = ("        trne    1,0400                  ; do not preempt slot-0 swap I/O\n"
               "        popj    17,")
        new = ("        trne    1,0400                  ; TEST: ignore swap request\n"
               "        jrst    proc_sched_tick_ready")
    elif mutation == "none":
        old = new = ""
    else:
        raise ValueError("unrecognized mutation: " + mutation)
    if old:
        assert leaf.count(old) == 1, mutation
        leaf = leaf.replace(old, new, 1)
    intro = (".text\n"
             ".equ PROC_STACK_WATERMARK,0\n"
             ".equ PROC_TIMER_DUE_LH,0200000\n"
             ".globl proc_sched_tick_idle_check\n"
             ".globl proc_sched_tick_ready\n")
    # The real source falls directly into proc_sched_tick_ready when
    # swap ownership is absent. End the source-derived leaf at that
    # ORIGINAL next label, not at an unrelated linked fixture's main.
    # Only the continuation body is replaced by a counting stub.
    continuation = ("proc_sched_tick_ready:\n"
                    "        aos     switch_count_v1650\n"
                    "        popj    17,\n")
    Path(output).write_text(intro + leaf + continuation,
                            encoding="ascii")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: extract-v1650.py proc_pdp6.s out.s mutation")
    extract(*sys.argv[1:])

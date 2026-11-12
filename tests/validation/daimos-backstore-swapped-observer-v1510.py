#!/usr/bin/env python3
"""Source-link real post-fault slot 011 restores and SLEEP syscalls.

All edits are made to a *disposable* kernel copy after v1508/v1509
instrumentation. No production KCORE changes or runtime state growth.
"""

from pathlib import Path
import sys


def once(source, old, new, name):
    if source.count(old) != 1:
        raise ValueError("v1510: source anchor drift: " + name)
    return source.replace(old, new, 1)


def inject(root):
    proc = root / "proc/proc_pdp6.s"
    swap = root / "proc/proc_swap_pdp6.s"
    backing = root / "storage/backstore_entry_v484.s"

    source = proc.read_text()
    anchor = ("daimos_test_sleep_normal_v1150:\n"
              "        hrrz    1,1")
    replacement = ("daimos_test_sleep_normal_v1150:\n"
        "        ; v1510: a real syscall from the independently swapped\n"
        "        ; slot 011 after the original slot 010 fault.\n"
        "        move    0,proc_current_slot\n"
        "        caie    0,011\n"
        "        jrst    daimos_v1510_sleep_done\n"
        "        skipn   daimos_v1494_faults\n"
        "        jrst    daimos_v1510_sleep_done\n"
        "        aos     daimos_v1510_sleep_count\n"
        "daimos_v1510_sleep_done:\n"
        "        hrrz    1,1")
    source = once(source, anchor, replacement, "real proc_sleep_ticks")
    proc.write_text(("        .globl daimos_v1494_faults\n"
                     "        .globl daimos_v1510_sleep_count\n") + source)

    source = swap.read_text()
    for start_label, end_label, counter in (
        ("proc_swap_service_restore_done_v842:",
         "proc_swap_service_pressure:", "daimos_v1510_restore_count"),
        ("proc_swap_service_exchanged_v834:",
         "proc_swap_service_no_pair_v834:", "daimos_v1510_exchange_count"),
    ):
        if source.count(start_label) != 1 or source.count(end_label) != 1:
            raise ValueError("v1510: ambiguous service branch: " + start_label)
        start = source.index(start_label)
        end = source.index(end_label, start)
        branch = source[start:end]
        anchor = ("        pop     17,1\n"
                  "        iori    1,PROC_SCHED_READY_ONCE")
        if branch.count(anchor) != 1:
            raise ValueError("v1510: committed publish moved: " + start_label)
        label = ("daimos_v1510_restore_done" if
                 "restore" in counter else "daimos_v1510_exchange_done")
        witness = (
            "        ; v1510: only a committed, real slot 011 restore\n"
            "        ; after the selected permanent release fault counts.\n"
            "        caie    1,011\n"
            "        jrst    %s\n" % label +
            "        skipn   daimos_v1494_faults\n"
            "        jrst    %s\n" % label +
            "        aos     %s\n" % counter +
            "%s:\n" % label)
        replacement = branch.replace(anchor,
                                     "        pop     17,1\n" + witness +
                                     "        iori    1,PROC_SCHED_READY_ONCE",
                                     1)
        source = source[:start] + replacement + source[end:]
    swap.write_text(("        .globl daimos_v1494_faults\n"
                     "        .globl daimos_v1510_restore_count\n"
                     "        .globl daimos_v1510_exchange_count\n") + source)

    source = backing.read_text()
    source += ("\n; v1510 disposable physical swap contender witnesses.\n"
               "        .bss\n")
    for counter in ("restore_count", "exchange_count", "sleep_count"):
        label = "daimos_v1510_" + counter
        if label + ":" in source:
            raise ValueError("v1510: duplicate symbol " + label)
        source += "        .globl %s\n%s: .block 1\n" % (label, label)
    backing.write_text(source)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1510.py DISPOSABLE-KERNEL-ROOT")
    inject(Path(sys.argv[1]))

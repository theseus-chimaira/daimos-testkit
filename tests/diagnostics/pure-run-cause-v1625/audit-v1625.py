#!/usr/bin/env python3
"""Prove the actual v1624 sixth RUN failure was EXEC_LOAD_NOMEM.

Require a linked original RUN error-stage PC and the exact first
physical AC1 result.  This does not infer the allocator's internal
fragmentation/capacity reason, nor prove net RAW memory savings.
"""

import argparse
from pathlib import Path
import re


def audit(map_text, trace, exec_source, run_source):
    symbols = {}
    for line in map_text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
            symbols[parts[0]] = int(parts[1], 8)
    expected = {
        "proc_run_startup_failed": 0o17722,
        "proc_run_mm_bad": 0o17724,
        "proc_run_claimed_bad": 0o17725,
        "proc_run_bad": 0o17727,
        "proc_current_slot": 0o24233,
        "proc_high_slot": 0o24231,
        "proc_slots": 0o24227,
    }
    for name, address in expected.items():
        assert symbols.get(name) == address, "linked RUN stage drift: " + name
    # The source-specific -2 return is created only by the failure of
    # vm_space_create, before loading the child payload or stable u-area.
    assert re.search(r"pushj\s+17,vm_space_create\s*\n"
                     r"\s*jumpn\s+1,exec_load_nomem", exec_source)
    assert re.search(r"exec_load_nomem:\s*\n\s*move\s+1,\[-2\]",
                     exec_source)
    assert re.search(r"jumpge\s+1,proc_run_exec_ok\s*\n"
                     r"\s*;[^\n]*\n\s*jrst\s+proc_run_claimed_bad",
                     run_source)
    assert "aaaaa\nBreakpoint, PC: 017725 (" in trace
    assert "\n1:\t777777777776\n" in trace, "AC1 is not -2"
    assert "\n24231:\t000000000010\n" in trace  # proc_high_slot
    assert "\n24227:\t000000000014\n" in trace  # proc_slots
    assert "Breakpoint, PC: 017722" not in trace
    assert "Breakpoint, PC: 017724" not in trace
    assert "Breakpoint, PC: 017727" not in trace
    return "sixth RUN: EXEC_LOAD_NOMEM at vm_space_create"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kcore_map", type=Path)
    parser.add_argument("physical_trace", type=Path)
    parser.add_argument("exec_load_source", type=Path)
    parser.add_argument("proc_run_source", type=Path)
    args = parser.parse_args()
    try:
        result = audit(args.kcore_map.read_text(encoding="ascii"),
                       args.physical_trace.read_text(encoding="ascii"),
                       args.exec_load_source.read_text(encoding="ascii"),
                       args.proc_run_source.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1625 RUN stage audit: %s\n" % exc)
    print("PASS v1625 original physical RUN stage: " + result)


if __name__ == "__main__":
    main()

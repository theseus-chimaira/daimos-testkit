#!/usr/bin/env python3
"""Verify real 48K PDP-6 RAW PURE MM retype and unpin write events.

These are machine watchpoint samples, not assumptions based on a C
function entry. An optional later trace may include scheduler updates.
"""
import re
import sys
from pathlib import Path


def events(trace):
    pieces = re.split(r"(?m)^Breakpoint, PC: ([0-7]{6})[^\n]*\n", trace)
    result = []
    for i in range(1, len(pieces) - 1, 2):
        pc = int(pieces[i], 8)
        words = {}
        for address, value in re.findall(
                r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$",
                pieces[i + 1]):
            a = int(address, 8)
            v = int(value, 8)
            if a in words and words[a] != v:
                raise ValueError("inconsistent physical word %06o" % a)
            words[a] = v
        result.append((pc, words))
    return result


def audit(trace, require_scheduler):
    text = Path(trace).read_text()
    if ("PURE" not in text or "LOADED" not in text or
            "<010000+020000>" not in text):
        raise ValueError("not a real 48K TSFS PURE physical trace")
    stages = events(text)
    if len(stages) < 3:
        raise ValueError("original MM transaction did not produce 2 writes")
    expected = [
        (0o34614, 0o14000002),
        (0o34765, 0o11000002),
        (0o2467, 0o1000002),
    ]
    for i, (pc, meta) in enumerate(expected):
        actual_pc, words = stages[i]
        if actual_pc != pc or words.get(0o24307) != meta:
            raise ValueError(
                "MM transaction %d not source PC/type/pin exact" % i)
    print("PASS v1620 physical MM pre: PACKED slot 2, 1 pin")
    print("PASS v1620 physical MM commit: PROCESS slot 2, 1 pin")
    print("PASS v1620 physical MM unpin: PROCESS slot 2, 0 pins")
    if require_scheduler:
        if len(stages) < 5:
            raise ValueError("READY_ONCE/current-slot writes missing")
        # These must originate from actual physical write watchpoints.
        if stages[3][1].get(0o24235) != 0o1002:
            raise ValueError("scheduler READY_ONCE was not published")
        if stages[3][1].get(0o24307) != 0o1000002:
            raise ValueError("scheduler publication changed MM owner")
        if stages[4][1].get(0o24233) != 2:
            raise ValueError("restored process did not become current")
        if stages[4][1].get(0o24307) != 0o1000002:
            raise ValueError("resumed process MM is not unpinned PROCESS")
        print("PASS v1620 scheduler READY_ONCE slot 2 published")
        print("PASS v1620 restored PROCESS slot 2 selected as current")
    else:
        print("OPEN v1620: scheduler READY_ONCE and active RUN not sampled")


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in ("mm", "scheduler"):
        raise ValueError(
            "usage: audit-follow-v1620.py TRACE.clean mm|scheduler")
    audit(sys.argv[1], sys.argv[2] == "scheduler")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit("FAIL v1620 physical follow audit: " + str(error))

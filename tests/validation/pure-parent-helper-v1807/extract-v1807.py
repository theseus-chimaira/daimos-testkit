#!/usr/bin/env python3
"""Extract original PDP-6 parent WAIT eligibility and return tails.

K04 v1768 introduced a shared parent-eligibility leaf referenced by the
original FINALIZE body. The older PURE source-linked fixtures must link that
production leaf, not replace it with a fixture-only return value.
"""

from pathlib import Path
import sys


def extract(source, start, end):
    if source.count(start) != 1:
        raise ValueError("ambiguous production start: " + start.strip())
    tail = source.split(start, 1)[1]
    if end not in tail:
        raise ValueError("missing production end: " + end.strip())
    return start + tail.split(end, 1)[0]


def main():
    if len(sys.argv) != 3:
        raise ValueError("usage: extract-v1807.py DAIMOS OUTPUT")
    kernel = Path(sys.argv[1]) / "system/kernel"
    output = Path(sys.argv[2])
    proc = (kernel / "proc/proc_pdp6.s").read_text(encoding="ascii")
    ret = (kernel / "core/ret.s").read_text(encoding="ascii")
    body = extract(
        proc,
        "proc_parent_waitable_v1768:\n",
        "\n/**\n * @brief Release heavy process resources")
    if (body.count("        jrst    kret_one") != 1 or
            not body.rstrip().endswith("jrst    kret_one")):
        raise ValueError("parent eligibility return boundary drifted")
    tails = extract(
        ret,
        "kret_zero:\n",
        "\n/** @brief Return -1 in AC1;")
    if tails.count("kret_one:") != 1:
        raise ValueError("production return tail boundary drifted")
    output.write_text(
        ".text\n"
        ".globl proc_parent_waitable_v1768\n"
        ".globl kret_zero\n"
        ".globl kret_one\n"
        ".equ PROC_TRANSITION_RH,0200000\n"
        ".equ PROC_FDCTL_OFFSET,024\n"
        ".equ PROC_FATAL_CLOSE_BIT,4\n"
        + body + "\n" + tails,
        encoding="ascii")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1807 K04 parent extraction: " + str(exc))

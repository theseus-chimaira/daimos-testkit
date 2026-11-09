#!/usr/bin/env python3
"""Reject loop-carried PDP-6 pointers that become stale across calls.

This checks the concrete minimal C89 lowering accepted in v1395.  The
real native KCC-to-KPARSE-to-KGEN tests remain separate acceptance gates.
"""

from pathlib import Path
import re
import sys


def body(path, function):
    text = Path(path).read_text()
    marker = function + ":\n"
    if text.count(marker) != 1:
        raise AssertionError("missing or duplicate function " + function)
    return text.split(marker, 1)[1].split("\n\t.bss", 1)[0]


def check_call_full(text):
    if not re.search(r"\bpushj\s+17,fetch_value\b", text, re.I):
        raise AssertionError("expected actual call to fetch_value")
    if not re.search(r"\bmovem\s+\d+,slots-1\(\d+\)", text, re.I):
        raise AssertionError("lost safe array index after call")
    if re.search(r"\bmovei\s+\d+,slots\b", text, re.I):
        raise AssertionError("unsafe loop-carried array base with call")


def check_call_gen(text):
    if not re.search(r"\bpushj\s+17,fetch_value\b", text, re.I):
        raise AssertionError("missing call with codegen-only optimization")
    if "%L2:" not in text:
        raise AssertionError("missing expected loop label")
    preloop, loop = text.split("%L2:", 1)
    if re.search(r"\bmovei\s+\d+,slots\b", preloop, re.I):
        raise AssertionError("call-unsafe pointer retained across loop head")
    if not re.search(r"\bmovei\s+\d+,slots\b", loop, re.I):
        raise AssertionError("expected per-iteration base materialization")


def check_nocall(text):
    if "%L2:" not in text:
        raise AssertionError("missing call-free loop label")
    preloop, loop = text.split("%L2:", 1)
    if not re.search(r"\bmovei\s+\d+,slots_nocall\b", preloop, re.I):
        raise AssertionError("call-free strength reduction was lost")
    if not re.search(r"\baddi\s+\d+,1\b", loop, re.I):
        raise AssertionError("call-free induction increment was lost")


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: check-v1395.py CALL_OPT CALL_GEN NOCALL_OPT")
    try:
        check_call_full(body(argv[1], "fill_slots"))
        check_call_gen(body(argv[2], "fill_slots"))
        check_nocall(body(argv[3], "fill_nocall"))
    except AssertionError as exc:
        raise SystemExit("FAIL v1395: " + str(exc))
    print("PASS v1395: call-safe full/codegen loops; call-free induction retained")


if __name__ == "__main__":
    main(sys.argv)

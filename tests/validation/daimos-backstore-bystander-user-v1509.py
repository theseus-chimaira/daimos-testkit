#!/usr/bin/env python3
"""Keep the genuine F07 spinner alive during permanently refused swap-in.

This adjusts only the disposable F07 INIT source. Its existing independent
PID 5 executes real SLEEP syscalls; the v1150 kernel witness counts them.
TERM/WAIT still execute, but only after the extra children have been reaped.
Under a permanently failed extra child the parent cannot reach that point,
so PID 5 remains eligible for normal scheduling.
"""

from pathlib import Path
import sys


TERM = ("        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,\n"
        "                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)\n"
        "                fail('q');\n"
        "        wait_status((unsigned int)spinner, 0400001U);\n"
        "#if V1207_TEST_SWAPSLOTS\n"
        "        (void)dsys_writechar(1, '|');\n"
        "#endif\n")

TAIL = ("        if (dsys_close(extra_hold_w) != 0)\n"
        "                fail('f');\n"
        "#endif\n"
        "#endif\n"
        "#if V1204_TEST_F07_HIGH\n")


def inject(source):
    """Reorder only existing spinner teardown; preserve the real workload."""
    if source.count(TERM) != 1 or source.count(TAIL) != 1:
        raise ValueError("v1509: F07 spinner or extra-child anchor changed")
    if "v1348 disposable guest only" not in source:
        raise ValueError("v1509: v1348 spinner progress barrier missing")
    if source.index(TERM) > source.index(TAIL):
        raise ValueError("v1509: source teardown order changed")
    source = source.replace(TERM,
        "        /* v1509: retain the REAL spinner during extra-child TERM/WAIT. */\n", 1)
    source = source.replace(TAIL, TAIL.replace(
        "#if V1204_TEST_F07_HIGH\n",
        "        /* v1509: ordinary spinner TERM/WAIT if extra cleanup ends. */\n"
        + TERM + "#if V1204_TEST_F07_HIGH\n"), 1)
    if source.count(TERM) != 1 or source.index(TERM) < source.index(TAIL.splitlines()[0]):
        raise AssertionError("v1509: incorrect single owning spinner teardown")
    return source


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1509.py DISPOSABLE-F07-C")
    path = Path(sys.argv[1])
    path.write_text(inject(path.read_text()))

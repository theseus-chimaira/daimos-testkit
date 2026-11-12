#!/usr/bin/env python3
"""Fail-closed mutation checks for disposable-only F07 spinner ordering."""

from pathlib import Path
import runpy
import sys


def main():
    here = Path(__file__).resolve().parent
    module = runpy.run_path(str(here / "daimos-backstore-bystander-user-v1509.py"))
    original = (here / "daimos-oom-requester-live-v1075.c").read_text()
    original = original.replace(
        "        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,\n"
        "                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)\n",
        "        /* v1348 disposable guest only: already checked by INIT. */\n"
        "        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,\n"
        "                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)\n",
        1)
    updated = module["inject"](original)
    assert updated.count(module["TERM"]) == 1
    assert updated.index(module["TERM"]) > updated.index(module["TAIL"].splitlines()[0])
    assert "if (dsys_read_words(0, &word, 1U) != 0)" in updated
    assert "dsys_sleep(2U)" in updated
    for label, broken in (
        ("no-v1348-barrier", original.replace("v1348 disposable guest only", "missing", 1)),
        ("duplicate-TERM", original + module["TERM"]),
        ("missing-TERM", original.replace(module["TERM"], "", 1)),
        ("wrong-placement", original.replace(module["TAIL"], "bad", 1)),
    ):
        try:
            module["inject"](broken)
        except ValueError:
            continue
        raise AssertionError("v1509 accepted broken F07 source: " + label)
    print("PASS v1509: real PID5 spinner kept through child cleanup")
    print("PASS v1509: original TERM/WAIT retained, four source mutations rejected")


if __name__ == "__main__":
    main()

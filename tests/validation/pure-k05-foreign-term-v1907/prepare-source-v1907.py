#!/usr/bin/env python3
"""Add one genuine user TERM during stalled FULL; retain the typed WAIT gate."""

from pathlib import Path
import runpy
import sys


def create(kit, output):
    prior = runpy.run_path(str(kit / "tests/validation/"
                           "pure-k05-full-commit-v1903/prepare-source-v1903.py"))
    base = output.parent / "init-parent-base-v1907.c"
    prior["create"](kit,base)
    source = base.read_text(encoding="ascii")
    anchor = ("        if (v1901_term_gate != 0UL)\n"
              "            break;\n")
    if source.count(anchor)!=1 or source.count("int\nmain(")!=1:
        raise ValueError("v1903 source-linked parent heartbeat/gate drift")
    injection = ("        /* Test-only USER APR gate: this syscall is issued only\n"
                 "         * after the physical owner-fault checkpoint.\n"
                 "         * Never alter MM, a kernel return or victim state.\n"
                 "         */\n"
                 "        if (!term_sent_v1907 &&\n"
                 "                v1907_term_gate == 076543210123UL) {\n"
                 "            int rc_v1907;\n"
                 "            term_sent_v1907 = 1;\n"
                 "            rc_v1907 = dsys_procctl(\n"
                 "                SYS_PROCCTL_EVENT_PID,\n"
                 "                SYS_EVENT_ARG(3U, SYS_EVENT_TERM));\n"
                 "            (void)p14_char('T');\n"
                 "            (void)p14_char(rc_v1907 == 0 ? 'A' : 'R');\n"
                 "        }\n")
    source = source.replace(anchor, injection + anchor, 1)
    source = source.replace("int\nmain(",
             "static int term_sent_v1907;\n"
             "volatile kword_t v1907_term_gate;\n\nint\nmain(",1)
    if source.count("SYS_EVENT_ARG(3U, SYS_EVENT_TERM)")!=2 or \
            source.count("if (v1901_term_gate != 0UL)")!=1 or \
            source.count("v1907_term_gate == 076543210123UL")!=1:
        raise ValueError("native v1907 TERM or original WAIT gate not unique")
    output.write_text(source,encoding="ascii")
    print("v1907: one real parent PROCCTL TERM(3) under foreign FULL claim")


if __name__=="__main__":
    if len(sys.argv)!=3:
        raise SystemExit("usage: prepare-source-v1907.py kit output.c")
    try:
        create(Path(sys.argv[1]),Path(sys.argv[2]))
    except (OSError,ValueError) as exc:
        raise SystemExit("FAIL v1907 user source: "+str(exc))

#!/usr/bin/env python3
"""Use the genuine parent SYS_PROCCTL_EVENT_PID on quarantined slot3."""

from pathlib import Path
import runpy
import sys


def prepare(kit, out):
    original = runpy.run_path(str(kit / "tests/validation/"
               "pure-k05-resident-peer-v1892/prepare-source-v1892.py"))
    base = out.parent / "init-parent-base-v1901.c"
    original["create"](kit, base)
    src = base.read_text(encoding="ascii")
    anchor = ("        (void)p14_char('H');\n"
              "        (void)p14_char('B');\n"
              "    }\n")
    replacement = ("        (void)p14_char('H');\n"
                   "        (void)p14_char('B');\n"
                   "        /* v1901 test ONLY: after the first HB the\n"
                   "         * source-linked physical controller stops the\n"
                   "         * guest and proves slot3 TRANSITION and both\n"
                   "         * genuine MM owners before this syscall.\n"
                   "         * Use the ORIGINAL user-mode PROCCTL ABI, not\n"
                   "         * simulator deposits or a fabricated event.\n"
                   "         */\n"
                   "        if (!term_sent_v1901 &&\n"
                   "                v1901_term_gate == 012345670123UL) {\n"
                   "            int rc_v1901;\n"
                   "            term_sent_v1901 = 1;\n"
                   "            rc_v1901 = dsys_procctl(\n"
                   "                SYS_PROCCTL_EVENT_PID,\n"
                   "                SYS_EVENT_ARG(3U, SYS_EVENT_TERM));\n"
                   "            (void)p14_char('T');\n"
                   "            (void)p14_char(rc_v1901 == 0 ? 'A' : 'R');\n"
                   "        }\n"
                   "    }\n")
    if src.count(anchor) != 1 or src.count("int\nmain(") != 1:
        raise ValueError("v1901 source-matched resident parent heartbeat drift")
    src = src.replace(anchor, replacement, 1)
    src = src.replace("int\nmain(",
                      "static int term_sent_v1901;\n"
                      "/* Test-only gate in parent USER APR, never kernel RAM. */\n"
                      "volatile kword_t v1901_term_gate;\n\nint\nmain(", 1)
    if src.count("SYS_PROCCTL_EVENT_PID") != 1 or \
            src.count("SYS_EVENT_TERM") != 1 or \
            src.count("v1901_term_gate == 012345670123UL") != 1 or \
            src.count("(void)p14_char('H');") != 1:
        raise ValueError("v1901 native parent TERM path not unique")
    out.write_text(src, encoding="ascii")
    print("v1901: original five-child ROOT/PIPE/BRK parent plus one true TERM(3)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-source-v1901.py testkit output.c")
    try:
        prepare(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError) as e:
        raise SystemExit("FAIL v1901 original TERM fixture: " + str(e))

#!/usr/bin/env python3
"""Give one real F07 swapped child a delayed independent wakeup.

This changes the disposable F07 INIT image only. The child ACKs its
normal RUN/BRK first, then PID 011 (octal) sleeps past the expected
fault phase and resumes its own ordinary two-tick SLEEP loop. Every
other C child keeps the original PIPE wait and TERM lifecycle.
"""

from pathlib import Path
import sys


ANCHOR = ("                        /* Unlike a periodic sleep, an empty pipe read\n"
          "                         * stays blocked until the parent explicitly\n"
          "                         * terminates the child. Repeated timer wakeups\n"
          "                         * otherwise cause unnecessary swap-in/out churn\n"
          "                         * while the later children are being admitted. */\n")

INSERT = ("                        /* v1510 disposable child: PID 011 (octal)\n"
          "                         * is an independent delayed swap contender.\n"
          "                         * Normal RUN, BRK and ACK already occurred.\n"
          "                         * Delay beyond F07 setup; then execute real\n"
          "                         * SLEEP syscalls after the selected fault. */\n"
          "                        if (dsys_getpid() == 011U) {\n"
          "                                if (dsys_sleep(0120000U) != 0)\n"
          "                                        (void)dsys_exit(076);\n"
          "                                for (;;) {\n"
          "                                        if (dsys_sleep(2U) != 0)\n"
          "                                                (void)dsys_exit(076);\n"
          "                                }\n"
          "                        }\n")


def inject(source):
    if source.count(ANCHOR) != 1:
        raise ValueError("v1510: C-child PIPE wait anchor drift")
    if "v1509: retain the REAL spinner during extra-child TERM/WAIT" not in source:
        raise ValueError("v1510: missing v1509 resident witness")
    if source.count("if (dsys_getpid() == 011U)"):
        raise ValueError("v1510: duplicate delayed swap child")
    if source.index(ANCHOR) < source.index("if (dsys_write_words(3, &word, 1U) != 1"):
        raise ValueError("v1510: child has not completed genuine ACK")
    return source.replace(ANCHOR, INSERT + ANCHOR, 1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1510.py DISPOSABLE-F07-C")
    path = Path(sys.argv[1])
    path.write_text(inject(path.read_text()))

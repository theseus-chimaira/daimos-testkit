#!/usr/bin/env python3
"""One original parent EXIT, externally gated after foreign FULL refusal."""

from pathlib import Path
import runpy
import sys


def create(kit,output):
    previous=runpy.run_path(str(kit/"tests/validation/"
                            "pure-k05-foreign-term-v1907/prepare-source-v1907.py"))
    base=output.parent/"init-parent-base-v1910.c"
    previous["create"](kit,base)
    source=base.read_text(encoding="ascii")
    marker=("        if (v1901_term_gate != 0UL)\n"
            "            break;\n")
    replacement=("        /* v1910: only the physical controller can open this\n"
                 "         * USER APR gate after a genuine failed FULL,\n"
                 "         * foreign target claim and refused TERM. This is\n"
                 "         * the original syscall, not an MM/EXIT deposit.\n"
                 "         */\n"
                 "        if (v1910_exit_gate == 065432107654UL) {\n"
                 "            int rc_v1910;\n"
                 "            (void)p14_char('E');\n"
                 "            rc_v1910 = dsys_exit(0);\n"
                 "            /* On success the parent never returns here.\n"
                 "             * On refusal, preserve native error proof.\n"
                 "             */\n"
                 "            (void)p14_char(rc_v1910 == 0 ? 'A' : 'R');\n"
                 "            if (rc_v1910 != 0)\n"
                 "                v1910_exit_gate = 0UL;\n"
                 "        }\n")
    if source.count(marker)!=1 or source.count("int\nmain(")!=1:
        raise ValueError("original v1907 parent heartbeat/WAIT source drifted")
    source=source.replace(marker,replacement+marker,1)
    source=source.replace("int\nmain(",
        "/* v1910 test-only parent USER APR gate, not KCORE. */\n"
        "volatile kword_t v1910_exit_gate;\n\nint\nmain(",1)
    if source.count("v1910_exit_gate == 065432107654UL")!=1 or \
       source.count("dsys_exit(0)")!=2 or \
       source.count("SYS_EVENT_ARG(3U, SYS_EVENT_TERM)")!=2 or \
       source.count("if (v1901_term_gate != 0UL)")!=1:
        raise ValueError("original parent EXIT/TERM/WAIT source not unique")
    output.write_text(source,encoding="ascii")
    print("v1910: original parent USER EXIT(0) gated after foreign FULL")


if __name__=="__main__":
    if len(sys.argv)!=3:
        raise SystemExit("usage: prepare-source-v1910.py testkit output.c")
    try:
        create(Path(sys.argv[1]),Path(sys.argv[2]))
    except (OSError,ValueError,KeyError) as exc:
        raise SystemExit("FAIL v1910 original parent source: "+str(exc))

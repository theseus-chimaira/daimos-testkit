#!/usr/bin/env python3
"""Add one test-only user BRK capacity refusal after a foreign FULL fault."""

from pathlib import Path
import runpy
import sys


BRK_TARGET = 0o130000
GATE = 0o76543012765


def create(kit, output):
    previous=runpy.run_path(str(kit / "tests/validation/"
                             "pure-k05-foreign-term-v1907/prepare-source-v1907.py"))
    generated=output.parent / "init-v1907-base-v1915.c"
    previous["create"](kit,generated)
    original=generated.read_text(encoding="ascii")
    marker="        if (v1901_term_gate != 0UL)\n            break;\n"
    if original.count(marker)!=1 or \
       original.count("volatile kword_t v1901_term_gate;")!=1 or \
       original.count("dsys_brk(target) != target")!=1:
        raise ValueError("original v1907 source BRK/gate anchor drift")
    # Reuse the original test-only parent USER gate, without adding
    # another permanent or user-BSS field. The physically impossible
    # requested APR size is inside the legal 18-bit USER BRK range.
    # native_sys_brk must attribute true MM_NOMEM to the requester;
    # it must NOT reclaim a held foreign-owner target or its RAW source.
    addition=(
        "        /* v1915 TEST ONLY: one USER-mode BRK capacity request,\n"
        "         * armed by the external controller AFTER genuine foreign\n"
        "         * FULL refusal and native TERM refusal. No kernel edits.\n"
        "         */\n"
        "        if (v1901_term_gate == 076543012765UL) {\n"
        "            (void)p14_char('P');\n"
        "            (void)dsys_brk(0130000UL);\n"
        "            /* On genuine OOM the native syscall kills this\n"
        "             * requester, so reaching here is a test failure.\n"
        "             */\n"
        "            p14_fail('O');\n"
        "        }\n")
    changed=original.replace(marker,addition+marker,1)
    if changed.count("dsys_brk(0130000UL)")!=1 or \
       changed.count("v1901_term_gate == 076543012765UL")!=1 or \
       changed.count("if (v1901_term_gate != 0UL)")!=1:
        raise ValueError("original parent pressure gate not exactly once")
    output.write_text(changed,encoding="ascii")
    print("v1915: original USER BRK(0130000) one-shot OOM gate after foreign owner")


if __name__=="__main__":
    if len(sys.argv)!=3:
        raise SystemExit("usage: prepare-source-v1915.py testkit output.c")
    try:
        create(Path(sys.argv[1]),Path(sys.argv[2]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1915 test-only pressure source: "+str(exc))

#!/usr/bin/env python3
"""Test-only INIT resident parent heartbeat during genuine physical FULL."""

from pathlib import Path
import runpy
import sys


def create(kit, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    base = runpy.run_path(str(kit / "tests/validation/"
                      "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    six = output.parent / "original-six-v1892.c"
    original = runpy.run_path(str(kit / "tests/diagnostics/"
                        "pure-secondary-read-v1643/prepare-v1643.py"))
    baseline = (kit / "tests/diagnostics/pure-brk-pressure-v1614/"
                "test-v1614.c").read_text(encoding="ascii")
    six.write_text(original["generate"](baseline), encoding="ascii")
    five = output.parent / "init-five-base-v1892.c"
    base["source_v1845"](six, five)
    source = five.read_text(encoding="ascii")
    target = ("    if (dsys_close(wr) != 0)\n"
              "        p14_fail('e');\n"
              "    for (i = 0U; i < P14_CHILDREN; ++i) {\n")
    replacement = ("    if (dsys_close(wr) != 0)\n"
              "        p14_fail('e');\n"
              "    /* v1892 TEST-ONLY: the parent owns an already resident\n"
              "     * independently runnable APR. Never block it in WAIT\n"
              "     * after releasing children. The parent's user-mode\n"
              "     * heartbeat must continue after another slot becomes\n"
              "     * permanently TRANSITION-held on a corrupt MM pin.\n"
              "     * All original child creation, BRK, memory pressure,\n"
              "     * immutable source and mutable sentinel checks above\n"
              "     * remain exactly unchanged. No kernel source hooks.\n"
              "     */\n"
              "    for (;;) {\n"
              "        if (dsys_sleep(0100U) != 0)\n"
              "            p14_fail('h');\n"
              "        if (p14_data[0] != 012345670123UL ||\n"
              "            p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL)\n"
              "            p14_fail('D');\n"
              "        (void)p14_char('H');\n"
              "        (void)p14_char('B');\n"
              "    }\n"
              "    for (i = 0U; i < P14_CHILDREN; ++i) {\n")
    if source.count(target) != 1 or source.count("(void)p14_char('L');") != 1:
        raise ValueError("original five-child parent/pressure source changed")
    final = source.replace(target, replacement, 1)
    if final.count("(void)p14_char('H');") != 1 or \
            final.count("(void)p14_char('B');") != 1 or \
            final.count("#define P14_CHILDREN         5U") != 1:
        raise ValueError("heartbeat fixture is not unique five-child source")
    output.write_text(final, encoding="ascii")
    print("v1892: test-only five-child original pressure + resident parent HB")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-source-v1892.py testkit output.c")
    create(Path(sys.argv[1]), Path(sys.argv[2]))

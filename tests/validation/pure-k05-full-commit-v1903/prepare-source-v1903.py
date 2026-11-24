#!/usr/bin/env python3
"""Source-build the original five-child parent with a gated WAIT path."""

from pathlib import Path
import runpy
import sys


def create(kit, output):
    prior = runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-transition-term-v1901/prepare-source-v1901.py"))
    original = output.parent / "init-parent-base-v1903.c"
    prior["prepare"](kit, original)
    source = original.read_text(encoding="ascii")
    anchor = ("        (void)p14_char('H');\n"
              "        (void)p14_char('B');\n"
              "        /* v1901 test ONLY:")
    replacement = ("        (void)p14_char('H');\n"
                   "        (void)p14_char('B');\n"
                   "        /* Only the physical controller can open this USER\n"
                   "         * gate. The saved child executive continuation\n"
                   "         * must be restored by the original kernel first.\n"
                   "         */\n"
                   "        if (v1901_term_gate != 0UL)\n"
                   "            break;\n"
                   "        /* v1901 test ONLY:")
    if source.count(anchor) != 1 or \
            source.count("    for (i = 0U; i < P14_CHILDREN; ++i) {") != 3:
        raise ValueError("original five-child source or heartbeat changed")
    result = source.replace(anchor, replacement, 1)
    if result.count("if (v1901_term_gate != 0UL)") != 1 or \
            result.count("#define P14_CHILDREN         5U") != 1 or \
            result.count("SYS_WAIT_STATUS_KIND(status)") != 1:
        raise ValueError("test-only gate or typed WAIT source is not unique")
    output.write_text(result, encoding="ascii")
    print("v1903: original five-child parent HB and externally gated typed WAIT")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-source-v1903.py testkit output.c")
    create(Path(sys.argv[1]), Path(sys.argv[2]))

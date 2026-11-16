#!/usr/bin/env python3
"""Construct a distinct 64K P1-E lifecycle-only physical test image.

Keep the original full PIPE/WAIT/EXIT status checks, mutable sentinels
and source-backed diagnostics. Remove only the assumption that a RAW
drop must occur *during* the parent's BRK, rather than before it.
"""

from pathlib import Path
import sys


def generate(source):
    changes = (
        ("#define P14_CHILDREN         4U",
         "#define P14_CHILDREN         6U"),
        ("#define P14_BRK_TARGET       022000UL",
         "#define P14_BRK_TARGET       017000UL"),
        ("        if (pid[i] <= 1 || !p14_sleeping((unsigned int)pid[i]))\n"
         "            p14_fail('c');",
         "        if (pid[i] <= 1)\n"
         "            p14_fail('r');\n"
         "        if (!p14_sleeping((unsigned int)pid[i]))\n"
         "            p14_fail('s');"),
        ("        before.process_words + brk_words <\n"
         "            after.process_words + child_words)\n"
         "        p14_fail('R');\n"
         "    (void)p14_char('R');",
         "        before.process_words + brk_words <\n"
         "            after.process_words)\n"
         "        p14_fail('R');\n"
         "    (void)p14_char('L');"),
    )
    for before, after in changes:
        assert source.count(before) == 1, "original v1614 source changed: " + before
        source = source.replace(before, after, 1)
    assert "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS" in source
    assert "(void)p14_char('Z');" in source
    return source


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1627.py original.c output.c")
    Path(sys.argv[2]).write_text(
        generate(Path(sys.argv[1]).read_text(encoding="ascii")),
        encoding="ascii")
    print("v1627: six children, 017000 BRK, lifecycle-only L marker")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate a 48K six-child PURE/PIPE/WAIT cache-placement guest.

Only the process count, BRK pressure geometry and independent memory
accounting check change from the original v1614 C source. Child data
sentinels and the parent's exact PID/EXITED/057 checks stay intact.
"""

from pathlib import Path
import sys


def generate(original):
    edits = (
        ("#define P14_CHILDREN         4U",
         "#define P14_CHILDREN         6U"),
        ("#define P14_BRK_TARGET       022000UL",
         "#define P14_BRK_TARGET       010000UL"),
        ("        if (pid[i] <= 1 || !p14_sleeping((unsigned int)pid[i]))\n"
         "            p14_fail('c');",
         "        if (pid[i] <= 1)\n"
         "            p14_fail('r');\n"
         "        if (!p14_sleeping((unsigned int)pid[i]))\n"
         "            p14_fail('s');"),
        ("    if (target <= old_brk || dsys_brk(target) != target)",
         "    if (target != old_brk || dsys_brk(target) != target)"),
        ("        before.process_words + brk_words <\n"
         "            after.process_words + child_words)\n"
         "        p14_fail('R');\n"
         "    (void)p14_char('R');",
         "        before.process_words + brk_words <\n"
         "            after.process_words)\n"
         "        p14_fail('R');\n"
         "    (void)p14_char('L');"),
    )
    for old, new in edits:
        assert original.count(old) == 1, "changed source: " + old
        original = original.replace(old, new, 1)
    required = ("dsys_read_words(0, &word, 1U)",
                "p14_data[0] != 012345670123UL",
                "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
                "dsys_wait((unsigned int)pid[i], &status, 0U)",
                "SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED",
                "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                "(void)p14_char('Z');")
    assert all(item in original for item in required)
    return original


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1636.py original.c output.c")
    Path(sys.argv[2]).write_text(generate(Path(sys.argv[1]).read_text(
        encoding="ascii")), encoding="ascii")
    print("v1636: six children, no-growth BRK, full WAIT/data checks")


if __name__ == "__main__":
    main()

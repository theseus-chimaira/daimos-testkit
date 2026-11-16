#!/usr/bin/env python3
"""Produce five-child 48K PURE packed-restore lifecycle source.

The expected sixth RUN failure triggers genuine memory pressure but
must not terminate the parent. Original child read, sentinels,
status-057 EXIT, parent five WAIT results and data checks survive.
"""

from pathlib import Path
import sys


def generate(original):
    substitutions = (
        ("#define P14_CHILDREN         4U",
         "#define P14_CHILDREN         5U"),
        ("#define P14_BRK_TARGET       022000UL",
         "#define P14_BRK_TARGET       010000UL"),
        ("int rd, wr, pid[P14_CHILDREN], got;",
         "int rd, wr, pid[P14_CHILDREN], got, denied;"),
        ("        (void)p14_char('a');\n"
         "    }\n"
         "    if (dsys_close(rd) != 0)",
         "        (void)p14_char('a');\n"
         "    }\n"
         "    /* Demand another full VM to reclaim the five sleepers.\n"
         "     * A failed sixth RUN is EXPECTED in the genuine 48K profile.\n"
         "     * Keep the parent alive to exercise all packed restores.\n"
         "     */\n"
         "    denied = p14_spawn(rd);\n"
         "    if (denied != -1)\n"
         "        p14_fail('u');\n"
         "    (void)p14_char('x');\n"
         "    if (dsys_close(rd) != 0)"),
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
    for old, new in substitutions:
        assert original.count(old) == 1, "original source diverged: " + old
        original = original.replace(old, new, 1)
    assert "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS" in original
    assert "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL" in original
    return original


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1629.py original.c output.c")
    Path(sys.argv[2]).write_text(generate(Path(sys.argv[1]).read_text(
        encoding="ascii")), encoding="ascii")
    print("v1629: five children, expected sixth refusal, no BRK growth")


if __name__ == "__main__":
    main()

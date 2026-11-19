#!/usr/bin/env python3
"""Six admitted 48K children, then pressure from refused seventh RUN.

Keep the original exact six child PIPE/read/data/EXIT/WAIT checks.
The additional RUN must fail cleanly and leave the parent alive.
"""

from pathlib import Path
import runpy
import sys


def generate(original, v1636_generator):
    source = v1636_generator(original)
    before = ("        (void)p14_char('a');\n"
              "    }\n"
              "    if (dsys_close(rd) != 0)")
    after = ("        (void)p14_char('a');\n"
             "    }\n"
             "    /* Seventh RUN forces real RAW memory pressure; it\n"
             "     * cannot acquire a seventh complete child APR. The\n"
             "     * parent must survive and reap its six existing kids.\n"
             "     */\n"
             "    denied = p14_spawn(rd);\n"
             "    if (denied != -1)\n"
             "        p14_fail('u');\n"
             "    (void)p14_char('x');\n"
             "    if (dsys_close(rd) != 0)")
    assert source.count(before) == 1
    assert source.count("int rd, wr, pid[P14_CHILDREN], got;") == 1
    source = source.replace("int rd, wr, pid[P14_CHILDREN], got;",
                            "int rd, wr, pid[P14_CHILDREN], got, denied;", 1)
    source = source.replace(before, after, 1)
    assert "#define P14_CHILDREN         6U" in source
    assert "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS" in source
    assert "(void)p14_char('Z');" in source
    return source


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1637.py original.c output.c")
    here = Path(__file__).resolve().parent
    parent = runpy.run_path(str(here.parent /
                                 "pure-cache-low-v1636/prepare-v1636.py"))
    code = generate(Path(sys.argv[1]).read_text(encoding="ascii"),
                    parent["generate"])
    Path(sys.argv[2]).write_text(code, encoding="ascii")
    print("v1637: six admitted, seventh refused, all six WAITs checked")


if __name__ == "__main__":
    main()

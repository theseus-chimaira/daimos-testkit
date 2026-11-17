#!/usr/bin/env python3
"""Make a mixed one-plain/five-compressed 48K PURE restore workload.

Original parent and first child run plain /SYSTEM/INIT. Remaining five
children and seventh pressure attempt use the same C89 program from
compressed immutable /SYSTEM/COMP. Nothing changes child data/WAIT.
"""

from pathlib import Path
import runpy
import sys


def generate(source, v1637_generate):
    code = v1637_generate(source)
    before = ("static kword_t p14_path[3] = {\n"
              "    12UL,\n"
              "    P14_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),\n"
              "    P14_SIX6('M', '/', 'I', 'N', 'I', 'T')\n"
              "};")
    after = before + ("\nstatic kword_t p14_compressed_path[3] = {\n"
                      "    12UL,\n"
                      "    P14_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),\n"
                      "    P14_SIX6('M', '/', 'C', 'O', 'M', 'P')\n"
                      "};")
    replacements = (
        (before, after),
        ("p14_spawn(int fd)", "p14_spawn(int fd, unsigned int compressed)"),
        ("    struct sys_run_v2 *run = (struct sys_run_v2 *)block;\n"
         "    unsigned int i;",
         "    struct sys_run_v2 *run = (struct sys_run_v2 *)block;\n"
         "    kword_t *path = compressed ? p14_compressed_path : p14_path;\n"
         "    unsigned int i;"),
        ("        block[P14_PATH_OFF + i] = p14_path[i];\n"
         "        block[P14_ARG0_OFF + i] = p14_path[i];",
         "        block[P14_PATH_OFF + i] = path[i];\n"
         "        block[P14_ARG0_OFF + i] = path[i];"),
        ("        pid[i] = p14_spawn(rd);",
         "        pid[i] = p14_spawn(rd, i != 0U);"),
        ("    denied = p14_spawn(rd);",
         "    denied = p14_spawn(rd, 1U);"),
    )
    for old, new in replacements:
        assert code.count(old) == 1, "original guest changed: " + old
        code = code.replace(old, new, 1)
    for fragment in ("#define P14_CHILDREN         6U",
                     "dsys_read_words(0, &word, 1U)",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('Z');"):
        assert fragment in code
    return code


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1638.py original.c output.c")
    here = Path(__file__).resolve().parent
    prev = runpy.run_path(str(here.parent /
                            "pure-cache-pressure-v1637/prepare-v1637.py"))
    plain = Path(sys.argv[1]).read_text(encoding="ascii")
    prev2 = runpy.run_path(str(here.parent /
                            "pure-cache-low-v1636/prepare-v1636.py"))
    code = generate(plain, lambda s: prev["generate"](s,
                                                    prev2["generate"]))
    Path(sys.argv[2]).write_text(code, encoding="ascii")
    print("v1638: plain first child, five compressed children, seventh refusal")


if __name__ == "__main__":
    main()

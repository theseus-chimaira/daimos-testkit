#!/usr/bin/env python3
"""Generate a source-identical PURE guest with typed RUN/SLEEP failure.

This deliberately changes only the parent diagnostic.  The RUN and
PROCINFO/sleep-boundary outcomes must not be conflated as v1621's !c.
No production kernel or process ABI is modified.
"""

import argparse
from pathlib import Path


def generate(source, children, target):
    assert children in (5, 6)
    assert target in (0o16000, 0o17000)
    changes = (
        ("#define P14_CHILDREN         4U",
         "#define P14_CHILDREN         %dU" % children),
        ("#define P14_BRK_TARGET       022000UL",
         "#define P14_BRK_TARGET       %06oUL" % target),
        ("        if (pid[i] <= 1 || !p14_sleeping((unsigned int)pid[i]))\n"
         "            p14_fail('c');",
         "        if (pid[i] <= 1)\n"
         "            p14_fail('r');\n"
         "        if (!p14_sleeping((unsigned int)pid[i]))\n"
         "            p14_fail('s');"),
    )
    for old, new in changes:
        if source.count(old) != 1:
            raise ValueError("original source diverged: " + old)
        source = source.replace(old, new, 1)
    return source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--children", type=int, choices=(5, 6), default=5)
    parser.add_argument("--target", choices=("016000", "017000"),
                        default="017000")
    args = parser.parse_args()
    result = generate(args.source.read_text(encoding="ascii"),
                      args.children, int(args.target, 8))
    args.output.write_text(result, encoding="ascii")
    print("v1624: %d children, target %s, typed !r/!s refusals" %
          (args.children, args.target))


if __name__ == "__main__":
    main()

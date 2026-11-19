#!/usr/bin/env python3
"""Attach SIMH-only physical MM event probes to an existing boot config."""

import re
import sys
from pathlib import Path


EVENTS = (
    "mres_init", "mm_extent_insert", "mm_boot_reserve", "mm_add_free",
    "mm_free", "mm_process_shrink_pinned", "mm_process_grow_pinned",
    "mm_compact", "vm_enter_initial_user",
)
READ = ("mm_core_words", "mm_extent_capacity", "mm_extent_count",
        "mm_arena_count", "sys_resident_words_immediate")


def main(argv):
    if len(argv) != 5:
        raise ValueError("usage: make-probe-v1670.py kinit.map kcore.map "
                         "headless.ini trace.ini")
    maps = [Path(p).read_text(encoding="ascii") for p in argv[1:3]]

    def addr(name):
        values = [int(v, 8) for source in maps for v in re.findall(
            r"^" + re.escape(name) + r"\s+([0-7]+)\s*$", source,
            re.M)]
        if not values or len(set(values)) != 1:
            raise ValueError("source link symbol missing/mismatch: " + name)
        return values[0]

    commands = []
    for name in EVENTS:
        examine = ["examine %o" % addr(global_name) for global_name in READ]
        examine.extend(("examine %o-%o" %
                        (addr("mm_arenas"), addr("mm_arenas") + 2),
                        "examine %o-%o" %
                        (addr("mm_extents"), addr("mm_extents") + 79)))
        examine.append("exit" if name == "vm_enter_initial_user"
                       else "go")
        commands.append("break %06o;%s" % (addr(name), ";".join(examine)))

    source = Path(argv[3]).read_text(encoding="ascii")
    if source.count("go 020") != 1 or source.count("\nexit\n") != 1:
        raise ValueError("unexpected SIMH boot entry/exit shape")
    result = source.replace("go 020", "\n".join(commands) + "\ngo 020")
    result = result.replace("\nexit\n", "\n")
    Path(argv[4]).write_text(result, encoding="ascii")
    print("v1670: installed %d event breakpoints, terminal exit, no "
          "guest-code modifications" % len(commands))


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1670 simulator MM probe: " + str(exc))

#!/usr/bin/env python3
"""Build unsafe K05 variants only in disposable test directories."""

from pathlib import Path
import sys


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: mutate-v1839.py source old-result no-foreign")
    source = Path(sys.argv[1]).read_text(encoding="ascii")

    anchor = "        rc = mm_free(source, MM_TYPE_PACKED_PROCESS, slot);\n"
    if source.count(anchor) != 1:
        raise SystemExit("v1839 source-free call anchor drift")
    start = source.index("        switch (pram_source_free_reply_v1839(", source.index(anchor))
    end = source.index("        VM_PDP6_SET_BASE(p, target);", start)
    old = source[:start] + (
        "        if (rc != MM_OK) {\n"
        "                goto fail_target_locked;\n"
        "        }\n\n"
    ) + source[end:]
    Path(sys.argv[2]).write_text(old, encoding="ascii")

    check = (
        "                        if ((source && base < source + raw &&\n"
        "                             source < base + size) ||\n"
        "                            (target && base < target + words &&\n"
        "                             target < base + size))\n"
        "                                return -1;\n"
    )
    if source.count(check) != 1:
        raise SystemExit("v1839 foreign source guard anchor drift")
    foreign = source.replace(check, "", 1)
    Path(sys.argv[3]).write_text(foreign, encoding="ascii")


if __name__ == "__main__":
    main()

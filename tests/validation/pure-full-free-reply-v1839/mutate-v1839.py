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
    start = source.index("        if (rc != MM_OK) {", source.index(anchor))
    end = source.index("        VM_PDP6_SET_BASE(p, target);", start)
    old = source[:start] + (
        "        if (rc != MM_OK) {\n"
        "                mach_pi_restore(pi_state);\n"
        "                goto fail_target;\n"
        "        }\n\n"
    ) + source[end:]
    Path(sys.argv[2]).write_text(old, encoding="ascii")

    check = (
        "                if ((MM_EXTENT_BASE(e) == source ||\n"
        "                     MM_EXTENT_BASE(e) == target) &&\n"
        "                    (MM_EXTENT_OWNER(e) != slot ||\n"
        "                     (type != MM_TYPE_PROCESS &&\n"
        "                      type != MM_TYPE_PACKED_PROCESS)))\n"
        "                        return -1;\n"
    )
    if source.count(check) != 1:
        raise SystemExit("v1839 foreign source guard anchor drift")
    foreign = source.replace(check, "", 1)
    Path(sys.argv[3]).write_text(foreign, encoding="ascii")


if __name__ == "__main__":
    main()

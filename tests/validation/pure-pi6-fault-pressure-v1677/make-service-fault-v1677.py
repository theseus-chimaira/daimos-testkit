#!/usr/bin/env python3
"""Generate an isolated test-only PURE MRES with lost-success MM reply.

The actual original DROP/MM operations run first. Only the returned rc
is falsified once, so the production MRES owner/pin proof must recover
without discarding the existing PACKED process. No kernel tree edit.
"""
from pathlib import Path
import sys


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: make-service-fault-v1677.py source.c out.c")
    src = Path(sys.argv[1]).read_text(encoding="ascii")
    if src.count("rc = proc_pure_ram_drop_v1381(slot);") != 1:
        raise SystemExit("v1677 source-matched DROP call changed")
    anchor = "#define PPURE_COOLDOWN_V1612 0100UL\n"
    if src.count(anchor) != 1:
        raise SystemExit("v1677 source-matched MRES marker changed")
    src = src.replace(anchor, anchor + "\n/* Test-only MRES data, never installed into default KCORE. */\n"
                      "kword_t v1677_fault_return_count;\n", 1)
    replacement = """rc = proc_pure_ram_drop_v1381(slot);
                /* Test-only lost-success result: the actual MM owner
                 * has already committed its unpin/rebase correctly.
                 * Do not fake an impossible concurrent user return.
                 */
                if (rc == MM_OK && !v1677_fault_return_count) {
                        v1677_fault_return_count = 1UL;
                        rc = MM_ERR_BUSY;
                }"""
    src = src.replace("rc = proc_pure_ram_drop_v1381(slot);",
                      replacement, 1)
    Path(sys.argv[2]).write_text(src, encoding="ascii")


if __name__ == "__main__":
    main()

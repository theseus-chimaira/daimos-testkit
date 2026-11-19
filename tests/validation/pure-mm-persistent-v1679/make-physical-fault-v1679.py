#!/usr/bin/env python3
"""Create test-only repeated original MM rebase refusals on child slot 2."""
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise ValueError("usage: make-physical-fault-v1679.py original.c out.c")
    src = Path(sys.argv[1]).read_text(encoding="ascii")
    marker = '#include "mm_pure_rebase_v1381.h"\n'
    if src.count(marker) != 1:
        raise ValueError("v1679 source-matched MM include changed")
    src = src.replace(marker, marker +
        "\n/* Optional MRES test witness; no permanent KCORE words. */\n"
        "kword_t v1679_rebase_fault_count;\n", 1)
    old = """        rc = mm_pure_rebase_pinned_v1381(source, slot, skip, words);
        if (rc == MM_OK) {"""
    new = """        /* Only this one real sleeping RESIDENT owner is refused.
         * Every retry executes the original MM assembler with sector
         * geometry rejected BEFORE its descriptor writes. This call
         * must not fake a failed result or invent a second MM owner. */
        if (slot == 2U) {
                rc = mm_pure_rebase_pinned_v1381(source, slot,
                    skip + 1UL, words);
                if (rc == MM_ERR_INVAL)
                        ++v1679_rebase_fault_count;
        } else {
                rc = mm_pure_rebase_pinned_v1381(source, slot,
                    skip, words);
        }
        if (rc == MM_OK) {"""
    if src.count(old) != 1:
        raise ValueError("v1679 source-matched actual MM rebase changed")
    Path(sys.argv[2]).write_text(src.replace(old, new, 1), encoding="ascii")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1679 physical source generator: " + str(exc))

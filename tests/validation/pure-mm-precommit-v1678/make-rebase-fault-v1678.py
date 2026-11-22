#!/usr/bin/env python3
"""Source-linked test-only PDP-6 MM rebase rejection, no fake return.

The original rebase assembler runs with invalid prefix geometry exactly
once, really rejects, then the original C DROP cleanup releases the pin.
Generated source belongs exclusively in a disposable DAIMOS build copy.
"""
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: make-rebase-fault-v1678.py source.c out.c")
    src = Path(sys.argv[1]).read_text(encoding="ascii")
    marker = "#include \"mm_pure_rebase_v1381.h\"\n"
    if src.count(marker) != 1:
        raise ValueError("v1678 expected original MM source include")
    src = src.replace(marker, marker +
                      "\n/* Test-only optional MRES witness, not KCORE. */\n"
                      "kword_t v1678_rebase_fault_count;\n", 1)
    old = """        rc = mm_pure_rebase_pinned_v1381(source, slot, skip, words);
        if (rc == MM_OK) {"""
    new = """        /* Invoke the REAL MM primitive with invalid 0200-sector
         * geometry for exactly the first DROP. The original assembler
         * must refuse before either MM descriptor store. The normal
         * post-failure C path must release the valid original pin. */
        if (v1678_rebase_fault_count == 0UL) {
                rc = mm_pure_rebase_pinned_v1381(source, slot,
                    skip + 1UL, words);
                if (rc == MM_ERR_INVAL)
                        v1678_rebase_fault_count = 1UL;
        } else {
                rc = mm_pure_rebase_pinned_v1381(source, slot,
                    skip, words);
        }
        if (rc == MM_OK) {"""
    if src.count(old) != 1:
        raise ValueError("v1678 original rebase call changed")
    Path(sys.argv[2]).write_text(src.replace(old, new, 1), encoding="ascii")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1678 source-linked injection: " + str(exc))

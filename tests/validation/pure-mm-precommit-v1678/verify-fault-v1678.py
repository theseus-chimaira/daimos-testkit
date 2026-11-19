#!/usr/bin/env python3
"""Independent physical proof of one actual injected PURE MRES fault.

The source-linked original KCORE JRST is the runtime address witness;
no fixed location for the relocated optional PURE MRES is assumed.
"""
import re
import sys
from pathlib import Path


def symbol(path, name):
    text = Path(path).read_text(encoding="ascii")
    found = re.findall(r"^" + re.escape(name) + r"\s+([0-7]+)\s*$",
                       text, re.M)
    if len(found) != 1:
        raise ValueError("missing unique original symbol " + name)
    return int(found[0], 8)


def verify(console, coremap, puremap):
    text = Path(console).read_text(encoding="ascii")
    begin = text.index("V1673 HOLD B")
    end = text.index("V1673 RELEASE B", begin)
    sample = text[begin:end]

    def word(addr):
        pat = r"^(?:sim> )?%o:\s+([0-7]{12})\s*$" % addr
        values = re.findall(pat, sample, re.M)
        if len(values) != 1:
            raise ValueError("missing/duplicate physical word %o" % addr)
        return int(values[0], 8)

    jump = word(symbol(coremap, "proc_swap_reclaim"))
    if jump >> 27 != 0o254:
        raise ValueError("service entry is not original patched JRST")
    entry = jump & 0o777777
    local = symbol(puremap, "proc_pure_mres_reclaim_v1612")
    counter = symbol(puremap, "v1678_rebase_fault_count")
    core = word(symbol(coremap, "mm_core_words"))
    physical = entry - local + counter
    if not 0 < physical < core:
        raise ValueError("service entry cannot locate valid MRES counter")
    observed = word(physical)
    if observed != 1:
        raise ValueError("MM-rebase-refusal fault fired %o times (expected 1)" %
                         observed)
    return physical


def main():
    if len(sys.argv) != 4:
        raise ValueError("usage: verify-fault-v1678.py physical.clean "
                         "kcore.map pure-mres.map")
    at = verify(*sys.argv[1:])
    print("PASS v1678: original installed PURE MRES counter at %o = 1" % at)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, UnicodeError, OSError) as exc:
        raise SystemExit("FAIL v1678 original physical fault witness: " +
                         str(exc))

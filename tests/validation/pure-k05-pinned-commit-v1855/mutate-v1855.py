#!/usr/bin/env python3
"""Two unsafe original-source FULL commit edits, for native execution."""

from pathlib import Path
import sys


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: mutate-v1855.py production.c no-guard.c weak-pin.c")
    source = Path(argv[1]).read_text(encoding="ascii")
    guard = ("if (pram_exact_owner_set_v1855(slot, source, raw,\n"
             "            target, words, 1U) != 3) {")
    copy_guard = ("if (proc_pure_full_owners_v1917(slot, source, raw, "
                  "target, words,\n            1U, 1U) != 3)")
    pin = "if (MM_EXTENT_PINS(e) != pins)"
    if source.count(guard) != 1 or source.count(pin) != 1:
        raise SystemExit("v1855 source anchors drifted: refuse mutant")
    changed = source.replace(guard, "if (0) {", 1)
    if copy_guard in source:
        assert source.count(copy_guard) == 1
        changed = changed.replace(copy_guard, "if (0)", 1)
    Path(argv[2]).write_text(changed,
                             encoding="ascii")
    # Preserve the original 0-pin v1839 free-reply test while
    # intentionally accepting extra pins at the new precommit check.
    Path(argv[3]).write_text(source.replace(pin,
        "if (pins == 0U ? MM_EXTENT_PINS(e) != 0U :\n"
        "                    MM_EXTENT_PINS(e) == 0U)", 1), encoding="ascii")
    print("v1855: created no-guard and weakened-original-MM-pin mutants")


if __name__ == "__main__":
    main(sys.argv)

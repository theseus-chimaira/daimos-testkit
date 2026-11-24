#!/usr/bin/env python3
"""Reintroduce old post-publication destination unpin in a throwaway copy.

The genuine source-linked v1395 native target-unpin case must reject the
old ordering. Never modify or install the original production source.
"""

from pathlib import Path
import sys


def mutate(original):
    early = (
        "        rc = mm_unpin(target);\n"
        "        if (rc != MM_OK) {\n"
        "                target_uncertain = 1;\n"
        "                goto fail_target_locked;\n"
        "        }\n"
        "        target_pinned = 0;\n"
    )
    late = (
        "        pram_publish(slot, PROC_STORAGE_PACKED, PROC_STORAGE_RESIDENT);\n"
        "        u[PROC_FINALIZE_OFFSET] = 0UL;\n"
        "        PROC_CLEAR_TRANSITION(p);\n"
    )
    assert original.count(early) == 1
    assert original.count(late) == 1
    # v1855's exact-owner/pin preflight now sits between PI exclusion
    # and the target unpin. Keep that new guard in the unsafe variant;
    # move ONLY the original unpin block behind RESIDENT publication.
    # Removing the new guard would make the historical v1654 mutant
    # accidentally test v1855's different overpin failure instead.
    changed = original.replace(early, "", 1)
    changed = changed.replace(
        late,
        "        pram_publish(slot, PROC_STORAGE_PACKED, PROC_STORAGE_RESIDENT);\n"
        "        rc = mm_unpin(target);\n"
        "        if (rc != MM_OK) {\n"
        "                mach_pi_restore(pi_state);\n"
        "                return MM_ERR_BUSY;\n"
        "        }\n"
        "        target_pinned = 0;\n"
        "        u[PROC_FINALIZE_OFFSET] = 0UL;\n"
        "        PROC_CLEAR_TRANSITION(p);\n", 1)
    assert changed != original
    return changed


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: mutate-v1654.py original.c bad.c")
    source = Path(sys.argv[1]).read_text(encoding="ascii")
    Path(sys.argv[2]).write_text(mutate(source), encoding="ascii")

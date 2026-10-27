#!/usr/bin/env python3
"""Guard native PDP-6 APR mapping and exact-size MM allocation contracts.

This is a source contract regression, not a substitute for native SIMH/AAP
memory-pressure tests. In particular, it does not claim 512-word user maps.
"""

import os
import pathlib
import re
import sys


def require(pattern, source, description):
    if re.search(pattern, source, re.MULTILINE) is None:
        raise AssertionError(description)


def main():
    root = os.environ.get("DAIMOS_REPO")
    if not root:
        raise SystemExit("DAIMOS_REPO must point to the DAIMOS checkout")
    root = pathlib.Path(root)
    mm = (root / "system/kernel/mm/mm.c").read_text()
    vm_h = (root / "system/kernel/proc/vm.h").read_text()
    vm_s = (root / "system/kernel/proc/vm_pdp6.s").read_text()
    swap_s = (root / "system/kernel/proc/proc_swap_pdp6.s").read_text()
    require(r"return\s+mm_alloc_aligned\(words,\s*1UL,", mm,
            "unaligned MM allocations must retain one-word alignment")
    require(r"#define\s+VM_EXTENT_ALIGN_WORDS\s+02000UL\b", vm_h,
            "native APR user-VM alignment must remain 02000 octal")
    require(r"andi\s+15,0776000", vm_s,
            "BRK extent rounding must retain APR-aligned mask")
    require(r"\.equ\s+VM_PDP6_ALIGN_WORDS,02000", swap_s,
            "swap/restoration must retain APR alignment")
    require(r"mm_move_extent\(i,\s*VM_EXTENT_ALIGN_WORDS\)", mm,
            "compaction must respect process APR alignment")
    print("PASS: MM exact-size allocation and native 1024-word APR contracts")
    print("NOTE: source guard only; native allocation/fragmentation tests remain required")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env python3
"""Inject one MEMFS data-destroy preflight refusal in an isolated source copy.

This is a test-only boundary. The first unmount must preserve every
resource and the VFS mount. Subsequent unmounts execute the production
MEMFS data-destroy code unchanged. The counter is in the test-only MRES
BSS, immediately after the three-word singleton state. It also serves
as a canary for writes past memfs_mres_fs.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: ... original/memfs_runtime.s copy/memfs_runtime.s")
original = Path(sys.argv[1]).read_text()
dest = Path(sys.argv[2])
anchor = ("        pushj   17,memfs_data_destroy"
          "   ; release demand-allocated data chunks")
if original.count(anchor) != 1:
    raise SystemExit("v1475: production MEMFS preflight boundary changed")
source = original.replace(
    anchor,
    "        pushj   17,daimos_test_data_destroy_v1475"
    "   ; test-only preflight", 1)
source += """
; v1475 ISOLATED TEST: refuse the first preflight without changing
; any resource, vnode, XIP pin, backing allocation or VFS mount record.
        .text
        .globl daimos_test_unmount_preflight_v1475
daimos_test_data_destroy_v1475:
        skipn   daimos_test_unmount_preflight_v1475
        jrst    daimos_test_data_destroy_refuse_v1475
        jrst    memfs_data_destroy
daimos_test_data_destroy_refuse_v1475:
        aos     daimos_test_unmount_preflight_v1475
        seto    1,
        popj    17,
        .bss
daimos_test_unmount_preflight_v1475: .block 1
"""
dest.write_text(source)
print("v1475: isolated preflight refusal installed")

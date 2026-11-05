#!/usr/bin/env python3
"""Temporary full-system PDP-6 tests of the REAL backstore allocator.

The dispatch source is from a disposable kernel tree. No production
syscall, MM allocator, backstore implementation or OOM setting changes.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])
dispatch = root / 'proc/syscall_dispatch_pdp6.s'
source = dispatch.read_text()
anchor = '''native_sys_brk:
        move    1,2
        pushj   17,vm_space_brk_current'''
replacement = '''native_sys_brk:
        ; v1156: temporary private selectors for real swap-bitmap tests.
        camn    2,[0777760]
        jrst    daimos_test_backing_fill_v1156
        camn    2,[0777761]
        jrst    daimos_test_backing_free_v1156
        move    1,2
        pushj   17,vm_space_brk_current'''
assert source.count(anchor) == 1, 'v1156: BRK entry changed'
source = source.replace(anchor, replacement, 1)
source += '''
        .text
        .globl  backstore_alloc
        .globl  backstore_free
        .globl  backstore_enabled
        .globl  backstore_blocks
        .globl  backstore_blocks_used

daimos_test_backing_fill_v1156:
        skipn   backstore_enabled
        jrst    daimos_test_backing_fail_v1156
        skipn   backstore_blocks
        jrst    daimos_test_backing_fail_v1156
        skipn   backstore_blocks_used
        jrst    daimos_test_backing_empty_v1156
        jrst    daimos_test_backing_fail_v1156
daimos_test_backing_empty_v1156:
        move    1,backstore_blocks
        movem   1,daimos_test_count_v1156
        setz    2,
        movei   3,daimos_test_first_v1156
        pushj   17,backstore_alloc
        jumpn   1,daimos_test_backing_fail_v1156
        move    1,backstore_blocks_used
        came    1,backstore_blocks
        jrst    daimos_test_backing_fail_v1156
        ; A full authoritative bitmap must reject a new real block.
        setom   daimos_test_try_v1156
        movei   1,1
        setz    2,
        movei   3,daimos_test_try_v1156
        pushj   17,backstore_alloc
        camn    1,[-1]
        jrst    daimos_test_backing_refused_v1156
        jrst    daimos_test_backing_fail_v1156
daimos_test_backing_refused_v1156:
        move    1,daimos_test_try_v1156
        camn    1,[-1]
        jrst    daimos_test_backing_unchanged_v1156
        jrst    daimos_test_backing_fail_v1156
daimos_test_backing_unchanged_v1156:
        move    1,backstore_blocks_used
        came    1,backstore_blocks
        jrst    daimos_test_backing_fail_v1156
        setz    1,
        popj    17,

daimos_test_backing_free_v1156:
        move    1,daimos_test_first_v1156
        move    2,daimos_test_count_v1156
        jumpe   2,daimos_test_backing_fail_v1156
        pushj   17,backstore_free
        skipn   backstore_blocks_used
        jrst    daimos_test_backing_released_v1156
        jrst    daimos_test_backing_fail_v1156
daimos_test_backing_released_v1156:
        setzm   daimos_test_count_v1156
        ; An allocation after full release must succeed at block zero.
        movei   1,1
        setz    2,
        movei   3,daimos_test_try_v1156
        pushj   17,backstore_alloc
        jumpn   1,daimos_test_backing_fail_v1156
        skipn   daimos_test_try_v1156
        jrst    daimos_test_backing_reuse_v1156
        jrst    daimos_test_backing_fail_v1156
daimos_test_backing_reuse_v1156:
        setz    1,
        movei   2,1
        pushj   17,backstore_free
        skipn   backstore_blocks_used
        jrst    daimos_test_backing_pass_v1156
        jrst    daimos_test_backing_fail_v1156
daimos_test_backing_pass_v1156:
        setz    1,
        popj    17,
daimos_test_backing_fail_v1156:
        seto    1,
        popj    17,

        .bss
daimos_test_first_v1156: .block 1
daimos_test_count_v1156: .block 1
daimos_test_try_v1156: .block 1
'''
dispatch.write_text(source)

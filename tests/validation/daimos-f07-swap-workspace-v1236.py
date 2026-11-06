#!/usr/bin/env python3
"""Trace whether swap overwrites shared VFS workspace during D6FS read.

Disposable KCORE-only counter counts swap workspace acquisitions. The
D6FS read captures the counter before and after fs_backing_read; the
FCB copy freezes those values before cleanup can overwrite them.
"""
from pathlib import Path
import sys

FIELDS = ('scratch_calls', 'read_before', 'read_after',
          'read_block', 'read_status', 'read_meta',
          'fcb_before', 'fcb_after', 'fcb_block', 'fcb_status',
          'fcb_meta')

def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('v1236 source layout changed: ' + old[:70])
    return text.replace(old, new, 1)

def inject(root):
    p = root / 'proc/proc_swap_pdp6.s'
    s = p.read_text()
    s = once(s, 'proc_swap_exchange_sector_v771:\n',
              'proc_swap_exchange_sector_v771:\n'
              '        aos     daimos_f07w_scratch_calls_v1236\n')
    s = once(s, 'proc_swap_verify_block:\n',
              'proc_swap_verify_block:\n'
              '        aos     daimos_f07w_scratch_calls_v1236\n')
    s = '        .globl daimos_f07w_scratch_calls_v1236\n' + s
    p.write_text(s)

    p = root / 'fs/d6fs_runtime.s'
    s = p.read_text()
    a = s.index('\nd6fs_reader_get_block:\n')
    b = s.index('\n        .globl  d6fs_reader_fcb', a)
    sec = s[a:b]
    anchor = ('        move    2,011\n'
              '        movei   3,fs_block_workspace     ; shared transfer block\n'
              '        pushj   17,fs_backing_read\n'
              '        jumpn   1,d6fs_get_block_read_fail\n')
    replace = """        move    2,011
        movei   3,fs_block_workspace     ; shared transfer block
        move    0,daimos_f07w_scratch_calls_v1236
        movem   0,daimos_f07w_read_before_v1236
        movem   011,daimos_f07w_read_block_v1236
        pushj   17,fs_backing_read
        movem   1,daimos_f07w_read_status_v1236
        move    0,daimos_f07w_scratch_calls_v1236
        movem   0,daimos_f07w_read_after_v1236
        move    0,fs_block_workspace+0160
        movem   0,daimos_f07w_read_meta_v1236
        jumpn   1,d6fs_get_block_read_fail
"""
    sec = once(sec, anchor, replace)
    s = s[:a] + sec + s[b:]
    a = s.index('\nd6fs_reader_fcb:\n')
    b = s.index('\n        .globl  d6fs_reader_put_fcb', a)
    sec = s[a:b]
    anchor = '        movem   0,daimos_f07h_fcb_workspace_tag_v1235\n'
    replacement = anchor + """        move    0,daimos_f07w_read_before_v1236
        movem   0,daimos_f07w_fcb_before_v1236
        move    0,daimos_f07w_read_after_v1236
        movem   0,daimos_f07w_fcb_after_v1236
        move    0,daimos_f07w_read_block_v1236
        movem   0,daimos_f07w_fcb_block_v1236
        move    0,daimos_f07w_read_status_v1236
        movem   0,daimos_f07w_fcb_status_v1236
        move    0,daimos_f07w_read_meta_v1236
        movem   0,daimos_f07w_fcb_meta_v1236
"""
    sec = once(sec, anchor, replacement)
    s = s[:a] + sec + s[b:]
    for n in FIELDS:
        s = '        .globl daimos_f07w_%s_v1236\n' % n + s
    p.write_text(s)

    p = root / 'proc/proc_pdp6.s'
    s = p.read_text() + '\n        .bss\n'
    for n in FIELDS:
        sym = 'daimos_f07w_%s_v1236' % n
        s += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    p.write_text(s)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1236 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

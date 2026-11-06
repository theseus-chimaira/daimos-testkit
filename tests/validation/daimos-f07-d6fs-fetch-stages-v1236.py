#!/usr/bin/env python3
"""Observe the exact block-0741 D6FS miss before/after backing and cache store.

This modifies only a copied, disposable PDP-6 kernel.  The probe never
changes the status, cache lookup, ownership, or production data path.
"""

from pathlib import Path
import sys


FIELDS = ('reads', 'status', 'before_read', 'after_read', 'after_store',
          'zero_after_read')


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('v1236: D6FS fetch control point changed')
    return source.replace(old, new, 1)


def inject(root):
    path = root / 'fs/d6fs_runtime.s'
    src = path.read_text()
    anchor = '''        movei   1,013(010)               ; embedded struct fs_backing
        move    2,011
        movei   3,fs_block_workspace     ; shared transfer block
        pushj   17,fs_backing_read
        jumpn   1,d6fs_get_block_read_fail
        move    1,012
        movei   2,fs_block_workspace
        pushj   17,bcache_store          ; miss becomes a clean cache entry
        movei   1,fs_block_workspace
'''
    modified = '''        move    7,011
        caie    7,0741                  ; failing FCB 037, diagnostic only
        jrst    daimos_f07x_before_done_v1236
        move    7,fs_block_workspace+0160
        movem   7,daimos_f07x_before_read_v1236
daimos_f07x_before_done_v1236:
        movei   1,013(010)               ; embedded struct fs_backing
        move    2,011
        movei   3,fs_block_workspace     ; shared transfer block
        pushj   17,fs_backing_read
        move    7,011
        caie    7,0741
        jrst    daimos_f07x_after_done_v1236
        aos     daimos_f07x_reads_v1236
        movem   1,daimos_f07x_status_v1236
        move    7,fs_block_workspace+0160
        movem   7,daimos_f07x_after_read_v1236
        skipn   7
        aos     daimos_f07x_zero_after_read_v1236
daimos_f07x_after_done_v1236:
        jumpn   1,d6fs_get_block_read_fail
        move    1,012
        movei   2,fs_block_workspace
        pushj   17,bcache_store          ; miss becomes a clean cache entry
        move    7,011
        caie    7,0741
        jrst    daimos_f07x_store_done_v1236
        move    7,fs_block_workspace+0160
        movem   7,daimos_f07x_after_store_v1236
daimos_f07x_store_done_v1236:
        movei   1,fs_block_workspace
'''
    src = replace_once(src, anchor, modified)
    src = ''.join('        .globl daimos_f07x_%s_v1236\n' % name
                  for name in FIELDS) + src
    path.write_text(src)

    core = root / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for name in FIELDS:
        sym = 'daimos_f07x_%s_v1236' % name
        text += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1236 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

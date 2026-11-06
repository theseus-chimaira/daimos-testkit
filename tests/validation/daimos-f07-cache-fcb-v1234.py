#!/usr/bin/env python3
"""Trace FCB workspace data and BCACHE source during disposable D6FS reads.

The source is snapshotted before the FCB BLT, and the cache selection
records whether the last fetch was workspace hit, private hit, or miss.
No kernel allocation, lock, process state or return path is modified.
"""
from pathlib import Path
import sys

FIELDS = ('last_key', 'cache_path', 'fcb_source_meta',
          'workspace_meta', 'fcb_index', 'fcb_block')

def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('v1234: source layout changed: ' + old[:70])
    return text.replace(old, new, 1)

def inject(root):
    p = root / 'storage/bcache_pdp6.s'
    s = p.read_text()
    s = once(s, 'bcache_fetch:\n', """bcache_fetch:
        setzm   daimos_f07b_cache_path_v1234
        movem   1,daimos_f07b_last_key_v1234
""")
    s = once(s, 'bcache_fetch_slot0:\n', """bcache_fetch_slot0:
        movei   0,1
        movem   0,daimos_f07b_cache_path_v1234
""")
    s = once(s, 'bcache_fetch_slot1:\n', """bcache_fetch_slot1:
        movei   0,2
        movem   0,daimos_f07b_cache_path_v1234
""")
    s = once(s, 'bcache_fetch_miss_ready:\n', """bcache_fetch_miss_ready:
        movei   0,3
        movem   0,daimos_f07b_cache_path_v1234
""")
    for n in FIELDS:
        s = '        .globl daimos_f07b_%s_v1234\n' % n + s
    p.write_text(s)

    p = root / 'fs/d6fs_runtime.s'
    s = p.read_text()
    a = s.index('\nd6fs_reader_fcb:\n')
    b = s.index('\n        .globl  d6fs_reader_put_fcb', a)
    sec = s[a:b]
    sec = once(sec, '        move    013,2                    ; index\n',
               '        move    013,2                    ; index\n        movem   2,daimos_f07b_fcb_index_v1234\n')
    sec = once(sec, '        move    2,5\n        move    1,010\n        movem   2,daimos_f07c_block_v1232\n        pushj   17,d6fs_reader_get_block\n',
               '        move    2,5\n        move    1,010\n        movem   2,daimos_f07c_block_v1232\n        movem   2,daimos_f07b_fcb_block_v1234\n        pushj   17,d6fs_reader_get_block\n')
    sec = once(sec, '        add     1,6                      ; source FCB in cache\n',
               '        add     1,6                      ; source FCB in cache\n'
               '        move    0,(1)\n        movem   0,daimos_f07b_fcb_source_meta_v1234\n'
               '        move    0,fs_block_workspace+0160\n'
               '        movem   0,daimos_f07b_workspace_meta_v1234\n')
    s = s[:a] + sec + s[b:]
    for n in FIELDS:
        s = '        .globl daimos_f07b_%s_v1234\n' % n + s
    p.write_text(s)

    p = root / 'proc/proc_pdp6.s'
    s = p.read_text() + '\n        .bss\n'
    for n in FIELDS:
        sym = 'daimos_f07b_%s_v1234' % n
        s += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    p.write_text(s)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1234 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

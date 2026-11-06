#!/usr/bin/env python3
"""Freeze the BCACHE path at the D6FS FCB copy, before failure cleanup.

v1234's last-cache counters can be overwritten by subsequent VFS
operations. This disposable extension records the cache key, path
and workspace tag at the same instant as the FCB word.
"""
from pathlib import Path
import sys

FIELDS = ('fcb_key', 'fcb_cache_path', 'fcb_workspace_tag')

def inject(root):
    b = root / 'storage/bcache_pdp6.s'
    source = b.read_text()
    anchor = 'bcache_workspace_tag: .block 1'
    if source.count(anchor) != 1:
        raise ValueError('v1235: workspace cache tag moved')
    b.write_text(source.replace(anchor,
        '        .globl bcache_workspace_tag\n' + anchor, 1))

    p = root / 'fs/d6fs_runtime.s'
    source = p.read_text()
    anchor = '        movem   0,daimos_f07b_workspace_meta_v1234\n'
    if source.count(anchor) != 1:
        raise ValueError('v1235: v1234 FCB copy snapshot moved')
    source = source.replace(anchor, anchor + """        move    0,daimos_f07b_last_key_v1234
        movem   0,daimos_f07h_fcb_key_v1235
        move    0,daimos_f07b_cache_path_v1234
        movem   0,daimos_f07h_fcb_cache_path_v1235
        move    0,bcache_workspace_tag
        movem   0,daimos_f07h_fcb_workspace_tag_v1235
""", 1)
    source = '        .globl bcache_workspace_tag\n' + source
    for field in FIELDS:
        source = ('        .globl daimos_f07h_%s_v1235\n' % field) + source
    p.write_text(source)

    p = root / 'proc/proc_pdp6.s'
    source = p.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07h_%s_v1235' % field
        source += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    p.write_text(source)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1235 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

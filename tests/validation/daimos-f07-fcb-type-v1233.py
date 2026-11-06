#!/usr/bin/env python3
"""Capture FCB metadata and decoded type at a failing D6FS EXEC read.

The counters are populated in the disposable D6FS MRES and kept in
disposable KCORE. They do not change any branch, result or stack frame.
"""
from pathlib import Path
import sys

FIELDS = ('raw_meta', 'decoded_type', 'decoded_flags',
          'decoded_size', 'fcb_copy', 'reader', 'type_samples')

def inject(root):
    p = root / 'fs/d6fs_runtime.s'
    s = p.read_text()
    a = s.index('\nd6fs_provider_read_words:\n')
    b = s.index('\n; int d6fs_provider_sync', a)
    sec = s[a:b]
    anchor = ('        move    1,-014(17)               ; info.type\n'
              '        cain    1,1                      ; D6FS_TYPE_REG\n')
    if sec.count(anchor) != 1:
        raise ValueError('v1233: D6FS read type check moved')
    sec = sec.replace(anchor, """        ; Read-only v1233 snapshot at the actual FCB/type gate.
        aos     daimos_f07t_type_samples_v1233
        move    0,-034(17)
        movem   0,daimos_f07t_raw_meta_v1233
        move    0,-033(17)
        movem   0,daimos_f07t_fcb_copy_v1233
        move    0,-013(17)
        movem   0,daimos_f07t_decoded_flags_v1233
        move    0,-005(17)
        movem   0,daimos_f07t_decoded_size_v1233
        move    0,d6fs_active_reader
        movem   0,daimos_f07t_reader_v1233
        move    1,-014(17)               ; info.type
        movem   1,daimos_f07t_decoded_type_v1233
        cain    1,1                      ; D6FS_TYPE_REG
""", 1)
    s = s[:a] + sec + s[b:]
    for n in FIELDS:
        s = '        .globl daimos_f07t_%s_v1233\n' % n + s
    p.write_text(s)
    p = root / 'proc/proc_pdp6.s'
    s = p.read_text() + '\n        .bss\n'
    for n in FIELDS:
        sym = 'daimos_f07t_%s_v1233' % n
        s += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    p.write_text(s)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1233 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

#!/usr/bin/env python3
"""D6FS FCB failure classification in a disposable PDP-6 kernel.

Only original failure branches get a reason:
1 null reader, 2 null info, 3 out-of-range index,
4 missing FCB block, 5 invalid FCB decode, 6 invalid file type.
"""
from pathlib import Path
import sys

FIELDS = ('reason', 'index', 'limit', 'block', 'block_fail',
          'decode_fail', 'type_fail', 'fcb_calls')

def replace_one(text, old, new):
    if text.count(old) != 1:
        raise ValueError('v1232 source layout changed: ' + old[:64])
    return text.replace(old, new, 1)

def inject(root):
    p = root / 'fs/d6fs_runtime.s'
    s = p.read_text()
    a = s.index('\nd6fs_reader_fcb:\n')
    b = s.index('\n        .globl  d6fs_reader_put_fcb', a)
    sec = s[a:b]
    sec = replace_one(sec, 'd6fs_reader_fcb:\n', """d6fs_reader_fcb:
        aos     daimos_f07c_fcb_calls_v1232
        movem   2,daimos_f07c_index_v1232
""")
    sec = replace_one(sec, 'jumpe   1,kret_neg1', 'jumpe   1,daimos_f07c_no_reader_v1232')
    sec = replace_one(sec, 'jumpe   4,kret_neg1', 'jumpe   4,daimos_f07c_no_info_v1232')
    sec = replace_one(sec, '        caml    2,6(1)                   ; index >= fcb_count\n',
                      '        move    7,6(1)\n        movem   7,daimos_f07c_limit_v1232\n        caml    2,6(1)                   ; index >= fcb_count\n')
    sec = replace_one(sec, 'jrst    kret_neg1\n', 'jrst    daimos_f07c_bad_index_v1232\n')
    sec = replace_one(sec, '        pushj   17,d6fs_reader_get_block\n',
                      '        movem   2,daimos_f07c_block_v1232\n        pushj   17,d6fs_reader_get_block\n')
    sec = replace_one(sec, '        pushj   17,d6fs_reader_get_block\n        jumpe   1,d6fs_reader_fcb_fail\n',
                      '        pushj   17,d6fs_reader_get_block\n        jumpe   1,daimos_f07c_block_fail_path_v1232\n')
    sec = replace_one(sec, '        pushj   17,d6fs_fcb_decode_valid\n        jumpe   1,d6fs_reader_fcb_fail\n',
                      '        pushj   17,d6fs_fcb_decode_valid\n        jumpe   1,daimos_f07c_decode_fail_path_v1232\n')
    sec = replace_one(sec, 'd6fs_reader_fcb_fail:\n', """daimos_f07c_no_reader_v1232:
        movei   1,1
        movem   1,daimos_f07c_reason_v1232
        jrst    kret_neg1
daimos_f07c_no_info_v1232:
        movei   1,2
        movem   1,daimos_f07c_reason_v1232
        jrst    kret_neg1
daimos_f07c_bad_index_v1232:
        movei   1,3
        movem   1,daimos_f07c_reason_v1232
        jrst    kret_neg1
daimos_f07c_block_fail_path_v1232:
        aos     daimos_f07c_block_fail_v1232
        movei   1,4
        movem   1,daimos_f07c_reason_v1232
        jrst    d6fs_reader_fcb_fail
daimos_f07c_decode_fail_path_v1232:
        aos     daimos_f07c_decode_fail_v1232
        movei   1,5
        movem   1,daimos_f07c_reason_v1232
        jrst    d6fs_reader_fcb_fail
d6fs_reader_fcb_fail:
""")
    s = s[:a] + sec + s[b:]
    a = s.index('\nd6fs_provider_read_words:\n')
    b = s.index('\n; int d6fs_provider_sync', a)
    sec = s[a:b]
    sec = replace_one(sec, '        caie    1,3                      ; D6FS_TYPE_SYMLINK\n        jrst    d6fs_provider_read_words_fail\n',
                      '        caie    1,3                      ; D6FS_TYPE_SYMLINK\n        jrst    daimos_f07c_type_fail_path_v1232\n')
    sec = replace_one(sec, 'd6fs_provider_read_words_fail:\n', """daimos_f07c_type_fail_path_v1232:
        aos     daimos_f07c_type_fail_v1232
        movei   1,6
        movem   1,daimos_f07c_reason_v1232
        jrst    d6fs_provider_read_words_fail
d6fs_provider_read_words_fail:
""")
    s = s[:a] + sec + s[b:]
    for n in FIELDS:
        s = '        .globl daimos_f07c_%s_v1232\n' % n + s
    p.write_text(s)
    p = root / 'proc/proc_pdp6.s'
    s = p.read_text() + '\n        .bss\n'
    for n in FIELDS:
        sym = 'daimos_f07c_%s_v1232' % n
        s += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    p.write_text(s)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1232 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

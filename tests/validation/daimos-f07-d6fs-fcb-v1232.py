#!/usr/bin/env python3
"""Disambiguate FCB index, metadata block, decode and type failures.

All changes affect only a disposable guest image and preserve the
original AC/stack ABI and returned status.
"""

from pathlib import Path
import sys

FIELDS = ('reader_calls', 'reader_index', 'reader_limit', 'reader_base',
          'index_reject', 'block_reject', 'decode_reject', 'type_reject',
          'last_type', 'fcb_calls')


def replace_one(source, old, new):
    if source.count(old) != 1:
        raise ValueError('v1232: source anchor changed: ' + old[:48])
    return source.replace(old, new, 1)


def inject(root):
    path = root / 'fs/d6fs_runtime.s'
    source = path.read_text()
    source = replace_one(source, '''d6fs_reader_fcb:
        jumpe   1,kret_neg1
        jumpe   4,kret_neg1
        caml    2,6(1)                   ; index >= fcb_count
        jrst    kret_neg1
''', '''d6fs_reader_fcb:
        aos     daimos_f07c_reader_calls_v1232
        movem   1,daimos_f07c_reader_base_v1232
        movem   2,daimos_f07c_reader_index_v1232
        jumpe   1,daimos_f07c_index_reject_branch_v1232
        jumpe   4,daimos_f07c_index_reject_branch_v1232
        move    5,6(1)
        movem   5,daimos_f07c_reader_limit_v1232
        caml    2,6(1)                   ; index >= fcb_count
        jrst    daimos_f07c_index_reject_branch_v1232
''')
    source = replace_one(source, '''        pushj   17,d6fs_reader_get_block
        jumpe   1,d6fs_reader_fcb_fail
        move    6,013
''', '''        pushj   17,d6fs_reader_get_block
        jumpe   1,daimos_f07c_block_reject_branch_v1232
        move    6,013
''')
    source = replace_one(source, '''        pushj   17,d6fs_fcb_decode_valid
        jumpe   1,d6fs_reader_fcb_fail
        setz    1,
        jrst    d6fs_reader_fcb_done
d6fs_reader_fcb_fail:
''', '''        pushj   17,d6fs_fcb_decode_valid
        jumpe   1,daimos_f07c_decode_reject_branch_v1232
        setz    1,
        jrst    d6fs_reader_fcb_done
daimos_f07c_index_reject_branch_v1232:
        aos     daimos_f07c_index_reject_v1232
        jrst    kret_neg1
daimos_f07c_block_reject_branch_v1232:
        aos     daimos_f07c_block_reject_v1232
        jrst    d6fs_reader_fcb_fail
daimos_f07c_decode_reject_branch_v1232:
        aos     daimos_f07c_decode_reject_v1232
d6fs_reader_fcb_fail:
''')
    source = replace_one(source, 'd6fs_provider_read_words:\n',
                         'd6fs_provider_read_words:\n'
                         '        aos     daimos_f07c_fcb_calls_v1232\n')
    source = replace_one(source, '''        move    1,-014(17)               ; info.type
        cain    1,1                      ; D6FS_TYPE_REG
        jrst    d6fs_provider_read_words_ok
        caie    1,3                      ; D6FS_TYPE_SYMLINK
        jrst    d6fs_provider_read_words_fail
''', '''        move    1,-014(17)               ; info.type
        movem   1,daimos_f07c_last_type_v1232
        cain    1,1                      ; D6FS_TYPE_REG
        jrst    d6fs_provider_read_words_ok
        caie    1,3                      ; D6FS_TYPE_SYMLINK
        jrst    daimos_f07c_type_reject_branch_v1232
''')
    source = replace_one(source, 'd6fs_provider_read_words_fail:\n',
                         'daimos_f07c_type_reject_branch_v1232:\n'
                         '        aos     daimos_f07c_type_reject_v1232\n'
                         'd6fs_provider_read_words_fail:\n')
    path.write_text(''.join('        .globl daimos_f07c_%s_v1232\n' % x
                            for x in FIELDS) + source)
    core = root / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07c_%s_v1232' % field
        text += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1232 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

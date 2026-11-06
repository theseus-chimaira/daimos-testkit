#!/usr/bin/env python3
"""Diagnostic-only comparison of rejected cached D6FS FCB with disk.

Re-read the same FCB block into a distinct 0200-word test BSS buffer
after the normal provider has rejected its decoded type. Never alter
the cache, existing FCB, error return or production kernel sources.
"""

from pathlib import Path
import sys


FIELDS = ('rejects', 'index', 'block', 'cached_meta', 'disk_meta',
          'backing_status', 'decoded_type')


def once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('v1233: missing source anchor: ' + old[:55])
    return source.replace(old, new, 1)


def inject(root):
    path = root / 'fs/d6fs_runtime.s'
    text = path.read_text()
    text = once(text, '''d6fs_provider_read_words:
        aos     daimos_f07c_fcb_calls_v1232
''', '''d6fs_provider_read_words:
        aos     daimos_f07c_fcb_calls_v1232
        hrrz    5,1
        movem   5,daimos_f07b_index_v1233
''')
    text = once(text, '''daimos_f07c_type_reject_branch_v1232:
        aos     daimos_f07c_type_reject_v1232
''', '''daimos_f07c_type_reject_branch_v1232:
        aos     daimos_f07c_type_reject_v1232
        aos     daimos_f07b_rejects_v1233
        move    7,-034(17)
        movem   7,daimos_f07b_cached_meta_v1233
        move    7,-014(17)
        movem   7,daimos_f07b_decoded_type_v1233
        move    7,daimos_f07b_index_v1233
        lsh     7,-3
        move    1,d6fs_active_reader
        add     7,5(1)
        movem   7,daimos_f07b_block_v1233
        move    2,7
        movei   1,013(1)
        movei   3,daimos_f07b_disk_buffer_v1233
        pushj   17,fs_backing_read
        movem   1,daimos_f07b_backing_status_v1233
        jumpn   1,daimos_f07b_read_failed_v1233
        move    7,daimos_f07b_index_v1233
        andi    7,7
        lsh     7,4
        move    1,daimos_f07b_disk_buffer_v1233(7)
        movem   1,daimos_f07b_disk_meta_v1233
daimos_f07b_read_failed_v1233:
''')
    text = '        .globl fs_backing_read\n' + text
    for field in FIELDS:
        text = ('        .globl daimos_f07b_%s_v1233\n' % field) + text
    text = ('        .globl daimos_f07b_disk_buffer_v1233\n' + text)
    path.write_text(text)
    core = root / 'proc/proc_pdp6.s'
    content = core.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07b_%s_v1233' % field
        content += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    content += ('        .globl daimos_f07b_disk_buffer_v1233\n'
                'daimos_f07b_disk_buffer_v1233: .block 0200\n')
    core.write_text(content)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1233 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

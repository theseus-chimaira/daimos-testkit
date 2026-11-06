#!/usr/bin/env python3
"""Observe exact VFS read result during EXEC payload loading.

Diagnostic-only: instruments vm_space_load_file in the disposable
kernel, without changing the original requested words, return code,
owner descriptor or any callee-saved register.
"""

from pathlib import Path
import sys


FIELDS = ('calls', 'vnode', 'offset', 'destination', 'requested', 'returned')


def inject(root):
    path = root / 'proc/vm_pdp6.s'
    text = path.read_text()
    begin = text.index('\nvm_space_load_file:\n')
    end = text.index('\n/**', begin + 1)
    segment = text[begin:end]
    anchor = ('        move    1,6\n'
              '        move    2,7\n'
              '        move    3,5\n'
              '        pushj   17,vfs_read_words\n'
              '        came    1,-1(17)\n')
    if segment.count(anchor) != 1:
        raise ValueError('v1230: exact VM payload reader moved')
    replacement = '''        move    1,6
        move    2,7
        move    3,5
        ; Read-only observation of this actual DXR payload request.
        aos     daimos_f07v_calls_v1230
        movem   1,daimos_f07v_vnode_v1230
        movem   2,daimos_f07v_offset_v1230
        movem   3,daimos_f07v_destination_v1230
        movem   4,daimos_f07v_requested_v1230
        pushj   17,vfs_read_words
        movem   1,daimos_f07v_returned_v1230
        came    1,-1(17)
'''
    segment = segment.replace(anchor, replacement, 1)
    text = text[:begin] + segment + text[end:]
    for field in FIELDS:
        text = ('        .globl daimos_f07v_%s_v1230\n' % field) + text
    path.write_text(text)
    core = root / 'proc/proc_pdp6.s'
    source = core.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07v_%s_v1230' % field
        source += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1230 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

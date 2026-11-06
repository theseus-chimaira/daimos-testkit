#!/usr/bin/env python3
"""Freeze BCACHE slot provenance at invalid D6FS FCB decode."""

from pathlib import Path
import sys

FIELDS = ('hits', 'key', 'mode', 'raw_word')


def inject(root):
    path = root / 'fs/d6fs_runtime.s'
    source = path.read_text()
    anchor = 'd6fs_reader_fcb_decode_cache:\n'
    if source.count(anchor) != 1:
        raise ValueError('v1235: FCB decode entry moved')
    source = source.replace(anchor, '''d6fs_reader_fcb_decode_cache:
        move    7,013
        caie    7,037
        jrst    daimos_f07h_not_target_v1235
        move    7,(1)
        jumpn   7,daimos_f07h_not_target_v1235
        aos     daimos_f07h_hits_v1235
        move    7,daimos_f07k_key_v1234
        movem   7,daimos_f07h_key_v1235
        move    7,daimos_f07k_mode_v1234
        movem   7,daimos_f07h_mode_v1235
        move    7,daimos_f07k_raw_word_v1234
        movem   7,daimos_f07h_raw_word_v1235
daimos_f07h_not_target_v1235:
''', 1)
    for name in FIELDS:
        source = ('        .globl daimos_f07h_%s_v1235\n' % name) + source
    source = ('''        .globl daimos_f07k_key_v1234
        .globl daimos_f07k_mode_v1234
        .globl daimos_f07k_raw_word_v1234
''' + source)
    path.write_text(source)
    core = root / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07h_%s_v1235' % field
        text += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1235 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

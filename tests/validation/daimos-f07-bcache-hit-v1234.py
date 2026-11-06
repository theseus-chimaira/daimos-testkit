#!/usr/bin/env python3
"""Identify which clean-cache slot supplied a corrupted D6FS FCB.

Only disposable KCORE; no changes to cache keys, allocation, lock
ownership, copy direction or provider return values.
"""

from pathlib import Path
import sys


FIELDS = ('calls', 'key', 'mode', 'raw_word')


def replace_one(source, old, new):
    if source.count(old) != 1:
        raise ValueError('v1234: cache control point moved: ' + old[:48])
    return source.replace(old, new, 1)


def inject(root):
    p = root / 'storage/bcache_pdp6.s'
    s = p.read_text()
    s = replace_one(s, 'bcache_fetch:\n', '''bcache_fetch:
        aos     daimos_f07k_calls_v1234
        movem   1,daimos_f07k_key_v1234
        setzm   daimos_f07k_mode_v1234
        setzm   daimos_f07k_raw_word_v1234
''')
    s = replace_one(s, 'bcache_fetch_slot0:\n', '''bcache_fetch_slot0:
        movei   5,1
        movem   5,daimos_f07k_mode_v1234
        move    5,fs_block_workspace+0160
        movem   5,daimos_f07k_raw_word_v1234
''')
    s = replace_one(s, 'bcache_fetch_slot1:\n', '''bcache_fetch_slot1:
        movei   5,2
        movem   5,daimos_f07k_mode_v1234
        move    5,0161(3)
        movem   5,daimos_f07k_raw_word_v1234
''')
    for field in FIELDS:
        s = ('        .globl daimos_f07k_%s_v1234\n' % field) + s
    p.write_text(s)
    core = root / 'proc/proc_pdp6.s'
    s = core.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07k_%s_v1234' % field
        s += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(s)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1234 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

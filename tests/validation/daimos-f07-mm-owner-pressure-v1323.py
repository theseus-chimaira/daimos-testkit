#!/usr/bin/env python3
"""Size the existing disposable v1204 MM owner fixture for F07 swap.

The source must already have received v1204's v1206 small-only rewrite.
No production allocation routine is changed. The guest's INIT makes
one real 1K-word kernel-dynamic allocation while the other user
processes are live, and frees that exact extent after their reaps.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()
    changes = (
        ('caige   010,0140             ; 96 small test extents',
         'caige   010,01               ; one physical 1K extent'),
        ('movei   1,0140\n', 'movei   1,01\n'),
        ('caie    6,0140\n', 'caie    6,01\n'),
        ('caige   010,0               ; no 8K blocks in v1206',
         'caige   010,01              ; single 1K extent allocation'),
    )
    for old, new in changes:
        if source.count(old) != 1:
            raise ValueError('v1323 allocator fixture anchor changed: ' + old)
        source = source.replace(old, new, 1)
    # v1323: the inherited big-extent branch requests 020000 (8K)
    # words, which the actual 24K F07 guest could not admit. Keep its
    # real allocator, owner and 02000 APR alignment, request 02000.
    original = '        movei   1,020000\n        movei   2,02000'
    replacement = '        movei   1,02000\n        movei   2,02000'
    if source.count(original) != 1:
        raise ValueError('v1323 MM owner size anchor changed')
    source = source.replace(original, replacement, 1)
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1323.py DISPOSABLE-KERNEL-ROOT')
    inject(Path(sys.argv[1]))

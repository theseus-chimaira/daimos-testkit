#!/usr/bin/env python3
"""Size the existing disposable v1204 MM owner fixture for F07 swap.

The source must already have received v1204's v1206 small-only rewrite.
No production allocation routine is changed. The guest's INIT makes
six real 8K-word kernel-dynamic allocations while the other user
processes are live, and frees those exact extents after their reaps.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()
    changes = (
        ('caige   010,0140             ; 96 small test extents',
         'caige   010,06               ; six physical 8K extents'),
        ('movei   1,0140\n', 'movei   1,06\n'),
        ('caie    6,0140\n', 'caie    6,06\n'),
        ('caige   010,0               ; no 8K blocks in v1206',
         'caige   010,06              ; all six use 8K extent allocation'),
    )
    for old, new in changes:
        if source.count(old) != 1:
            raise ValueError('v1321 allocator fixture anchor changed: ' + old)
        source = source.replace(old, new, 1)
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1321.py DISPOSABLE-KERNEL-ROOT')
    inject(Path(sys.argv[1]))

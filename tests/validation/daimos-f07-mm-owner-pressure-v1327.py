#!/usr/bin/env python3
"""Reserve four real 8K MM owner extents before F07 child admissions.

The source must already have received v1204's v1206 small-only rewrite.
No production MM allocator or swap code is changed. INIT holds four
8K-word kernel-dynamic extents while it admits 18 more real process
images, then releases their exact typed MM owner at cleanup. This
occurs before the original foreign FS provider lease is acquired.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()
    changes = (
        ('caige   010,0140             ; 96 small test extents',
         'caige   010,04               ; four physical 8K extents'),
        ('movei   1,0140\n', 'movei   1,04\n'),
        ('caie    6,0140\n', 'caie    6,04\n'),
        ('caige   010,0               ; no 8K blocks in v1206',
         'caige   010,04              ; all four use 8K extent allocation'),
    )
    for old, new in changes:
        if source.count(old) != 1:
            raise ValueError('v1327 allocator fixture anchor changed: ' + old)
        source = source.replace(old, new, 1)
    # The original v1204 late pressure probe was conditional on the
    # foreign provider already holding its lease. The v1327 test must
    # reserve memory BEFORE extra RUNs, while H/G are still blocked on
    # their real gate PIPE. Remove only that now-inapplicable test
    # precondition, not the original provider checks, MM allocator,
    # INIT identity check or exact owner-verified freeing.
    start = 'daimos_f07_prepare_lease_v1204:\n'
    end = '        push    17,010\n'
    if source.count(start) != 1:
        raise ValueError('v1327 early lease guard label changed')
    begin = source.index(start)
    finish = source.index(end, begin)
    old_lease = source[begin:finish]
    if ('fs_provider_ready' not in old_lease or
            'daimos_test_holder_enter_v1150' not in old_lease or
            'daimos_test_predispatch_v1150' not in old_lease):
        raise ValueError('v1327 early lease guard assumptions changed')
    source = (source[:begin] +
              'daimos_f07_prepare_lease_v1204:\n'
              'daimos_f07_prepare_enter_v1204:\n' +
              source[finish:])
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1327.py DISPOSABLE-KERNEL-ROOT')
    inject(Path(sys.argv[1]))

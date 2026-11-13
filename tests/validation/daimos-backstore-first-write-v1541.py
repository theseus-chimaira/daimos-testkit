#!/usr/bin/env python3
"""Select the first actual active/owned swap WRITE for v1541 PI2 fault.

Only modifies the disposable full-guest kernel source after the accepted
v1511 Type-236 error-witness injection.  It never changes the controller
completion code, publishes a fake negative I/O, or touches checked-out
DAIMOS production files.  A valid physical drum transfer must happen.
"""
from pathlib import Path
import sys


def instrument(kernel):
    path = Path(kernel) / 'fs/fs_mres.s'
    src = path.read_text()
    original = ('backstore_write:\n'
                'blockset_direct_tail_write:\n'
                '        movei   4,1\n')
    assert src.count(original) == 1, 'BACKSTORE write entry changed'
    assert 'daimos_v1511_this_read' in src
    assert 'daimos_v1511_device_errors' in src
    assert 'proc_sched_cursor' in src
    assert 'backstore_blocks_used' in src
    changed = ('''backstore_write:
blockset_direct_tail_write:
        ; v1541 disposable PI2 witness: arm only at a genuinely owned
        ; active backing WRITE, never at boot-time snapshot probes.
        skipn   backstore_enabled
        jrst    daimos_v1541_write_normal
        skipn   backstore_blocks_used
        jrst    daimos_v1541_write_normal
        ; Only one real Type-236 error completion is needed. After the
        ; driver retires its actual descriptor, fixed v1541 must HALT.
        skipn   daimos_v1511_device_errors
        setom   daimos_v1511_this_read
daimos_v1541_write_normal:
        movei   4,1
''')
    assert 'daimos_v1541_write_normal:' not in src
    src = src.replace(original, changed, 1)
    path.write_text(src)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1541-writer.py DISPOSABLE_KERNEL_ROOT')
    instrument(sys.argv[1])

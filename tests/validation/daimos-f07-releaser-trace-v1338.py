#!/usr/bin/env python3
"""Add read-only diagnostic words to the disposable v1336 F07 guest.

No production kernel instruction is modified. This overlays only the
already test-only cooldown query and owner-release entry. The actual
MM allocator, PI6, disk swap and pin/unpin are unchanged.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()
    query = '''        move    1,daimos_f07s_cooldown_v1209
        popj    17,
daimos_f07_normal_v1204:'''
    replacement = '''        aos     daimos_f07q_calls_v1338
        move    1,daimos_f07s_cooldown_v1209
        movem   1,daimos_f07q_last_v1338
        popj    17,
daimos_f07_normal_v1204:'''
    if source.count(query) != 1:
        raise ValueError('v1338 test-only cooldown query moved')
    source = source.replace(query, replacement, 1)
    release = '''daimos_f07_release_v1204:
        move    6,daimos_f07_prepared_v1204'''
    if source.count(release) != 1:
        raise ValueError('v1338 owner-release entry moved')
    source = source.replace(release, '''daimos_f07_release_v1204:
        aos     daimos_f07q_release_calls_v1338
        move    6,daimos_f07_prepared_v1204''', 1)
    source += '''
        .bss
        .globl daimos_f07q_calls_v1338
daimos_f07q_calls_v1338: .block 1
        .globl daimos_f07q_last_v1338
daimos_f07q_last_v1338: .block 1
        .globl daimos_f07q_release_calls_v1338
daimos_f07q_release_calls_v1338: .block 1
'''
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1338.py DISPOSABLE-KERNEL-ROOT')
    inject(Path(sys.argv[1]))

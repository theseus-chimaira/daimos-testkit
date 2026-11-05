#!/usr/bin/env python3
"""Observe protected live process slots at a genuine BRK OOM.

Runs only after v1150 has patched a copied kernel. The original
allocator, victim decision and provider lock/release path are retained.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])
p = root / 'proc/syscall_dispatch_pdp6.s'
src = p.read_text()

anchor = ('daimos_test_brk_real_v1150:\n'
          '        aos     daimos_test_real_oom_v1150')
assert src.count(anchor) == 1, 'v1159: missing actual OOM probe'

checks = [
    ('init', '05', (3,)),        # slot 1: sleeping INIT
    ('witness', '010', (3,)),   # slot 2: blocked pipe reader
    ('waiter', '016', (3,)),    # slot 4: pre-dispatch FS waiter
    ('spinner', '021', (2, 3)), # slot 5: runnable or sleeping
    ('holder', '024', (3,)),    # slot 6: original in-flight lease
]
lines = [
    'daimos_test_brk_real_v1150:',
    '        move    0,proc_current_slot',
    '        movem   0,daimos_e12_requester_v1159',
    '        caie    0,3',
    '        jrst    daimos_e12_bad_v1159',
    # PDP-10 AC0 is NOT an index register: X=0 means no indexing.
    # Use AC6, which the original v1150 OOM witness overwrites anyway.
    '        move    6,proc_table',
    '        jumpe   6,daimos_e12_bad_v1159',
]
for name, offset, permitted in checks:
    lines += [
        '        hlrz    7,%s(6)' % offset,
        '        movem   7,daimos_e12_%s_v1159' % name,
        '        andi    7,0700000',
    ]
    # CAIE skips the *next* instruction if EQUAL. One allowed state
    # needs a single compare; two use a separate second-state branch.
    if len(permitted) == 1:
        lines += [
            '        caie    7,0%o00000' % permitted[0],
            '        jrst    daimos_e12_bad_v1159',
        ]
    else:
        assert len(permitted) == 2
        lines += [
            '        caie    7,0%o00000' % permitted[0],
            '        jrst    daimos_e12_%s_second_v1159' % name,
            '        jrst    daimos_e12_%s_ok_v1159' % name,
            'daimos_e12_%s_second_v1159:' % name,
            '        caie    7,0%o00000' % permitted[1],
            '        jrst    daimos_e12_bad_v1159',
            'daimos_e12_%s_ok_v1159:' % name,
        ]
lines += [
    '        jrst    daimos_e12_snapshot_ok_v1159',
    'daimos_e12_bad_v1159:',
    '        setom   daimos_e12_error_v1159',
    'daimos_e12_snapshot_ok_v1159:',
    '        aos     daimos_e12_snapshots_v1159',
    '        aos     daimos_test_real_oom_v1150',
]
src = src.replace(anchor, '\n'.join(lines), 1)

# Observe the actual fatal branch, after the production MM-cause check.
# The disabled guest assembles this out; it must have zero selections.
fatal = ('native_sys_brk_oom_v1000:\n'
         '        movei   1,1\n'
         '        jrst    proc_fatal_close_current_v879')
assert src.count(fatal) == 1, 'v1159: fatal decision changed'
src = src.replace(fatal, '''native_sys_brk_oom_v1000:
        move    0,proc_current_slot
        movem   0,daimos_e12_selected_v1159
        aos     daimos_e12_select_calls_v1159
        caie    0,3
        setom   daimos_e12_error_v1159
        movei   1,1
        jrst    proc_fatal_close_current_v879''', 1)

names = ['requester', 'init', 'witness', 'waiter', 'spinner',
         'holder', 'error', 'snapshots', 'selected', 'select_calls']
src += '\n        .bss\n'
for name in names:
    sym = 'daimos_e12_%s_v1159' % name
    src += '        .globl %s\n%s: .block 1\n' % (sym, sym)
p.write_text(src)

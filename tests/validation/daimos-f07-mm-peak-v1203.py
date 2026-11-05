#!/usr/bin/env python3
"""Disposable, allocation-free live-MM snapshot at genuine BRK OOM.

Insert after the v1150 foreign-provider hook. The probe uses no pushes,
calls, MM allocation, provider acquisition or scheduler operations.
Only the disposable kernel gains the fixed snapshot storage.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])
p = root / 'proc/syscall_dispatch_pdp6.s'
s = p.read_text()
# v1159 replaces the original label+increment pair with a protected
# process snapshot. Anchor after that snapshot, immediately before the
# original lease verification; do not replace or bypass v1159 checks.
anchor = ('        aos     daimos_test_real_oom_v1150\n'
          '        move    6,fs_provider_ready')
assert s.count(anchor) == 1, 'v1203: real physical OOM hook missing'

probe = '''        aos     daimos_test_real_oom_v1150
        ; Disposable F07 probe: snapshot while FS lease is still held.
        ; AC1/AC2 syscall result and the private owner stack are untouched.
        aos     daimos_f07_samples_v1203
        move    6,mm_extent_count
        movem   6,daimos_f07_count_v1203
        move    7,mm_extent_capacity
        movem   7,daimos_f07_capacity_v1203
        move    7,mm_core_words
        movem   7,daimos_f07_core_v1203
        move    7,mm_arena_count
        movem   7,daimos_f07_arena_count_v1203
        move    7,mm_arenas
        movem   7,daimos_f07_arena0_v1203
        move    7,mm_arenas+1
        movem   7,daimos_f07_arena1_v1203
        move    7,mm_arenas+2
        movem   7,daimos_f07_arena2_v1203
        move    7,fs_provider_ready
        movem   7,daimos_f07_lease_v1203
        movei   7,fs_block_workspace
        movem   7,daimos_f07_buffer_base_v1203
        ; Never copy outside the fixed 136*2-word snapshot array.
        jumpl   6,daimos_f07_invalid_v1203
        caile   6,0210
        jrst    daimos_f07_invalid_v1203
        lsh     6,1
        movem   6,daimos_f07_words_v1203
        setz    7,
daimos_f07_copy_v1203:
        caml    7,daimos_f07_words_v1203
        jrst    daimos_f07_done_v1203
        move    6,mm_extents(7)
        movem   6,daimos_f07_extents_v1203(7)
        aoja    7,daimos_f07_copy_v1203
daimos_f07_invalid_v1203:
        setom   daimos_f07_error_v1203
daimos_f07_done_v1203:
        move    6,fs_provider_ready'''
s = s.replace(anchor, probe, 1)
s = ('''        .globl mm_extent_count
        .globl mm_extent_capacity
        .globl mm_core_words
        .globl mm_arena_count
        .globl mm_arenas
        .globl mm_extents
        .globl fs_provider_ready
        .globl fs_block_workspace
''' + s)

symbols = ['samples', 'count', 'capacity', 'core', 'arena_count',
           'arena0', 'arena1', 'arena2', 'lease', 'buffer_base',
           'words', 'error']
s += '\n        .bss\n'
for name in symbols:
    sym = 'daimos_f07_%s_v1203' % name
    s += '        .globl %s\n%s: .block 1\n' % (sym, sym)
s += ('''        .globl daimos_f07_extents_v1203
daimos_f07_extents_v1203: .block 0420
''')
p.write_text(s)

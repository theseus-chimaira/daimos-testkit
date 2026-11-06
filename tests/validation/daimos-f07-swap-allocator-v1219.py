#!/usr/bin/env python3
"""Test-only snapshot of swap-in allocator failure and physical fit.

The snapshot runs only after the allocator has returned nonzero. It
does not change process ownership, transaction markers or MM extents.
The exact allocator return code is restored before normal processing.
"""

from pathlib import Path
import sys


FIELDS = ('calls', 'error', 'owner', 'requested', 'extents',
          'low_fit', 'low_base_or_free', 'high_fit',
          'high_base_or_free', 'meta')


def inject(root):
    path = root / 'proc/proc_swap_pdp6.s'
    source = path.read_text()
    anchor = 'proc_swap_in_alloc_status:\n'
    if source.count(anchor) != 1:
        raise ValueError('v1219: allocator failure label changed')
    replacement = '''proc_swap_in_alloc_status:
        ; v1219 disposable-only: retain the exact typed MM error,
        ; then ask the read-only common fit finder for LOW and HIGH.
        ; AC10..AC16 are preserved by mm_find_fit, as in production.
        aos     daimos_f07a_calls_v1219
        movem   1,daimos_f07a_error_v1219
        movem   10,daimos_f07a_owner_v1219
        movem   13,daimos_f07a_requested_v1219
        move    7,mm_extent_count
        movem   7,daimos_f07a_extents_v1219
        move    7,(11)
        movem   7,daimos_f07a_meta_v1219
        push    17,[0]
        move    1,13
        movei   2,VM_PDP6_ALIGN_WORDS
        setz    3,
        movei   4,(17)
        pushj   17,mm_find_fit
        movem   1,daimos_f07a_low_fit_v1219
        move    7,(17)
        movem   7,daimos_f07a_low_base_or_free_v1219
        move    1,13
        movei   2,VM_PDP6_ALIGN_WORDS
        movei   3,1
        movei   4,(17)
        pushj   17,mm_find_fit
        movem   1,daimos_f07a_high_fit_v1219
        move    7,(17)
        movem   7,daimos_f07a_high_base_or_free_v1219
        sub     17,kconst_1_1
        move    1,daimos_f07a_error_v1219
'''
    source = source.replace(anchor, replacement, 1)
    source = '        .globl mm_extent_count\n        .globl mm_find_fit\n' + source
    for name in FIELDS:
        source += ('        .globl daimos_f07a_%s_v1219\n' % name)
    path.write_text(source)
    mm = root / 'mm/mm_pdp6.s'
    mm_source = mm.read_text()
    if mm_source.count('\nmm_find_fit:\n') != 1:
        raise ValueError('v1219: MM fit entry moved')
    mm.write_text(mm_source.replace('\nmm_find_fit:\n',
                                   '\n        .globl mm_find_fit\nmm_find_fit:\n', 1))
    core = root / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for name in FIELDS:
        label = 'daimos_f07a_%s_v1219' % name
        text += '        .globl %s\n%s: .block 1\n' % (label, label)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1219 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

#!/usr/bin/env python3
"""Sample PID 1 descriptor around real disk swap transactions.

The high-pressure v1217 guest observed a missing u-area on the current
owner. This test-only probe checks whether the descriptor becomes invalid
before swap-out, during swap-out, or during the attempted swap-in. All
counters reside in the disposable KCORE, not the production image.
"""

from pathlib import Path
import sys


NAMES = ('out_calls', 'out_slot', 'out_before', 'out_after', 'out_result',
         'in_calls', 'in_slot', 'in_before', 'in_after', 'in_result')


def inject(root):
    src = root / 'proc/proc_swap_pdp6.s'
    core = root / 'proc/proc_pdp6.s'
    swap = src.read_text()
    # Only caller-scratch AC6/AC7 are used. Success/failure and saved
    # AC10..AC16 remain identical to the original transaction.
    captures = (
        ('proc_swap_out:\n', '''proc_swap_out:
        aos     daimos_f07m_out_calls_v1218
        movem   1,daimos_f07m_out_slot_v1218
        move    7,proc_table
        addi    7,3
        move    6,(7)
        movem   6,daimos_f07m_out_before_v1218
'''),
        ('proc_swap_out_restore:\n', '''proc_swap_out_restore:
        movem   1,daimos_f07m_out_result_v1218
        move    7,proc_table
        addi    7,3
        move    6,(7)
        movem   6,daimos_f07m_out_after_v1218
'''),
        ('proc_swap_in:\n', '''proc_swap_in:
        aos     daimos_f07m_in_calls_v1218
        movem   1,daimos_f07m_in_slot_v1218
        move    7,proc_table
        addi    7,3
        move    6,(7)
        movem   6,daimos_f07m_in_before_v1218
'''),
        ('proc_swap_in_restore:\n', '''proc_swap_in_restore:
        movem   1,daimos_f07m_in_result_v1218
        move    7,proc_table
        addi    7,3
        move    6,(7)
        movem   6,daimos_f07m_in_after_v1218
'''),
    )
    for anchor, replacement in captures:
        if swap.count(anchor) != 1:
            raise ValueError('v1218: swap label moved: ' + anchor.strip())
        swap = swap.replace(anchor, replacement, 1)
    swap = ''.join('        .globl daimos_f07m_%s_v1218\n' % n
                   for n in NAMES) + swap
    src.write_text(swap)
    core_text = core.read_text() + '\n        .bss\n'
    for name in NAMES:
        symbol = 'daimos_f07m_%s_v1218' % name
        core_text += '        .globl %s\n%s: .block 1\n' % (symbol, symbol)
    core.write_text(core_text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: swap-meta-v1218.py DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))

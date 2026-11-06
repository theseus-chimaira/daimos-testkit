#!/usr/bin/env python3
"""Count real per-slot dispatch and swap selection in a disposable kernel.

This is F07 diagnosis only. It adds no scheduler decisions, I/O retries,
production state, or private-stack words. The instrumented source is a
copy of proc_pdp6.s in a disposable guest, never the DAIMOS checkout.
"""

from pathlib import Path
import sys


def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('v1253: changed or ambiguous scheduler hook')
    return source.replace(before, after, 1)


def inject(root):
    path = root / 'proc/proc_pdp6.s'
    source = path.read_text()
    source = once(source, '''proc_sched_restore_selected:
        movem   1,proc_current_slot
''', '''proc_sched_restore_selected:
        ; v1253 disposable: AC1 remains the selected process slot.
        ; AC6 is scratch; actual user/exec ACs are restored afterwards.
        move    6,1
        jumpe   6,daimos_f07u_idle_v1253
        jumpl   6,daimos_f07u_selected_v1253
        caige   6,0100
        aos     daimos_f07u_dispatch_v1253(6)
        jrst    daimos_f07u_selected_v1253
daimos_f07u_idle_v1253:
        aos     daimos_f07u_idle_count_v1253
daimos_f07u_selected_v1253:
        movem   1,proc_current_slot
''')
    source = once(source, '''proc_select_done_swap_v879:
        movei   1,0400
''', '''proc_select_done_swap_v879:
        ; This branch has already chosen a nonresident RUN candidate.
        ; Record its slot, then preserve the exact original request.
        move    6,proc_sched_cursor
        andi    6,0377
        caige   6,0100
        aos     daimos_f07u_swapreq_v1253(6)
        movei   1,0400
''')
    source += '''
        .bss
        .globl daimos_f07u_dispatch_v1253
daimos_f07u_dispatch_v1253: .block 0100
        .globl daimos_f07u_swapreq_v1253
daimos_f07u_swapreq_v1253: .block 0100
        .globl daimos_f07u_idle_count_v1253
daimos_f07u_idle_count_v1253: .block 1
'''
    path.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1253 DISPOSABLE_KERNEL_ROOT')
    inject(Path(sys.argv[1]))

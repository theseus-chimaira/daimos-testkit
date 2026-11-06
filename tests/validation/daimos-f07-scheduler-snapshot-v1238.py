#!/usr/bin/env python3
"""Record last real swap request and process state under F07 load.

Only a disposable guest is instrumented. No production scheduler path,
resource allocation, or process table is changed. The 32-entry snapshot
contains the three native descriptor words per process; slot 0 is included.
"""

from pathlib import Path
import sys


FIELDS = ('services', 'swap_request', 'selector_swap', 'selector_ready',
          'selector_resident', 'selector_none', 'idle', 'timer',
          'cursor', 'current', 'runq', 'high_slot', 'process_table',
          'rt_owner', 'pid1_meta', 'pid1_vm', 'pid1_sched')


def replace_once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('v1238: ambiguous/moved assembly anchor: ' + before)
    return source.replace(before, after, 1)


def inject(root):
    core = root / 'proc/proc_pdp6.s'
    src = core.read_text()
    for name, anchor in (
            ('selector_swap', 'proc_select_done_swap_v879:\n'),
            ('selector_ready', 'proc_select_runq_start:\n'),
            ('selector_resident', 'proc_select_return_best:\n'),
            ('selector_none', 'proc_select_none:\n'),
            ('idle', 'proc_idle_swap_v881:\n')):
        src = replace_once(src, anchor, anchor +
                           '        aos     daimos_f07q_%s_v1238\n' % name)
    for name, anchor in (('timer', 'proc_sched_tick_select:\n'),):
        src = replace_once(src, anchor, anchor +
                           '        aos     daimos_f07q_%s_v1238\n' % name)
    src = ''.join('        .globl daimos_f07q_%s_v1238\n' % name
                  for name in FIELDS) + src
    core.write_text(src)

    swap = root / 'proc/proc_swap_pdp6.s'
    src = swap.read_text()
    anchor = 'proc_swap_mres_service_v481:\n'
    body = '''proc_swap_mres_service_v481:
        aos     daimos_f07q_services_v1238
        push    17,7
        move    7,proc_sched_cursor
        movem   7,daimos_f07q_cursor_v1238
        move    7,proc_current_slot
        movem   7,daimos_f07q_current_v1238
        move    7,proc_runq_head
        movem   7,daimos_f07q_runq_v1238
        move    7,proc_high_slot
        movem   7,daimos_f07q_high_slot_v1238
        move    7,proc_rt_owner
        movem   7,daimos_f07q_rt_owner_v1238
        move    7,proc_table
        movem   7,daimos_f07q_process_table_v1238
        jumpe   7,daimos_f07q_no_table_v1238
        move    7,proc_table
        hrl     7,proc_table
        hrri    7,daimos_f07q_slots_v1238
        blt     7,daimos_f07q_slots_v1238+0137
        move    7,daimos_f07q_slots_v1238+3
        movem   7,daimos_f07q_pid1_meta_v1238
        move    7,daimos_f07q_slots_v1238+4
        movem   7,daimos_f07q_pid1_vm_v1238
        move    7,daimos_f07q_slots_v1238+5
        movem   7,daimos_f07q_pid1_sched_v1238
daimos_f07q_no_table_v1238:
        pop     17,7
'''
    src = replace_once(src, anchor, body)
    src = replace_once(src,
                       '''        trnn    1,PROC_SCHED_SWAP_REQUEST
        jrst    kret_zero
''',
                       '''        trnn    1,PROC_SCHED_SWAP_REQUEST
        jrst    kret_zero
        aos     daimos_f07q_swap_request_v1238
''')
    src = '''        .globl proc_runq_head
        .globl proc_rt_owner
''' + ''.join('        .globl daimos_f07q_%s_v1238\n' % name
                for name in FIELDS) + src
    swap.write_text(src)

    core = root / 'proc/proc_pdp6.s'
    src = core.read_text() + '\n        .bss\n'
    for name in FIELDS:
        label = 'daimos_f07q_%s_v1238' % name
        src += '        .globl %s\n%s: .block 1\n' % (label, label)
    src += ('''        .globl daimos_f07q_slots_v1238
daimos_f07q_slots_v1238: .block 0140
''')
    core.write_text(src)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1238 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
